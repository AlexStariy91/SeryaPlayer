import Domain

/// Yields `frames` to every subscriber and finishes; counts subscriptions.
@MainActor
public final class FakeAudioSpectrum: AudioSpectrumProviding {
    public let bandCount: Int
    public var frames: [[Float]]
    public private(set) var subscriptionCount = 0

    public init(bandCount: Int = 28, frames: [[Float]] = []) {
        self.bandCount = bandCount
        self.frames = frames
    }

    public func spectrum() -> AsyncStream<[Float]> {
        subscriptionCount += 1
        let frames = frames
        return AsyncStream { continuation in
            frames.forEach { continuation.yield($0) }
            continuation.finish()
        }
    }
}
