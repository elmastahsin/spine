import Foundation
import Observation

/// Overrides which language the UI and spoken alerts use, independent of
/// the Mac's system language.
enum LanguagePreference: String, CaseIterable, Codable {
    case system
    case en
    case tr

    var locale: Locale {
        switch self {
        case .system: return Locale.current
        case .en: return Locale(identifier: "en")
        case .tr: return Locale(identifier: "tr")
        }
    }
}

/// Which voice gender to prefer when multiple voices are installed for a
/// language. `.automatic` picks the highest-quality voice regardless of
/// gender.
enum VoiceGenderPreference: String, CaseIterable, Codable {
    case automatic
    case female
    case male
}

/// UserDefaults-backed persistence for calibration baseline and user prefs.
@Observable
final class SettingsStore {
    static let cooldownOptions: [TimeInterval] = [60, 90, 180]

    private enum Keys {
        static let baseline = "settings.baseline"
        static let sensitivity = "settings.sensitivity"
        static let cooldown = "settings.cooldown"
        static let voiceEnabled = "settings.voiceEnabled"
        static let languagePreference = "settings.languagePreference"
        static let voiceGender = "settings.voiceGender"
    }

    private let defaults: UserDefaults

    var baseline: Double? {
        didSet {
            if let baseline {
                defaults.set(baseline, forKey: Keys.baseline)
            } else {
                defaults.removeObject(forKey: Keys.baseline)
            }
        }
    }

    var sensitivity: PostureSensitivity {
        didSet { defaults.set(sensitivity.rawValue, forKey: Keys.sensitivity) }
    }

    var cooldown: TimeInterval {
        didSet { defaults.set(cooldown, forKey: Keys.cooldown) }
    }

    var voiceEnabled: Bool {
        didSet { defaults.set(voiceEnabled, forKey: Keys.voiceEnabled) }
    }

    var languagePreference: LanguagePreference {
        didSet { defaults.set(languagePreference.rawValue, forKey: Keys.languagePreference) }
    }

    var voiceGender: VoiceGenderPreference {
        didSet { defaults.set(voiceGender.rawValue, forKey: Keys.voiceGender) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        baseline = defaults.object(forKey: Keys.baseline) != nil
            ? defaults.double(forKey: Keys.baseline)
            : nil

        if let rawSensitivity = defaults.string(forKey: Keys.sensitivity),
           let storedSensitivity = PostureSensitivity(rawValue: rawSensitivity) {
            sensitivity = storedSensitivity
        } else {
            sensitivity = .medium
        }

        let storedCooldown = defaults.double(forKey: Keys.cooldown)
        cooldown = SettingsStore.cooldownOptions.contains(storedCooldown) ? storedCooldown : 90

        voiceEnabled = defaults.object(forKey: Keys.voiceEnabled) != nil
            ? defaults.bool(forKey: Keys.voiceEnabled)
            : true

        if let rawLanguage = defaults.string(forKey: Keys.languagePreference),
           let storedLanguage = LanguagePreference(rawValue: rawLanguage) {
            languagePreference = storedLanguage
        } else {
            languagePreference = .system
        }

        if let rawGender = defaults.string(forKey: Keys.voiceGender),
           let storedGender = VoiceGenderPreference(rawValue: rawGender) {
            voiceGender = storedGender
        } else {
            voiceGender = .automatic
        }
    }
}
