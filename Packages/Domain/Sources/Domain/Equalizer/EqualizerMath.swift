import Foundation

public enum EqualizerMath {
    public static func clamp(_ gain: Float) -> Float {
        min(max(gain, EQBands.gainRange.lowerBound), EQBands.gainRange.upperBound)
    }

    /// Clamps every gain to ±12 dB and pads with 0 / truncates to exactly `EQBands.count` values.
    public static func normalized(_ gains: [Float]) -> [Float] {
        let clamped = gains.prefix(EQBands.count).map(clamp)
        return clamped + Array(repeating: 0, count: EQBands.count - clamped.count)
    }

    /// Automatic preamp: −(largest positive gain), so boosted bands cannot clip. 0 if nothing is boosted.
    public static func autoPreamp(for gains: [Float]) -> Float {
        let peak = gains.map(clamp).filter { $0 > 0 }.max() ?? 0
        return peak == 0 ? 0 : -peak
    }
}
