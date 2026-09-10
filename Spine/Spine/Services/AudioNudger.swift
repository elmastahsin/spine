import AVFoundation
import Foundation

/// Speaks posture nudges and calibration prompts through AVSpeechSynthesizer.
/// Picks a random message from the pool, skips a new message while already
/// speaking, and selects a voice matching the current language.
final class AudioNudger {
    private let synthesizer: AVSpeechSynthesizer
    private let locale: Locale

    init(synthesizer: AVSpeechSynthesizer = AVSpeechSynthesizer(), locale: Locale = .current) {
        self.synthesizer = synthesizer
        self.locale = locale
    }

    var isSpeaking: Bool {
        synthesizer.isSpeaking
    }

    /// Speaks one random message from the posture nudge pool. No-op if
    /// already speaking, so overlapping nudges never queue up.
    @discardableResult
    func nudge() -> Bool {
        guard let message = Self.nudgeMessages.randomElement() else { return false }
        return speak(message)
    }

    /// Speaks arbitrary text (calibration prompts, etc). Returns false and
    /// does nothing if already speaking.
    @discardableResult
    func speak(_ text: String) -> Bool {
        guard !synthesizer.isSpeaking else { return false }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voiceForCurrentLocale()
        synthesizer.speak(utterance)
        return true
    }

    private func voiceForCurrentLocale() -> AVSpeechSynthesisVoice? {
        let languageCode = locale.language.languageCode?.identifier ?? "en"
        let bcp47 = languageCode == "tr" ? "tr-TR" : "en-US"
        return AVSpeechSynthesisVoice(language: bcp47)
    }

    static var nudgeMessages: [String] {
        [
            String(localized: "Sit up straight", comment: "Spoken posture nudge"),
            String(localized: "Roll your shoulders back", comment: "Spoken posture nudge"),
            String(localized: "Lift your head", comment: "Spoken posture nudge"),
            String(localized: "You're sinking into the screen", comment: "Spoken posture nudge"),
        ]
    }
}
