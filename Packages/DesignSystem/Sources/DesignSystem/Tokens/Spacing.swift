import CoreGraphics

/// Spacing scale (pt). Use these instead of magic numbers.
public enum Spacing {
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let s: CGFloat = 8
    public static let m: CGFloat = 12
    public static let l: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
    /// Horizontal screen margin.
    public static let screenMargin: CGFloat = 16
}

/// Corner radii (pt).
public enum Radius {
    public static let s: CGFloat = 6
    public static let m: CGFloat = 10
    public static let l: CGFloat = 16
    public static let xl: CGFloat = 24
}

/// Artwork sizes used across the app.
public enum ArtworkSize: Sendable, Equatable {
    /// 48 pt, list rows.
    case row
    /// 44 pt, mini player.
    case mini
    /// 160 pt, album / playlist grids.
    case grid
    /// 320 pt, full player.
    case player
    case custom(CGFloat)

    public var points: CGFloat {
        switch self {
        case .row: 48
        case .mini: 44
        case .grid: 160
        case .player: 320
        case let .custom(value): value
        }
    }

    /// Corner radius that scales with the artwork.
    public var cornerRadius: CGFloat {
        switch self {
        case .row, .mini: Radius.s
        case .grid: Radius.m
        case .player: Radius.l
        case let .custom(value): max(Radius.s, value * 0.06)
        }
    }
}
