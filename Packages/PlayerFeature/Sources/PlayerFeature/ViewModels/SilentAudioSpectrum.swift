import Domain

/// A spectrum that never yields: the visualizer rests. For previews and tests that don't care.
@MainActor
final class SilentAudioSpectrum: AudioSpectrumProviding {
    let bandCount = 28

    func spectrum() -> AsyncStream<[Float]> {
        AsyncStream { _ in }
    }
}

/// A fixed, music-like frame for previews and snapshots.
enum PreviewSpectrumLevels {
    static let sample: [Float] = [
        0.55, 0.72, 0.86, 0.8, 0.66, 0.7, 0.58, 0.62, 0.74, 0.6, 0.48, 0.52, 0.64, 0.5,
        0.42, 0.46, 0.38, 0.44, 0.36, 0.3, 0.34, 0.27, 0.22, 0.25, 0.18, 0.14, 0.1, 0.06,
    ]
}
