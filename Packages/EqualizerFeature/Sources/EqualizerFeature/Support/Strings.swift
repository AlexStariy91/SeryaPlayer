import Domain
import Foundation

/// Display strings shared by several screens. Literal keys live in `Resources/Localizable.xcstrings`.
enum Strings {
    /// Built-in names come from Domain in English and are translated through the catalog; user names are shown as typed.
    static func name(of preset: EQPreset) -> String {
        preset.isBuiltIn ? String(localized: String.LocalizationValue(preset.name), bundle: .module) : preset.name
    }

    static func frequency(_ hertz: Float) -> String {
        hertz >= 1000 ? "\(Int(hertz / 1000))k" : "\(Int(hertz))"
    }

    static func message(for error: any Error) -> String {
        switch error {
        case DomainError.emptyName: String(localized: "Enter a name for the preset.", bundle: .module)
        case is PresetFileError: String(localized: "That file isn't a valid preset file.", bundle: .module)
        default: String(localized: "The preset couldn't be saved.", bundle: .module)
        }
    }
}
