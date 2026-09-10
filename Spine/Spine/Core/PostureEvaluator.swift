import Foundation

/// Coarse posture classification derived from head pitch deviation.
enum PostureStatus: Equatable {
    case good
    case drifting
    case bad
}

/// Sensitivity presets map to the pitch deviation (in degrees from baseline)
/// that counts as "bad" posture.
enum PostureSensitivity: String, CaseIterable, Codable {
    case low
    case medium
    case high

    var thresholdDegrees: Double {
        switch self {
        case .low: return 16
        case .medium: return 12
        case .high: return 8
        }
    }
}

/// Result of feeding one pitch sample into a `PostureEvaluator`.
struct PostureEvaluation: Equatable {
    let status: PostureStatus
    let deviationDegrees: Double
    let shouldNudge: Bool
}

/// Turns a raw stream of head-pitch samples into posture state, free of any
/// CoreMotion dependency so it can be unit tested with injected timestamps.
///
/// Behavior:
/// - Smooths incoming pitch with an exponential moving average.
/// - Applies hysteresis around the sensitivity threshold: enters "over
///   threshold" at `threshold`, only exits back below `threshold - hysteresisMargin`.
/// - Requires `gracePeriod` of continuous over-threshold deviation before
///   reporting `.bad` (short glances don't count).
/// - Once `.bad`, allows at most one `shouldNudge == true` result per
///   `cooldown` interval, so a continuous slouch produces periodic reminders
///   rather than a single one-off nudge or a flood of them.
final class PostureEvaluator {
    let baseline: Double
    var sensitivity: PostureSensitivity
    let gracePeriod: TimeInterval
    var cooldown: TimeInterval
    let hysteresisMargin: Double
    let smoothingFactor: Double

    private var smoothedPitch: Double?
    private var isOverThreshold = false
    private var overThresholdSince: TimeInterval?
    private var lastNudgeTimestamp: TimeInterval?

    init(
        baseline: Double,
        sensitivity: PostureSensitivity,
        gracePeriod: TimeInterval = 8,
        cooldown: TimeInterval = 90,
        hysteresisMargin: Double = 4,
        smoothingFactor: Double = 0.2
    ) {
        self.baseline = baseline
        self.sensitivity = sensitivity
        self.gracePeriod = gracePeriod
        self.cooldown = cooldown
        self.hysteresisMargin = hysteresisMargin
        self.smoothingFactor = smoothingFactor
    }

    @discardableResult
    func evaluate(pitchDegrees: Double, timestamp: TimeInterval) -> PostureEvaluation {
        let smoothed = smoothedPitch.map { $0 + smoothingFactor * (pitchDegrees - $0) } ?? pitchDegrees
        smoothedPitch = smoothed

        let deviation = abs(smoothed - baseline)
        let threshold = sensitivity.thresholdDegrees
        let exitThreshold = threshold - hysteresisMargin

        if isOverThreshold {
            if deviation < exitThreshold {
                isOverThreshold = false
                overThresholdSince = nil
            }
        } else if deviation >= threshold {
            isOverThreshold = true
            overThresholdSince = timestamp
        }

        guard isOverThreshold, let since = overThresholdSince else {
            return PostureEvaluation(status: .good, deviationDegrees: deviation, shouldNudge: false)
        }

        guard timestamp - since >= gracePeriod else {
            return PostureEvaluation(status: .drifting, deviationDegrees: deviation, shouldNudge: false)
        }

        let cooldownElapsed = lastNudgeTimestamp.map { timestamp - $0 >= cooldown } ?? true
        guard cooldownElapsed else {
            return PostureEvaluation(status: .bad, deviationDegrees: deviation, shouldNudge: false)
        }

        lastNudgeTimestamp = timestamp
        return PostureEvaluation(status: .bad, deviationDegrees: deviation, shouldNudge: true)
    }
}
