import CoreMotion
import Foundation
import Observation

/// Full head orientation in degrees, for the live 3D head visualization.
/// Posture detection only ever uses `pitchDegrees` (via `onPitchUpdate`);
/// yaw/roll exist purely for the cosmetic 3D display.
struct HeadAttitude: Equatable {
    let pitchDegrees: Double
    let yawDegrees: Double
    let rollDegrees: Double
}

/// Wraps `CMHeadphoneMotionManager`, exposing connection state and a pitch
/// stream. The CMHeadphoneMotionManagerDelegate connect/disconnect callbacks
/// aren't always delivered promptly (or at all) on macOS, so this service
/// also treats the arrival of the first motion sample as proof of connection.
@Observable
final class HeadMotionService: NSObject {
    enum ConnectionState: Equatable {
        case disconnected
        case connected
    }

    private(set) var connectionState: ConnectionState = .disconnected {
        didSet {
            guard oldValue != connectionState else { return }
            onConnectionChange?(connectionState)
        }
    }
    private(set) var latestPitchDegrees: Double?

    var onConnectionChange: ((ConnectionState) -> Void)?
    var onPitchUpdate: ((_ pitchDegrees: Double, _ timestamp: TimeInterval) -> Void)?
    var onAttitudeUpdate: ((_ attitude: HeadAttitude, _ timestamp: TimeInterval) -> Void)?

    private let motionManager: CMHeadphoneMotionManager

    var isDeviceMotionAvailable: Bool {
        motionManager.isDeviceMotionAvailable
    }

    init(motionManager: CMHeadphoneMotionManager = CMHeadphoneMotionManager()) {
        self.motionManager = motionManager
        super.init()
        self.motionManager.delegate = self
    }

    func start() {
        guard motionManager.isDeviceMotionAvailable, !motionManager.isDeviceMotionActive else { return }
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }

            if self.connectionState != .connected {
                self.connectionState = .connected
            }

            let attitude = HeadAttitude(
                pitchDegrees: motion.attitude.pitch * 180 / .pi,
                yawDegrees: motion.attitude.yaw * 180 / .pi,
                rollDegrees: motion.attitude.roll * 180 / .pi
            )
            self.latestPitchDegrees = attitude.pitchDegrees
            self.onPitchUpdate?(attitude.pitchDegrees, motion.timestamp)
            self.onAttitudeUpdate?(attitude, motion.timestamp)
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        connectionState = .disconnected
        latestPitchDegrees = nil
    }
}

extension HeadMotionService: CMHeadphoneMotionManagerDelegate {
    func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        connectionState = .connected
    }

    func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        connectionState = .disconnected
        latestPitchDegrees = nil
    }
}
