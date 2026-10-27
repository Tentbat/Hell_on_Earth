import Foundation

public enum UnitFormat {
    public static func feet(fromMeters m: Double) -> String {
        let ft = Int((m * Geodesy.feetPerMeter / 100).rounded() * 100)
        return "\(ft.formatted()) ft"
    }
    public static func knots(fromMetersPerSecond v: Double) -> String {
        "\(Int((v * 1.943_844).rounded())) kt"
    }
    public static func mph(fromMetersPerSecond v: Double) -> String {
        "\(Int((v * 2.236_936).rounded())) mph"
    }
    public static func miles(fromMeters m: Double) -> String {
        let mi = m / 1609.344
        return mi < 10 ? String(format: "%.1f mi", mi) : "\(Int(mi.rounded())) mi"
    }
    public static func duration(_ seconds: Double) -> String {
        let s = max(0, Int(seconds))
        let h = s / 3600, m = (s % 3600) / 60
        return h > 0 ? "\(h) h \(m) min" : "\(m) min"
    }
    public static func clock(_ seconds: Double) -> String {
        let s = max(0, Int(seconds))
        return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
}
