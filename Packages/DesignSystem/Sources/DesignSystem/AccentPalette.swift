import SwiftUI

/// Accent colors. `serya` (#1C283F) is the default; dark mode uses a lighter
/// variant of the same hue, otherwise it blends into the background.
/// TODO(stage-0/design-system): 6–8 more options, contrast checks.
public struct AccentOption: Identifiable, Sendable {
    public let id: String
    public let name: String.LocalizationValue
    public let light: UInt32
    public let dark: UInt32

    public var color: Color {
        Color(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

public enum AccentPalette {
    public static let serya = AccentOption(id: "serya", name: "Serya Blue", light: 0x1C283F, dark: 0x8FA6D1)
    public static let all: [AccentOption] = [serya]

    public static func option(id: String) -> AccentOption {
        all.first { $0.id == id } ?? serya
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
