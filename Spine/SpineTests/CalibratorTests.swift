import Testing
@testable import Spine

struct CalibratorTests {
    @Test func lowVarianceSamplesSucceed() {
        let calibrator = Calibrator()
        for pitch in [0.0, 0.5, -0.5, 0.2, -0.2, 0.1] {
            calibrator.addSample(pitchDegrees: pitch)
        }

        let result = calibrator.finish()
        guard case let .success(baseline) = result else {
            Issue.record("Expected success, got \(result)")
            return
        }
        #expect(abs(baseline) < 0.5)
    }

    @Test func highVarianceSamplesAreRejected() {
        let calibrator = Calibrator()
        for pitch in [0.0, 10.0, -8.0, 6.0, -12.0, 9.0] {
            calibrator.addSample(pitchDegrees: pitch)
        }

        let result = calibrator.finish()
        guard case let .failure(reason) = result else {
            Issue.record("Expected failure, got \(result)")
            return
        }
        guard case let .tooMuchMovement(standardDeviation) = reason else {
            Issue.record("Expected tooMuchMovement, got \(reason)")
            return
        }
        #expect(standardDeviation > Calibrator.maxStandardDeviation)
    }

    @Test func tooFewSamplesAreRejected() {
        let calibrator = Calibrator()
        calibrator.addSample(pitchDegrees: 0)

        #expect(calibrator.finish() == .failure(.insufficientSamples))
    }

    @Test func resetClearsCollectedSamples() {
        let calibrator = Calibrator()
        calibrator.addSample(pitchDegrees: 0)
        calibrator.addSample(pitchDegrees: 1)
        calibrator.reset()

        #expect(calibrator.samples.isEmpty)
    }
}
