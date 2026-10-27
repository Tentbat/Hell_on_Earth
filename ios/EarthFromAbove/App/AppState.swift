import Foundation
import Observation
import EarthFromAboveCore

/// The one object the views observe. It owns the services and the position
/// estimator, and republishes a fresh estimate every few seconds.
@Observable
@MainActor
final class AppState {
    var settings: UserSettings { didSet { settings.save() } }
    var session: FlightSession? { didSet { session?.save(); if session == nil { FlightSession.clear() } } }
    var bundle: RouteBundle?
    var estimate: PositionEstimate?
    var phase: FlightPhase = .preflight
    var lastError: String?
    var isDownloading = false

    let location = LocationService()
    let motion = MotionService()
    let notifications = NotificationService()
    let store = BundleStore()
    var api: APIClient

    private var estimator = PositionEstimator()
    private var phaseDetector = FlightPhaseDetector()
    private var ticker: Task<Void, Never>?

    init() {
        let s = UserSettings.load()
        settings = s
        api = APIClient(baseURL: APIClient.resolveBaseURL(override: s.backendURL))
        session = FlightSession.load()
    }

    // MARK: Lifecycle

    func start() async {
        if let session, let b = store.load(id: session.bundleID) {
            apply(bundle: b, takeoff: session.takeoffTime)
        }
        location.onFix = { [weak self] fix in Task { @MainActor in self?.ingest(fix) } }
        motion.onCabinAltitude = { [weak self] alt, time in
            Task { @MainActor in self?.ingestBaro(alt, time) }
        }
        location.start()
        motion.start()
        startTicker()
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                self?.refreshEstimate()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    // MARK: Bundle management

    func apply(bundle b: RouteBundle, takeoff: Date?) {
        bundle = b
        estimator = PositionEstimator(route: b.route, takeoffTime: takeoff)
        phaseDetector = FlightPhaseDetector(initialPhase: takeoff == nil ? .preflight : .climb)
        if session?.bundleID != store.id(for: b) {
            session = FlightSession(bundleID: store.id(for: b), takeoffTime: takeoff)
        }
        refreshEstimate()
        scheduleNotifications()
    }

    func loadSampleBundle() {
        do {
            let b = try store.loadSample()
            store.save(b)
            apply(bundle: b, takeoff: nil)
        } catch { lastError = "Could not load sample flight: \(error.localizedDescription)" }
    }

    func downloadBundle(flightNumber: String, date: Date) async {
        isDownloading = true
        defer { isDownloading = false }
        do {
            let b = try await api.fetchBundle(flightNumber: flightNumber, date: date)
            store.save(b)
            apply(bundle: b, takeoff: nil)
            settings.onlineExplanationsUsedThisFlight = 0
            lastError = nil
        } catch {
            lastError = "Download failed: \(error.localizedDescription)"
        }
    }

    func endFlight() {
        session = nil
        bundle = nil
        estimate = nil
        estimator = PositionEstimator()
        phase = .preflight
        notifications.cancelAll()
    }

    // MARK: Takeoff

    func markTakeoff(at time: Date = Date()) {
        estimator.markTakeoff(at: time)
        phaseDetector.markTakeoff()
        phase = .climb
        session?.takeoffTime = time
        refreshEstimate()
        scheduleNotifications()
    }

    func undoTakeoff() {
        estimator.clearTakeoff()
        session?.takeoffTime = nil
        phase = .preflight
        notifications.cancelAll()
        refreshEstimate()
    }

    var takeoffTime: Date? { estimator.takeoffTime }
    var elapsedSeconds: Double { estimate?.elapsedSeconds ?? 0 }
    var remainingSeconds: Double? { estimator.remainingSeconds() }

    // MARK: Sensor ingestion

    private func ingest(_ fix: PositionFix) {
        estimator.ingest(fix)
        if session?.takeoffTime == nil, let t = estimator.takeoffTime {
            // The estimator inferred takeoff from an airborne GPS fix.
            session?.takeoffTime = t
            phase = .cruise
            scheduleNotifications()
        }
        refreshEstimate()
    }

    private func ingestBaro(_ cabinAltitude: Double, _ time: Date) {
        let before = phaseDetector.phase
        let after = phaseDetector.add(.init(cabinAltitudeMeters: cabinAltitude, time: time))
        if after != before {
            phase = after
            if before == .preflight && after == .climb && estimator.takeoffTime == nil {
                // Auto-detected takeoff as a backup for the button.
                markTakeoff(at: time.addingTimeInterval(-60))
            }
        }
    }

    func refreshEstimate() {
        estimate = estimator.estimate()
    }

    // MARK: Derived helpers

    var planner: LookoutPlanner? {
        bundle.map { LookoutPlanner(bundle: $0, interests: settings.interests) }
    }

    var userSide: CabinSide? {
        settings.side ?? CabinSide.fromSeat(settings.seat, lettersInRow: bundle?.aircraft?.seatLettersPerRow ?? 6)
    }

    func scheduleNotifications() {
        guard settings.notificationsEnabled, let planner, let takeoff = estimator.takeoffTime else { return }
        let items = planner.timeline(userSide: userSide).filter { $0.visibility != .obscured }
        notifications.schedule(items: items, takeoff: takeoff, offsetSeconds: estimator.scheduleOffsetSeconds,
                               leadSeconds: settings.notificationLeadSeconds, kidBand: settings.kidModeEnabled ? settings.kidBand : nil)
    }

    /// Whether the user may make another online explanation request right now.
    var canExplainOnline: Bool {
        settings.isPremium || settings.onlineExplanationsUsedThisFlight < APIClient.freeExplanationsPerFlight
    }
}
