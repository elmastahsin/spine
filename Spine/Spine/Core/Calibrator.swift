import Foundation

enum CalibrationFailureReason: Equatable {
    case insufficientSamples
    case tooMuchMovement(standardDeviation: Double)
}

enum CalibrationResult: Equatable {
    case success(baseline: Double)
    case failure(CalibrationFailureReason)
}

/// Collects pitch samples during the calibration countdown and turns them
/// into a baseline, rejecting the attempt if the user moved too much.
final class Calibrator {
    /// Above this standard deviation (degrees) the sample set is rejected.
    static let maxStandardDeviation: Double = 3

    private static let minimumSampleCount = 2

    private(set) var samples: [Double] = []

    func addSample(pitchDegrees: Double) {
        samples.append(pitchDegrees)
    }

    func reset() {
        samples.removeAll()
    }

    func finish() -> CalibrationResult {
        guard samples.count >= Self.minimumSampleCount else {
            return .failure(.insufficientSamples)
        }

        let mean = samples.reduce(0, +) / Double(samples.count)
        let variance = samples.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(samples.count)
        let standardDeviation = variance.squareRoot()

        guard standardDeviation <= Self.maxStandardDeviation else {
            return .failure(.tooMuchMovement(standardDeviation: standardDeviation))
        }

        return .success(baseline: mean)
    }
}
