import SwiftUI

/// Semantic colors. Built on system colors, so light/dark and increased contrast work automatically.
public enum SemanticColor {
    /// Screen background.
    public static let background = Color(uiColor: .systemBackground)
    /// Cards, grouped rows, mini player fallback.
    public static let secondaryBackground = Color(uiColor: .secondarySystemBackground)
    /// Nested content on a secondary background.
    public static let tertiaryBackground = Color(uiColor: .tertiarySystemBackground)
    public static let textPrimary = Color(uiColor: .label)
    public static let textSecondary = Color(uiColor: .secondaryLabel)
    public static let textTertiary = Color(uiColor: .tertiaryLabel)
    public static let separator = Color(uiColor: .separator)
    /// Empty track of a slider.
    public static let fill = Color(uiColor: .tertiarySystemFill)
}
