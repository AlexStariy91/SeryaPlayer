import SwiftUI

/// Typography tokens. Only text styles, so everything follows Dynamic Type.
public enum AppFont {
    public static let screenTitle = Font.largeTitle.weight(.bold)
    public static let title = Font.title2.weight(.bold)
    public static let sectionTitle = Font.title3.weight(.semibold)
    public static let headline = Font.headline
    public static let body = Font.body
    public static let rowTitle = Font.body
    public static let rowSubtitle = Font.subheadline
    public static let caption = Font.caption
    /// Playback times: digits of equal width so they don't jitter.
    public static let time = Font.caption.monospacedDigit()
    public static let playerTitle = Font.title2.weight(.semibold)
    public static let playerSubtitle = Font.title3
}
