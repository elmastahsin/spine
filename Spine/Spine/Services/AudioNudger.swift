import AVFoundation
import Foundation

/// Speaks posture nudges and calibration prompts through AVSpeechSynthesizer.
/// Picks a random message from the pool, skips a new message while already
/// speaking, and selects a voice matching the requested locale and gender
/// preference.
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
    func nudge(locale: Locale, genderPreference: VoiceGenderPreference = .automatic) -> Bool {
        guard let message = Self.nudgeMessages(locale: locale).randomElement() else { return false }
        return speak(message, locale: locale, genderPreference: genderPreference)
    }

    /// Speaks arbitrary text (calibration prompts, etc) in the given locale.
    /// Returns false and does nothing if already speaking.
    @discardableResult
    func speak(_ text: String, locale: Locale, genderPreference: VoiceGenderPreference = .automatic) -> Bool {
        guard !synthesizer.isSpeaking else { return false }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice(for: locale, genderPreference: genderPreference)
        synthesizer.speak(utterance)
        return true
    }

    /// Picks the highest-quality installed voice for the locale, filtered by
    /// gender preference when one is set. `AVSpeechSynthesisVoice(language:)`
    /// alone returns the default (usually the lowest-quality "compact")
    /// voice; Enhanced/Premium voices exist per language but only get used
    /// if selected explicitly here — and only if the user has downloaded one
    /// via System Settings > Accessibility > Spoken Content > System Voice.
    private func voice(for locale: Locale, genderPreference: VoiceGenderPreference) -> AVSpeechSynthesisVoice? {
        let languageCode = locale.language.languageCode?.identifier ?? "en"
        let bcp47 = languageCode == "tr" ? "tr-TR" : "en-US"

        let installed = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == bcp47 }
        let candidates = installed.filter { $0.gender == genderPreference.avGender }
        let best = candidates.max(by: { $0.quality.rawValue < $1.quality.rawValue })
            ?? installed.max(by: { $0.quality.rawValue < $1.quality.rawValue })
        return best ?? AVSpeechSynthesisVoice(language: bcp47)
    }

    static func nudgeMessages(locale: Locale) -> [String] {
        let bundle = LocalizedBundle.resolve(for: locale)
        return [
            String(localized: "Sit up straight", bundle: bundle, locale: locale, comment: "Spoken posture nudge"),
            String(localized: "Roll your shoulders back", bundle: bundle, locale: locale, comment: "Spoken posture nudge"),
            String(localized: "Lift your head", bundle: bundle, locale: locale, comment: "Spoken posture nudge"),
            String(localized: "You're sinking into the screen", bundle: bundle, locale: locale, comment: "Spoken posture nudge"),
        ]
    }
}

private extension VoiceGenderPreference {
    /// `nil` (automatic) never equals a real `AVSpeechSynthesisVoiceGender`,
    /// so the gender filter in `voice(for:genderPreference:)` naturally
    /// yields no candidates and falls back to quality-only selection.
    var avGender: AVSpeechSynthesisVoiceGender? {
        switch self {
        case .automatic: return nil
        case .female: return .female
        case .male: return .male
        }
    }
}
