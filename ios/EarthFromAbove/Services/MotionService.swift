import Foundation
import CoreMotion

/// Barometer for flight phase, and device attitude for camera pointing angle.
/// Note: the magnetometer is useless inside the fuselage, so we never read heading
/// from it. Camera bearing comes from aircraft track plus the window side.
final class MotionService {
    var onCabinAltitude: ((Double, Date) -> Void)?

    private let altimeter = CMAltimeter()
    private let motion = CMMotionManager()
    private let queue = OperationQueue()

    /// Latest device attitude: pitch and roll in radians, gravity-referenced.
    private(set) var latestAttitude: (pitch: Double, roll: Double, yaw: Double)?

    var isBarometerAvailable: Bool { CMAltimeter.isRelativeAltitudeAvailable() }

    func start() {
        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.startRelativeAltitudeUpdates(to: queue) { [weak self] data, _ in
                guard let data else { return }
                // Relative altitude in metres since start; absolute level does not matter
                // for phase detection, only the trend.
                self?.onCabinAltitude?(data.relativeAltitude.doubleValue, Date())
            }
        }
        if motion.isDeviceMotionAvailable {
            motion.deviceMotionUpdateInterval = 0.2
            motion.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: queue) { [weak self] dm, _ in
                guard let a = dm?.attitude else { return }
                self?.latestAttitude = (a.pitch, a.roll, a.yaw)
            }
        }
    }

    func stop() {
        altimeter.stopRelativeAltitudeUpdates()
        motion.stopDeviceMotionUpdates()
    }

    /// Camera depression angle (degrees below horizontal) for the rear camera when
    /// the phone is held up to the window. With the phone upright in portrait, the
    /// rear camera looks along -Z of the device; pitch of the device from vertical
    /// gives the depression. Returns 20 degrees as a sensible default when unknown.
    func cameraDepressionDegrees() -> Double {
        guard let a = latestAttitude else { return 20 }
        // Device pitch: 0 when flat on its back (camera straight down), pi/2 when upright.
        // Depression below horizontal = 90 - pitch (in degrees), clamped.
        let pitchDeg = abs(a.pitch) * 180 / .pi
        // Landscape holds swap the role of roll and pitch; take whichever is more vertical.
        let rollDeg = abs(a.roll) * 180 / .pi
        let tilt = max(pitchDeg, min(90, rollDeg))
        return max(0, min(90, 90 - tilt))
    }
}
