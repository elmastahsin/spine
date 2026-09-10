import CoreMotion
import Foundation
import Observation

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

    private(set) var connectionState: ConnectionState = .disconnected
    private(set) var latestPitchDegrees: Double?

    var onPitchUpdate: ((_ pitchDegrees: Double, _ timestamp: TimeInterval) -> Void)?

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

            let pitchDegrees = motion.attitude.pitch * 180 / .pi
            self.latestPitchDegrees = pitchDegrees
            self.onPitchUpdate?(pitchDegrees, motion.timestamp)
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
