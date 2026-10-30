import SwiftUI

/// An accent color option. `id` is stored in `AppSettings.accentColorID`: never change existing ids.
public struct AccentOption: Identifiable, Sendable {
    public let id: String
    public let name: String.LocalizationValue
    /// RGB hex for the light theme.
    public let light: UInt32
    /// RGB hex for the dark theme.
    public let dark: UInt32

    public var color: Color {
        Color(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

/// Accent colors. `serya` (#1C283F) is the default; the dark variant of each option is a lighter tint
/// of the same hue, otherwise it blends into a dark background. Every variant keeps a WCAG contrast
/// of at least 3:1 against its theme background (checked in tests).
public enum AccentPalette {
    public static let serya = AccentOption(id: "serya", name: "Serya Blue", light: 0x1C283F, dark: 0x8FA6D1)
    public static let crimson = AccentOption(id: "crimson", name: "Crimson", light: 0xB3202F, dark: 0xFF6B7A)
    public static let orange = AccentOption(id: "orange", name: "Orange", light: 0xC2410C, dark: 0xFF9F5A)
    public static let amber = AccentOption(id: "amber", name: "Amber", light: 0xA16207, dark: 0xFFC94D)
    public static let green = AccentOption(id: "green", name: "Green", light: 0x15803D, dark: 0x5FD38A)
    public static let teal = AccentOption(id: "teal", name: "Teal", light: 0x0F766E, dark: 0x4FD1C5)
    public static let indigo = AccentOption(id: "indigo", name: "Indigo", light: 0x4338CA, dark: 0x9AA2FF)
    public static let purple = AccentOption(id: "purple", name: "Purple", light: 0x7E22CE, dark: 0xC58BFF)
    public static let pink = AccentOption(id: "pink", name: "Pink", light: 0xBE185D, dark: 0xFF7EB6)

    public static let all: [AccentOption] = [serya, crimson, orange, amber, green, teal, indigo, purple, pink]

    /// The option with this id, or `serya` for an unknown id.
    public static func option(id: String) -> AccentOption {
        all.first { $0.id == id } ?? serya
    }

    /// Theme backgrounds the contrast is checked against (`systemBackground`).
    static let lightBackground: UInt32 = 0xFFFFFF
    static let darkBackground: UInt32 = 0x000000
}

extension AccentOption {
    /// WCAG 2.x contrast ratio of the light variant against the light background.
    var lightContrast: Double {
        ContrastRatio.ratio(light, AccentPalette.lightBackground)
    }

    /// WCAG 2.x contrast ratio of the dark variant against the dark background.
    var darkContrast: Double {
        ContrastRatio.ratio(dark, AccentPalette.darkBackground)
    }
}

enum ContrastRatio {
    static func luminance(_ rgb: UInt32) -> Double {
        func channel(_ shift: UInt32) -> Double {
            let value = Double((rgb >> shift) & 0xFF) / 255
            return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
    }

    static func ratio(_ first: UInt32, _ second: UInt32) -> Double {
        let a = luminance(first)
        let b = luminance(second)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}

extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
