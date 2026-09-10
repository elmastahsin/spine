import Foundation
import Testing
@testable import Spine

struct PostureEvaluatorTests {
    /// medium sensitivity: threshold 12°, exit 8°, grace 8s, cooldown 90s.
    private func makeEvaluator(
        baseline: Double = 0,
        sensitivity: PostureSensitivity = .medium,
        gracePeriod: TimeInterval = 8,
        cooldown: TimeInterval = 90,
        smoothingFactor: Double = 1 // disable smoothing so tests reason about raw pitch
    ) -> PostureEvaluator {
        PostureEvaluator(
            baseline: baseline,
            sensitivity: sensitivity,
            gracePeriod: gracePeriod,
            cooldown: cooldown,
            smoothingFactor: smoothingFactor
        )
    }

    @Test func belowThresholdNeverNudges() {
        let evaluator = makeEvaluator()
        var t: TimeInterval = 0
        for _ in 0..<20 {
            let result = evaluator.evaluate(pitchDegrees: 5, timestamp: t) // deviation 5 < 12
            #expect(result.status == .good)
            #expect(result.shouldNudge == false)
            t += 1
        }
    }

    @Test func aboveThresholdBeforeGracePeriodDoesNotNudge() {
        let evaluator = makeEvaluator()
        let result = evaluator.evaluate(pitchDegrees: 20, timestamp: 0) // deviation 20 >= 12
        #expect(result.status == .drifting)
        #expect(result.shouldNudge == false)

        let stillDrifting = evaluator.evaluate(pitchDegrees: 20, timestamp: 7.9)
        #expect(stillDrifting.status == .drifting)
        #expect(stillDrifting.shouldNudge == false)
    }

    @Test func gracePeriodElapsedNudgesOnceThenBlocksDuringCooldown() {
        let evaluator = makeEvaluator()
        evaluator.evaluate(pitchDegrees: 20, timestamp: 0) // enters over-threshold

        let atGraceEnd = evaluator.evaluate(pitchDegrees: 20, timestamp: 8)
        #expect(atGraceEnd.status == .bad)
        #expect(atGraceEnd.shouldNudge == true)

        // Still bad, well within the 90s cooldown: no second nudge.
        let duringCooldown = evaluator.evaluate(pitchDegrees: 20, timestamp: 30)
        #expect(duringCooldown.status == .bad)
        #expect(duringCooldown.shouldNudge == false)

        let stillWithinCooldown = evaluator.evaluate(pitchDegrees: 20, timestamp: 97)
        #expect(stillWithinCooldown.shouldNudge == false)

        // Cooldown has fully elapsed since the first nudge (t=8, +90 = 98).
        let afterCooldown = evaluator.evaluate(pitchDegrees: 20, timestamp: 99)
        #expect(afterCooldown.status == .bad)
        #expect(afterCooldown.shouldNudge == true)
    }

    @Test func hysteresisBandDoesNotFlipState() {
        let evaluator = makeEvaluator()

        // Rising from good into the hysteresis band (8..<12) does not enter "over threshold".
        let inBandFromGood = evaluator.evaluate(pitchDegrees: 10, timestamp: 0)
        #expect(inBandFromGood.status == .good)

        // Cross into bad territory, then wait out the grace period.
        evaluator.evaluate(pitchDegrees: 20, timestamp: 1)
        let bad = evaluator.evaluate(pitchDegrees: 20, timestamp: 9)
        #expect(bad.status == .bad)

        // Dropping into the hysteresis band (8..<12) from bad does not exit to good.
        let inBandFromBad = evaluator.evaluate(pitchDegrees: 10, timestamp: 10)
        #expect(inBandFromBad.status == .bad)

        // Only dropping below the exit threshold (8) actually exits.
        let belowExit = evaluator.evaluate(pitchDegrees: 5, timestamp: 11)
        #expect(belowExit.status == .good)
    }

    @Test func newBadEpisodeAfterRecoveryCanNudgeOnceCooldownAllows() {
        let evaluator = makeEvaluator(cooldown: 5)
        evaluator.evaluate(pitchDegrees: 20, timestamp: 0)
        let firstNudge = evaluator.evaluate(pitchDegrees: 20, timestamp: 8)
        #expect(firstNudge.shouldNudge == true)

        // Recover to good.
        let recovered = evaluator.evaluate(pitchDegrees: 0, timestamp: 9)
        #expect(recovered.status == .good)

        // Slouch again after the (short) cooldown has elapsed.
        evaluator.evaluate(pitchDegrees: 20, timestamp: 20)
        let secondEpisodeNudge = evaluator.evaluate(pitchDegrees: 20, timestamp: 28)
        #expect(secondEpisodeNudge.status == .bad)
        #expect(secondEpisodeNudge.shouldNudge == true)
    }
}
