import Domain
import Foundation

/// Display strings shared by several screens. Literal keys live in `Resources/Localizable.xcstrings`.
enum Strings {
    /// Built-in names come from Domain in English and are translated through the catalog; user names are shown as typed.
    static func name(of preset: EQPreset) -> String {
        preset.isBuiltIn ? builtInNames[preset.name] ?? preset.name : preset.name
    }

    /// Spelled out as literals so Xcode's string extraction sees them; a dynamic key would mark them stale.
    static let builtInNames: [String: String] = [
        "Flat": String(localized: "Flat", bundle: .module),
        "Rock": String(localized: "Rock", bundle: .module),
        "Pop": String(localized: "Pop", bundle: .module),
        "Dance": String(localized: "Dance", bundle: .module),
        "Electronic": String(localized: "Electronic", bundle: .module),
        "Hip-Hop": String(localized: "Hip-Hop", bundle: .module),
        "Jazz": String(localized: "Jazz", bundle: .module),
        "Classical": String(localized: "Classical", bundle: .module),
        "Acoustic": String(localized: "Acoustic", bundle: .module),
        "R&B": String(localized: "R&B", bundle: .module),
        "Bass Booster": String(localized: "Bass Booster", bundle: .module),
        "Treble Booster": String(localized: "Treble Booster", bundle: .module),
        "Vocal": String(localized: "Vocal", bundle: .module),
        "Loudness": String(localized: "Loudness", bundle: .module),
        "Late Night": String(localized: "Late Night", bundle: .module),
        "Spoken Word": String(localized: "Spoken Word", bundle: .module),
    ]

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
