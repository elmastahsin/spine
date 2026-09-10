import Foundation
import Observation

/// UserDefaults-backed persistence for calibration baseline and user prefs.
@Observable
final class SettingsStore {
    static let cooldownOptions: [TimeInterval] = [60, 90, 180]

    private enum Keys {
        static let baseline = "settings.baseline"
        static let sensitivity = "settings.sensitivity"
        static let cooldown = "settings.cooldown"
        static let voiceEnabled = "settings.voiceEnabled"
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
    }
}
