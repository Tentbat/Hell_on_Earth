import SwiftUI
import EarthFromAboveCore

/// Kid mode: a mission briefing before the flight, big "we're off" button, a
/// checklist or bingo card, and a simple "what is that?" camera.
struct KidRootView: View {
    @Environment(AppState.self) private var app
    @State private var showParentGate = false
    @State private var gateAnswer = ""
    @State private var gateA = Int.random(in: 3...9)
    @State private var gateB = Int.random(in: 3...9)

    var body: some View {
        NavigationStack {
            Group {
                if app.bundle == nil {
                    ContentUnavailableView("Ask a grown-up to load your flight", systemImage: "airplane",
                                           description: Text("Then come back here for your mission."))
                } else if app.settings.kidBand == .explorer {
                    ExplorerView()
                } else {
                    NavigatorView()
                }
            }
            .navigationTitle("Earth from Above")
            .toolbar {
                Button { showParentGate = true } label: { Label("Grown-ups", systemImage: "lock") }
            }
            .alert("Grown-ups only", isPresented: $showParentGate) {
                TextField("What is \(gateA) times \(gateB)?", text: $gateAnswer).keyboardType(.numberPad)
                Button("Unlock") {
                    if Int(gateAnswer) == gateA * gateB { app.settings.kidModeEnabled = false }
                    gateAnswer = ""; gateA = Int.random(in: 3...9); gateB = Int.random(in: 3...9)
                }
                Button("Cancel", role: .cancel) { gateAnswer = "" }
            } message: {
                Text("Answer to leave kid mode.")
            }
        }
    }
}

/// Ages about 9 to 13: mission briefing, live checklist, camera.
struct NavigatorView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let b = app.bundle, let planner = app.planner {
                    let items = planner.timeline(userSide: app.userSide).filter(\.isFeature)
                    if app.takeoffTime == nil {
                        Text("Mission briefing").font(.title.bold())
                        ForEach(KidMode.briefing(flight: b.flight, items: items, band: .navigator), id: \.self) { line in
                            Label(line, systemImage: "checkmark.seal").font(.body)
                        }
                        Button { app.markTakeoff() } label: {
                            Label("We're off!", systemImage: "airplane.departure").font(.title.bold()).frame(maxWidth: .infinity).padding(.vertical, 20)
                        }.buttonStyle(.borderedProminent)
                    } else if let est = app.estimate {
                        HStack {
                            StatTile(title: "Flying for", value: UnitFormat.duration(est.elapsedSeconds))
                            StatTile(title: "Left to go", value: app.remainingSeconds.map { UnitFormat.duration($0) } ?? "–")
                            StatTile(title: "How high", value: UnitFormat.feet(fromMeters: est.altitudeMeters))
                        }
                        let next = planner.upcoming(fromElapsed: est.elapsedSeconds, horizonSeconds: 3_600, userSide: app.userSide)
                        Text("Coming up").font(.title2.bold())
                        if next.isEmpty { Text("Nothing for a while. Watch the clouds!").foregroundStyle(.secondary) }
                        ForEach(next.prefix(6)) { item in KidItemRow(item: item, elapsed: est.elapsedSeconds, band: .navigator) }
                    }
                    Text("Your checklist").font(.title2.bold())
                    ForEach(items.prefix(15)) { item in
                        KidCheckRow(item: item)
                    }
                    NavigationLink { PhotoIDView() } label: {
                        Label("What is that? Take a photo", systemImage: "camera.viewfinder").font(.headline).frame(maxWidth: .infinity).padding()
                    }.buttonStyle(.bordered)
                    NavigationLink { LearnView() } label: { Label("Learn about clouds, rivers and more", systemImage: "book") }
                }
            }
            .padding()
        }
    }
}

/// Ages about 5 to 8, with a parent: giant button, bingo card, big pictures.
struct ExplorerView: View {
    @Environment(AppState.self) private var app
    @State private var card: [BingoSquare] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let planner = app.planner {
                    if app.takeoffTime == nil {
                        Text("Ready for your flight?").font(.largeTitle.bold()).multilineTextAlignment(.center)
                        Button { app.markTakeoff() } label: {
                            VStack { Image(systemName: "airplane.departure").font(.system(size: 60)); Text("We're off!").font(.largeTitle.bold()) }
                                .frame(maxWidth: .infinity).padding(.vertical, 30)
                        }.buttonStyle(.borderedProminent)
                    } else if let est = app.estimate {
                        let now = planner.upcoming(fromElapsed: est.elapsedSeconds - 60, horizonSeconds: 900, userSide: app.userSide)
                        if let first = now.first {
                            VStack(spacing: 6) {
                                Text("Look \(first.side == .left ? "left" : first.side == .right ? "right" : "down")!").font(.largeTitle.bold())
                                Text(first.name).font(.title2)
                                Text(KidMode.text(for: first, band: .explorer)).font(.title3).multilineTextAlignment(.center)
                            }
                            .padding().frame(maxWidth: .infinity).background(RoundedRectangle(cornerRadius: 16).fill(Color.yellow.opacity(0.2)))
                        } else {
                            Text("Watch the clouds for a bit!").font(.title2)
                        }
                    }
                    Text("Spotter bingo").font(.title.bold())
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(card) { sq in
                            Button {
                                toggle(sq)
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: sq.category.symbolName).font(.title)
                                    Text(sq.title).font(.caption.weight(.semibold)).multilineTextAlignment(.center).lineLimit(3)
                                }
                                .frame(maxWidth: .infinity, minHeight: 96)
                                .background(RoundedRectangle(cornerRadius: 12).fill(isFound(sq) ? Color.green.opacity(0.35) : Color(.secondarySystemBackground)))
                                .overlay(alignment: .topTrailing) { if isFound(sq) { Image(systemName: "star.fill").foregroundStyle(.yellow).padding(6) } }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text("Found \(card.filter(isFound).count) of \(card.count)").font(.headline)
                }
            }
            .padding()
        }
        .onAppear {
            if let planner = app.planner { card = KidMode.bingoCard(from: planner.timeline(userSide: app.userSide), userSide: app.userSide) }
        }
    }

    private func isFound(_ sq: BingoSquare) -> Bool { app.session?.foundBingoSquares.contains(sq.id) ?? false }
    private func toggle(_ sq: BingoSquare) {
        guard app.session != nil else { return }
        if isFound(sq) { app.session?.foundBingoSquares.remove(sq.id) } else { app.session?.foundBingoSquares.insert(sq.id) }
    }
}

struct KidItemRow: View {
    var item: LookoutItem
    var elapsed: Double
    var band: KidBand
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: item.category.symbolName).font(.title2).frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.headline)
                Text(KidMode.text(for: item, band: band)).font(.callout)
                Text("\(item.side.map { $0 == .left ? "Left window" : "Right window" } ?? "Straight down"), in \(max(0, Int((item.elapsedSeconds - elapsed) / 60))) minutes")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(10).background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}

struct KidCheckRow: View {
    @Environment(AppState.self) private var app
    var item: LookoutItem
    var body: some View {
        Button {
            guard app.session != nil else { return }
            if app.session!.checkedLookoutItems.contains(item.id) { app.session!.checkedLookoutItems.remove(item.id) }
            else { app.session!.checkedLookoutItems.insert(item.id) }
        } label: {
            HStack {
                Image(systemName: (app.session?.checkedLookoutItems.contains(item.id) ?? false) ? "checkmark.circle.fill" : "circle").font(.title2)
                VStack(alignment: .leading) {
                    Text(item.name).font(.body.weight(.medium))
                    Text("+\(Int(item.elapsedSeconds / 60)) min, \(item.side.map { $0 == .left ? "left" : "right" } ?? "below")").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .foregroundStyle(.primary)
        }
    }
}
