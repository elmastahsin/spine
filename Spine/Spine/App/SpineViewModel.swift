import Foundation
import Observation

/// Owns the app lifecycle: wires HeadMotionService's pitch stream into a
/// Calibrator or PostureEvaluator depending on state, and exposes everything
/// MenuContentView / CalibrationView need to render.
@Observable
final class SpineViewModel {
    enum CalibrationFeedback: Equatable {
        case tooMuchMovement
    }

    private(set) var state: AppState = .waitingForAirPods
    private(set) var calibrationFeedback: CalibrationFeedback?
    private(set) var currentDeviationDegrees: Double?

    let settings: SettingsStore

    private let motionService: HeadMotionService
    private let audioNudger: AudioNudger

    private var evaluator: PostureEvaluator?
    private var calibrator: Calibrator?
    private var calibrationTimer: Timer?
    private var calibrationElapsed: TimeInterval = 0
    private let calibrationDuration: TimeInterval = 3
    private let calibrationTickInterval: TimeInterval = 0.1

    var menuBarIconName: String {
        switch state {
        case .waitingForAirPods, .needsCalibration, .calibrating:
            return "airpods"
        case .monitoring(let status):
            return status == .bad ? "figure.fall" : "figure.stand"
        case .paused:
            return "pause.circle"
        }
    }

    var menuBarIconOpacity: Double {
        if case .waitingForAirPods = state { return 0.4 }
        return 1
    }

    /// The locale the UI and spoken alerts should use, per the user's
    /// language preference (independent of the Mac's system language).
    var locale: Locale {
        settings.languagePreference.locale
    }

    func localized(_ key: String.LocalizationValue, comment: StaticString = "") -> String {
        String(localized: key, locale: locale, comment: comment)
    }

    init(
        settings: SettingsStore = SettingsStore(),
        motionService: HeadMotionService = HeadMotionService(),
        audioNudger: AudioNudger = AudioNudger()
    ) {
        self.settings = settings
        self.motionService = motionService
        self.audioNudger = audioNudger

        motionService.onConnectionChange = { [weak self] connectionState in
            self?.handleConnectionChange(connectionState)
        }
        motionService.onPitchUpdate = { [weak self] pitch, timestamp in
            self?.handlePitch(pitch, timestamp: timestamp)
        }

        motionService.start()
    }

    // MARK: - Connection

    private func handleConnectionChange(_ connectionState: HeadMotionService.ConnectionState) {
        switch connectionState {
        case .connected:
            calibrationFeedback = nil
            if let baseline = settings.baseline {
                evaluator = PostureEvaluator(baseline: baseline, sensitivity: settings.sensitivity, cooldown: settings.cooldown)
                state = .monitoring(.good)
            } else {
                state = .needsCalibration
            }
        case .disconnected:
            calibrationTimer?.invalidate()
            calibrationTimer = nil
            calibrator = nil
            evaluator = nil
            currentDeviationDegrees = nil
            state = .waitingForAirPods
        }
    }

    // MARK: - Posture

    private func handlePitch(_ pitchDegrees: Double, timestamp: TimeInterval) {
        if calibrator != nil {
            calibrator?.addSample(pitchDegrees: pitchDegrees)
            return
        }

        guard case .monitoring = state, let evaluator else { return }

        let evaluation = evaluator.evaluate(pitchDegrees: pitchDegrees, timestamp: timestamp)
        currentDeviationDegrees = evaluation.deviationDegrees
        state = .monitoring(evaluation.status)

        if evaluation.shouldNudge, settings.voiceEnabled {
            audioNudger.nudge(locale: locale)
        }
    }

    // MARK: - Calibration

    func startCalibration() {
        guard motionService.connectionState == .connected else { return }

        calibrationTimer?.invalidate()
        calibrator = Calibrator()
        calibrationFeedback = nil
        calibrationElapsed = 0
        state = .calibrating(progress: 0)

        audioNudger.speak(
            localized("Sit up straight and look at the screen.", comment: "Spoken prompt at the start of calibration"),
            locale: locale
        )

        calibrationTimer = Timer.scheduledTimer(withTimeInterval: calibrationTickInterval, repeats: true) { [weak self] _ in
            self?.tickCalibration()
        }
    }

    private func tickCalibration() {
        calibrationElapsed += calibrationTickInterval
        state = .calibrating(progress: min(calibrationElapsed / calibrationDuration, 1))

        guard calibrationElapsed >= calibrationDuration else { return }

        calibrationTimer?.invalidate()
        calibrationTimer = nil
        finishCalibration()
    }

    private func finishCalibration() {
        guard let calibrator else { return }
        self.calibrator = nil

        switch calibrator.finish() {
        case .success(let baseline):
            settings.baseline = baseline
            evaluator = PostureEvaluator(baseline: baseline, sensitivity: settings.sensitivity, cooldown: settings.cooldown)
            calibrationFeedback = nil
            state = .monitoring(.good)
            audioNudger.speak(
                localized("Calibration complete.", comment: "Spoken message on successful calibration"),
                locale: locale
            )
        case .failure:
            calibrationFeedback = .tooMuchMovement
            state = .needsCalibration
            audioNudger.speak(
                localized("You moved too much. Try again.", comment: "Spoken message when calibration is rejected"),
                locale: locale
            )
        }
    }

    // MARK: - Settings

    func updateSensitivity(_ sensitivity: PostureSensitivity) {
        settings.sensitivity = sensitivity
        evaluator?.sensitivity = sensitivity
    }

    func updateCooldown(_ cooldown: TimeInterval) {
        settings.cooldown = cooldown
        evaluator?.cooldown = cooldown
    }

    func setVoiceEnabled(_ enabled: Bool) {
        settings.voiceEnabled = enabled
    }

    func updateLanguagePreference(_ preference: LanguagePreference) {
        settings.languagePreference = preference
    }

    // MARK: - Pause

    func togglePause() {
        switch state {
        case .paused:
            state = .monitoring(.good)
        case .monitoring:
            state = .paused
        default:
            break
        }
    }
}
