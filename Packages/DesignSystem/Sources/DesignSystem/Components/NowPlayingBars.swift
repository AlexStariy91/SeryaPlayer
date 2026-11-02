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

/// The now-playing indicator of a row, white like the dimmed overlay it sits in: a few small bars driven by the
/// live spectrum while playing. On pause they fall to rest (round dots, like the full player's visualizer) with the
/// spectrum service's own release, and the subscription ends once they have settled. Reduce Motion shows the rest
/// state without animating. Drawn by Core Animation layers, so levels never touch SwiftUI state.
/// The spectrum is subscribed to only while the row is on screen, the app is active and the bars are moving.
struct NowPlayingBars: View {
    static let barCount = 4
    /// Playing without live data (no source, Reduce Motion): a still, higher shape.
    static let stillPlayingLevels: [Float] = [0.5, 0.9, 0.65, 0.8]
    /// Below this the bars are drawn as resting dots anyway.
    static let restThreshold: Float = 0.01
    /// Same time constant as the spectrum service's smoother, so rows fall like the full player's bars.
    static let releaseTime = 0.16

    let state: TrackRow.NowPlaying
    let source: SpectrumLevelsSource?

    @State private var bars: SpectrumBarsController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    init(state: TrackRow.NowPlaying, source: SpectrumLevelsSource?) {
        self.state = state
        self.source = source
        _bars = State(initialValue: SpectrumBarsController(levels: Self.restLevels(for: state, animated: source != nil)))
    }

    /// Resting zeros, or the still shape for a playing row that has no live data to show.
    static func restLevels(for state: TrackRow.NowPlaying, animated: Bool) -> [Float] {
        state == .playing && !animated ? stillPlayingLevels : Array(repeating: 0, count: barCount)
    }

    static func isResting(_ levels: [Float]) -> Bool {
        levels.allSatisfy { $0 < restThreshold }
    }

    private var isAnimated: Bool {
        source != nil && !reduceMotion && scenePhase == .active
    }

    var body: some View {
        SpectrumBarsView(controller: bars, colors: [.white, .white], barWidthRatio: 0.6)
            .frame(width: 22, height: 20)
            .task(id: Mode(state: state, isAnimated: isAnimated)) {
                guard isAnimated, let source else {
                    bars.show(Self.restLevels(for: state, animated: false))
                    return
                }
                if state == .paused {
                    await fallToRest()
                    return
                }
                for await values in source() {
                    bars.show(BandGrouping.group(values, into: Self.barCount))
                }
            }
    }

    /// Eases the bars down to rest with the spectrum service's release time, then stops: nothing runs once
    /// they have settled. Done here, not through a new subscription, because a restarted analysis has no
    /// memory of the last levels and would leave the bars where they stopped.
    private func fallToRest() async {
        let step = Duration.milliseconds(33)
        var levels = bars.levels
        while !Self.isResting(levels) {
            try? await Task.sleep(for: step)
            if Task.isCancelled {
                return
            }
            let keep = Float(exp(-0.033 / Self.releaseTime))
            levels = levels.map { $0 * keep }
            bars.show(levels)
        }
        bars.show(Self.restLevels(for: .paused, animated: true))
    }

    private struct Mode: Hashable {
        let state: TrackRow.NowPlaying
        let isAnimated: Bool
    }
}
