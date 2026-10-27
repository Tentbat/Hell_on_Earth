import Foundation
import UserNotifications
import EarthFromAboveCore

/// Local notifications for upcoming sights. They are scheduled from the timeline
/// whenever the schedule anchor changes, so they stay roughly right even with no
/// network. iOS allows 64 pending notifications; we keep the best 60.
final class NotificationService {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func cancelAll() { center.removeAllPendingNotificationRequests() }

    func schedule(items: [LookoutItem], takeoff: Date, offsetSeconds: Double, leadSeconds: Double, kidBand: KidBand?) {
        cancelAll()
        requestAuthorization()
        let now = Date()
        let candidates = items
            .filter { takeoff.addingTimeInterval($0.elapsedSeconds - offsetSeconds - leadSeconds) > now.addingTimeInterval(5) }
            .sorted { a, b in
                // Prefer features over crossings and higher salience within features.
                switch (a.kind, b.kind) {
                case (.feature(let fa), .feature(let fb)): return fa.salience > fb.salience
                case (.feature, .crossing): return true
                case (.crossing, .feature): return false
                default: return a.elapsedSeconds < b.elapsedSeconds
                }
            }
            .prefix(60)

        for item in candidates {
            let fire = takeoff.addingTimeInterval(item.elapsedSeconds - offsetSeconds - leadSeconds)
            let content = UNMutableNotificationContent()
            let minutes = max(1, Int(leadSeconds / 60))
            let where_ = item.side.map { $0 == .left ? "on your left" : "on your right" } ?? "below you"
            if let band = kidBand {
                content.title = "Coming up \(where_)!"
                content.body = KidMode.text(for: item, band: band)
            } else {
                content.title = "In \(minutes) min \(where_): \(item.name)"
                content.body = item.summary
            }
            content.sound = .default
            content.threadIdentifier = "lookout"
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(5, fire.timeIntervalSince(now)), repeats: false)
            center.add(UNNotificationRequest(identifier: "lookout-" + item.id, content: content, trigger: trigger))
        }
    }
}
