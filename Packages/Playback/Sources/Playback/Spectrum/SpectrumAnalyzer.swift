import Accelerate
import Foundation

/// Turns one window of mono samples into log-spaced band levels, normalized to 0...1.
///
/// Hann window → real FFT (vDSP) → power per bin → the loudest bin of each band in dB, tilted by
/// +3 dB per octave around 1 kHz (music, like pink noise, has less energy per bin up high) and mapped
/// from `floor...ceiling` dB to 0...1. Every buffer is allocated once in `init`; `analyze` allocates
/// nothing, so it can run on the audio tap thread.
final class SpectrumAnalyzer {
    let fftSize: Int
    let bandCount: Int
    let sampleRate: Double

    static let minFrequency = 40.0
    static let maxFrequency = 16000.0
    static let floorDecibels: Float = -72
    static let ceilingDecibels: Float = -12
    static let tiltPerOctave: Float = 3

    private let log2n: vDSP_Length
    private let setup: FFTSetup
    private let window: UnsafeMutablePointer<Float>
    private let windowed: UnsafeMutablePointer<Float>
    private let real: UnsafeMutablePointer<Float>
    private let imaginary: UnsafeMutablePointer<Float>
    private let power: UnsafeMutablePointer<Float>
    /// Half-open bin ranges, one per band.
    private let bandBins: [Range<Int>]
    private let bandTilt: [Float]

    /// - Parameter fftSize: a power of two.
    init(fftSize: Int = 2048, bandCount: Int, sampleRate: Double) {
        precondition(fftSize > 0 && fftSize & (fftSize - 1) == 0, "fftSize must be a power of two")
        self.fftSize = fftSize
        self.bandCount = bandCount
        self.sampleRate = sampleRate
        log2n = vDSP_Length(log2(Double(fftSize)))
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            fatalError("vDSP_create_fftsetup failed for \(fftSize) points")
        }
        self.setup = setup

        let half = fftSize / 2
        window = .allocate(capacity: fftSize)
        vDSP_hann_window(window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        windowed = .allocate(capacity: fftSize)
        real = .allocate(capacity: half)
        imaginary = .allocate(capacity: half)
        power = .allocate(capacity: half)

        let ranges = Self.bandRanges(bandCount: bandCount, fftSize: fftSize, sampleRate: sampleRate)
        bandBins = ranges.map(\.bins)
        bandTilt = ranges.map { Self.tiltPerOctave * Float(log2($0.center / 1000)) }
    }

    deinit {
        vDSP_destroy_fftsetup(setup)
        window.deallocate()
        windowed.deallocate()
        real.deallocate()
        imaginary.deallocate()
        power.deallocate()
    }

    /// Bin ranges and center frequencies of log-spaced bands between `minFrequency` and the lower of
    /// `maxFrequency` and Nyquist. Narrow low bands get at least one bin.
    static func bandRanges(bandCount: Int, fftSize: Int, sampleRate: Double) -> [(bins: Range<Int>, center: Double)] {
        let half = fftSize / 2
        let binWidth = sampleRate / Double(fftSize)
        let top = min(maxFrequency, sampleRate / 2 * 0.95)
        let ratio = log2(top / minFrequency)
        let edges = (0 ... bandCount).map { minFrequency * exp2(ratio * Double($0) / Double(bandCount)) }
        return (0 ..< bandCount).map { band in
            let low = min(max(Int((edges[band] / binWidth).rounded()), 1), half - 1)
            let high = min(max(Int((edges[band + 1] / binWidth).rounded()), low + 1), half)
            return (low ..< high, sqrt(edges[band] * edges[band + 1]))
        }
    }

    /// The band whose range holds `frequency`, if any.
    func band(containing frequency: Double) -> Int? {
        let bin = Int((frequency * Double(fftSize) / sampleRate).rounded())
        return bandBins.firstIndex { $0.contains(bin) }
    }

    /// - Parameters:
    ///   - samples: exactly `fftSize` mono samples, oldest first.
    ///   - bands: room for `bandCount` levels.
    func analyze(_ samples: UnsafePointer<Float>, into bands: UnsafeMutablePointer<Float>) {
        let half = fftSize / 2
        vDSP_vmul(samples, 1, window, 1, windowed, 1, vDSP_Length(fftSize))
        var split = DSPSplitComplex(realp: real, imagp: imaginary)
        windowed.withMemoryRebound(to: DSPComplex.self, capacity: half) { complex in
            vDSP_ctoz(complex, 2, &split, 1, vDSP_Length(half))
        }
        vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
        // `zrip` packs the Nyquist bin into imaginary[0]; the DC bin is never part of a band.
        imaginary[0] = 0
        vDSP_zvmags(&split, 1, power, 1, vDSP_Length(half))

        // `zrip` returns twice the DFT, and the Hann window halves a sine's peak: a full-scale sine
        // has |X| = N / 2. Scale the power so that sine reads 0 dB.
        let scale = 4 / Float(fftSize * fftSize)
        let range = Self.ceilingDecibels - Self.floorDecibels
        for band in 0 ..< bandCount {
            let bins = bandBins[band]
            var peak: Float = 0
            vDSP_maxv(power + bins.lowerBound, 1, &peak, vDSP_Length(bins.count))
            let decibels = 10 * log10f(peak * scale + 1e-12) + bandTilt[band]
            bands[band] = min(max((decibels - Self.floorDecibels) / range, 0), 1)
        }
    }
}
