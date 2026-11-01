import Accelerate
import Foundation

/// Maps band levels in dB to 0...1 against a running reference, so a loud master and a quiet audiobook
/// both use most of the height instead of sitting at the ceiling or near the floor.
///
/// The reference follows the loudest band of each analysis: up quickly (so a transient after a quiet
/// part shoots above it and reaches the top), down slowly (so it doesn't pump between beats). A band at
/// the reference shows at `peakLevel`; the `window` dB below it spread over the rest. The reference never
/// drops below `minReference`, so near-silence isn't amplified into noise and silence stays at zero.
/// A few scalar operations per analysis, no allocations.
struct AutoGain {
    /// Where a band at the reference lands: typical peaks sit here, louder moments reach the top.
    static let peakLevel: Float = 0.8
    /// dB below the reference that are visible at all.
    static let window: Float = 30
    /// The quietest reference, in the analyzer's tilted dB (a full-scale sine reads 0 dB).
    static let minReference: Float = -42
    /// Time constants of the reference, in seconds.
    static let attack = 0.15
    static let release = 3.0

    /// A typical music level, so the first frames after subscribing are neither pinned nor dim.
    private(set) var reference: Float = -24

    /// Converts `count` levels in dB to 0...1 in place, `elapsed` seconds after the previous call.
    mutating func normalize(_ bands: UnsafeMutablePointer<Float>, count: Int, elapsed: Double) {
        var loudest: Float = 0
        vDSP_maxv(bands, 1, &loudest, vDSP_Length(count))
        let timeConstant = loudest > reference ? Self.attack : Self.release
        let follow = Float(1 - exp(-elapsed / timeConstant))
        reference = max(reference + (loudest - reference) * follow, Self.minReference)

        let bottom = reference - Self.window
        let scale = Self.peakLevel / Self.window
        for band in 0 ..< count {
            bands[band] = min(max((bands[band] - bottom) * scale, 0), 1)
        }
    }
}
