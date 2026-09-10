import AVFoundation
import Foundation

/// Speaks posture nudges and calibration prompts through AVSpeechSynthesizer.
/// Picks a random message from the pool, skips a new message while already
/// speaking, and selects a voice matching the requested locale.
final class AudioNudger {
    private let synthesizer: AVSpeechSynthesizer

    init(synthesizer: AVSpeechSynthesizer = AVSpeechSynthesizer()) {
        self.synthesizer = synthesizer
    }

    var isSpeaking: Bool {
        synthesizer.isSpeaking
    }

    /// Speaks one random message from the posture nudge pool, in the given
    /// locale. No-op if already speaking, so overlapping nudges never queue up.
    @discardableResult
    func nudge(locale: Locale) -> Bool {
        guard let message = Self.nudgeMessages(locale: locale).randomElement() else { return false }
        return speak(message, locale: locale)
    }

    /// Speaks arbitrary text (calibration prompts, etc) in the given locale.
    /// Returns false and does nothing if already speaking.
    @discardableResult
    func speak(_ text: String, locale: Locale) -> Bool {
        guard !synthesizer.isSpeaking else { return false }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice(for: locale)
        synthesizer.speak(utterance)
        return true
    }

    private func voice(for locale: Locale) -> AVSpeechSynthesisVoice? {
        let languageCode = locale.language.languageCode?.identifier ?? "en"
        let bcp47 = languageCode == "tr" ? "tr-TR" : "en-US"
        return AVSpeechSynthesisVoice(language: bcp47)
    }

    static func nudgeMessages(locale: Locale) -> [String] {
        [
            String(localized: "Sit up straight", locale: locale, comment: "Spoken posture nudge"),
            String(localized: "Roll your shoulders back", locale: locale, comment: "Spoken posture nudge"),
            String(localized: "Lift your head", locale: locale, comment: "Spoken posture nudge"),
            String(localized: "You're sinking into the screen", locale: locale, comment: "Spoken posture nudge"),
        ]
    }
}
