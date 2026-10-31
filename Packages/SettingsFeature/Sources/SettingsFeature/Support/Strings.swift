import Domain
import Foundation

/// Display strings and formatting. Literal keys live in `Resources/Localizable.xcstrings`.
enum Strings {
    static func name(of theme: AppTheme) -> String {
        switch theme {
        case .system: String(localized: "System", bundle: .module)
        case .light: String(localized: "Light", bundle: .module)
        case .dark: String(localized: "Dark", bundle: .module)
        }
    }

    static var clearFailed: String {
        String(localized: "The artwork cache couldn't be cleared.", bundle: .module)
    }

    /// "12.3 MB", localized. `locale` is a parameter so tests don't depend on the device language.
    static func size(_ bytes: Int64, locale: Locale = .current) -> String {
        bytes.formatted(.byteCount(style: .file, spellsOutZero: false).locale(locale))
    }
}
