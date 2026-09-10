import Foundation

/// Resolves the `.lproj` bundle for an explicit locale override.
///
/// `String(localized:locale:)`'s `locale` argument does not force which
/// translation is picked — that's still driven by the system's language
/// negotiation (`Bundle.preferredLocalizations`), so it's silently ignored
/// whenever the override differs from the Mac's system language. Passing
/// the resolved bundle explicitly is what actually forces the language.
enum LocalizedBundle {
    static func resolve(for locale: Locale) -> Bundle {
        guard let languageCode = locale.language.languageCode?.identifier,
              let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else {
            return .main
        }
        return bundle
    }
}
