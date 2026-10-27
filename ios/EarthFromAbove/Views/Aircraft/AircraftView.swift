import SwiftUI
import EarthFromAboveCore

struct AircraftView: View {
    var aircraft: AircraftInfo

    var body: some View {
        List {
            Section("This aircraft") {
                LabeledContent("Type", value: aircraft.typeName)
                LabeledContent("Code", value: aircraft.typeCode)
                if let r = aircraft.registration { LabeledContent("Registration", value: r) }
                if let y = aircraft.manufacturedYear { LabeledContent("Built", value: String(y)) }
                if let e = aircraft.engines { LabeledContent("Engines", value: e) }
                if let a = aircraft.typicalCruiseAltitudeMeters { LabeledContent("Typical cruise", value: UnitFormat.feet(fromMeters: a)) }
                if let s = aircraft.typicalCruiseSpeedMetersPerSecond { LabeledContent("Typical speed", value: UnitFormat.mph(fromMetersPerSecond: s)) }
            }
            if let n = aircraft.notes {
                Section("Worth knowing") { Text(n) }
            }
            Section("Seating") {
                if let l = aircraft.seatLettersPerRow {
                    let last = String(Character(UnicodeScalar(UInt8(ascii: "A") + UInt8(max(1, min(26, l)) - 1))))
                    Text("\(l) seats across. Seat A is on the left; seat \(last) is on the right.")
                }
                Text("Registration details come from the national aircraft registry; the specific airframe is confirmed once the airline assigns it, usually the day before.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Aircraft")
    }
}
