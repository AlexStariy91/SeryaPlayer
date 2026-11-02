import SwiftUI

/// Where a row's live bars get their levels: a new stream per call, band levels in 0...1.
public typealias SpectrumLevelsSource = @MainActor () -> AsyncStream<[Float]>

/// Averages spectrum bands into a few groups for small displays.
public enum BandGrouping {
    /// Splits `values` into `groups` consecutive, near-equal groups and averages each.
    /// Fewer values than groups repeat the last one; no values give zeros.
    public static func group(_ values: [Float], into groups: Int) -> [Float] {
        guard groups > 0 else { return [] }
        guard !values.isEmpty else { return Array(repeating: 0, count: groups) }
        return (0 ..< groups).map { index in
            let start = index * values.count / groups
            let end = max(start + 1, (index + 1) * values.count / groups)
            let slice = values[min(start, values.count - 1) ..< min(end, values.count)]
            return slice.reduce(0, +) / Float(slice.count)
        }
    }
}

/// The now-playing indicator of a row, white like the dimmed overlay it sits in: a few small bars driven by the live spectrum while playing, a low
/// still shape while paused or with Reduce Motion. Drawn by Core Animation layers, so levels never touch SwiftUI state.
/// The spectrum is subscribed to only while the row is on screen, playing and the app is active.
struct NowPlayingBars: View {
    static let barCount = 4
    /// Paused: a low, still shape.
    static let pausedLevels: [Float] = [0.25, 0.4, 0.3, 0.2]
    /// Playing without live data (no source, Reduce Motion): a still, higher shape.
    static let stillPlayingLevels: [Float] = [0.5, 0.9, 0.65, 0.8]

    let state: TrackRow.NowPlaying
    let source: SpectrumLevelsSource?

    @State private var bars: SpectrumBarsController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    init(state: TrackRow.NowPlaying, source: SpectrumLevelsSource?) {
        self.state = state
        self.source = source
        _bars = State(initialValue: SpectrumBarsController(levels: Self.restLevels(for: state)))
    }

    private static func restLevels(for state: TrackRow.NowPlaying) -> [Float] {
        state == .playing ? stillPlayingLevels : pausedLevels
    }

    private var isLive: Bool {
        state == .playing && source != nil && !reduceMotion && scenePhase == .active
    }

    var body: some View {
        SpectrumBarsView(controller: bars, colors: [.white, .white], barWidthRatio: 0.6)
            .frame(width: 22, height: 20)
            .task(id: Mode(state: state, isLive: isLive)) {
                guard isLive, let source else {
                    bars.show(Self.restLevels(for: state))
                    return
                }
                for await values in source() {
                    bars.show(BandGrouping.group(values, into: Self.barCount))
                }
            }
    }

    private struct Mode: Hashable {
        let state: TrackRow.NowPlaying
        let isLive: Bool
    }
}
