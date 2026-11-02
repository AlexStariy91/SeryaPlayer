import Foundation

/// Live spectrum of what is playing, for the visualizer. Measured after the equalizer.
///
/// Analysis runs only while someone is subscribed: the first subscriber starts it and the last one
/// to go away stops it, so a visualizer that is off screen costs nothing.
@MainActor
public protocol AudioSpectrumProviding: AnyObject, Sendable {
    /// Number of bands in every value of `spectrum()`, low to high frequencies.
    var bandCount: Int { get }
    /// A new stream per subscriber: band levels, each normalized to 0...1, already smoothed for display.
    /// Values arrive at up to ~30 per second while there is sound and ease down to zeros when it stops.
    func spectrum() -> AsyncStream<[Float]>
}
