import Foundation

@MainActor
public struct StartPlaybackUseCase {
    private let playback: any PlaybackControlling

    public init(playback: any PlaybackControlling) {
        self.playback = playback
    }

    /// Starts `tracks` from `index`. Does nothing for an empty list or an out-of-range index.
    public func callAsFunction(_ tracks: [Track], startingAt index: Int = 0, shuffled: Bool = false) {
        guard tracks.indices.contains(index) else { return }
        playback.play(tracks, startingAt: index, shuffled: shuffled)
    }

    /// "Shuffle" button over a list: starts from a random track.
    public func shuffleAll(_ tracks: [Track]) {
        guard !tracks.isEmpty else { return }
        playback.play(tracks, startingAt: Int.random(in: tracks.indices), shuffled: true)
    }
}
