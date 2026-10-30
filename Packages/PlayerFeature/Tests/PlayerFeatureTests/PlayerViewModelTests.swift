import Domain
import DomainTestSupport
import Foundation
@testable import PlayerFeature
import SwiftUI
import Testing

@MainActor
struct PlayerViewModelTests {
    let tracks = makeQueue(4)

    func makeViewModel(
        player: RecordingPlayer,
        artwork: StubArtworkStore = StubArtworkStore(),
        settings: InMemorySettingsRepository = InMemorySettingsRepository(),
        colors: [Color] = [.red, .blue]
    ) -> PlayerViewModel {
        PlayerViewModel(player: player, artworkStore: artwork, settingsRepository: settings, colorExtractor: { _ in colors })
    }

    func playing(at index: Int, isPlaying: Bool = true) -> PlaybackSnapshot {
        PlaybackSnapshot(nowPlaying: tracks[index], isPlaying: isPlaying, queue: tracks, currentIndex: index)
    }

    // MARK: - Snapshots and artwork

    @Test func startsHiddenWithAnEmptyQueue() {
        let viewModel = makeViewModel(player: RecordingPlayer())
        #expect(!viewModel.isQueued)
        #expect(viewModel.track == nil)
        #expect(viewModel.upNext.isEmpty)
    }

    @Test func followsSnapshotsAndResolvesArtwork() async {
        let player = RecordingPlayer()
        player.snapshotsToSend = [playing(at: 1)]
        let viewModel = makeViewModel(player: player)

        await viewModel.observePlayback()

        #expect(viewModel.isQueued)
        #expect(viewModel.track?.id == tracks[1].id)
        #expect(viewModel.duration == tracks[1].duration)
        #expect(viewModel.artworkURL == URL(fileURLWithPath: "/art/art1-large"))
        #expect(viewModel.thumbnailURL == URL(fileURLWithPath: "/art/art1-thumb"))
        #expect(viewModel.backgroundColors == [.red, .blue])
    }

    @Test func playPauseDoesNotReloadArtwork() async {
        let player = RecordingPlayer()
        let artwork = StubArtworkStore()
        player.snapshotsToSend = [playing(at: 0), playing(at: 0, isPlaying: false), playing(at: 0)]
        let viewModel = makeViewModel(player: player, artwork: artwork)

        await viewModel.observePlayback()

        #expect(artwork.lookupCount == 2) // large + thumbnail, once
        #expect(viewModel.snapshot.isPlaying)
    }

    @Test func trackWithoutArtworkClearsTheBackground() async {
        var bare = Track.fixture("Bare")
        bare.artworkKey = nil
        let player = RecordingPlayer()
        player.snapshotsToSend = [playing(at: 0), PlaybackSnapshot(nowPlaying: bare, queue: [bare], currentIndex: 0)]
        let viewModel = makeViewModel(player: player)

        await viewModel.observePlayback()

        #expect(viewModel.track?.id == bare.id)
        #expect(viewModel.artworkURL == nil)
        #expect(viewModel.thumbnailURL == nil)
        #expect(viewModel.backgroundColors.isEmpty)
    }

    @Test func restoredQueueShowsTheCurrentItemBeforeItIsLoaded() {
        let player = RecordingPlayer(snapshot: PlaybackSnapshot(queue: tracks, currentIndex: 2))
        let viewModel = makeViewModel(player: player)
        #expect(viewModel.isQueued)
        #expect(viewModel.track?.id == tracks[2].id)
    }

    // MARK: - Queue

    @Test func splitsTheQueueIntoNowPlayingAndUpNext() {
        let viewModel = makeViewModel(player: RecordingPlayer(snapshot: playing(at: 1)))
        #expect(viewModel.nowPlayingItem == QueueItem(index: 1, track: tracks[1]))
        #expect(viewModel.upNext.map(\.index) == [2, 3])
        #expect(viewModel.upNext.map(\.track.id) == [tracks[2].id, tracks[3].id])
    }

    @Test func duplicateTracksGetDistinctQueueIDs() {
        let track = tracks[0]
        let player = RecordingPlayer(snapshot: PlaybackSnapshot(nowPlaying: track, queue: [track, track, track], currentIndex: 0))
        let viewModel = makeViewModel(player: player)
        #expect(Set(viewModel.upNext.map(\.id)).count == 2)
    }

    @Test func upNextEditsAreTranslatedToQueueOffsets() {
        let player = RecordingPlayer(snapshot: playing(at: 1))
        let viewModel = makeViewModel(player: player)

        viewModel.moveUpNext(fromOffsets: [1], toOffset: 0)
        viewModel.removeUpNext(atOffsets: [0])
        viewModel.play(viewModel.upNext[1])

        #expect(player.calls == [.move([3], 2), .remove([2]), .jump(3)])
    }

    // MARK: - Actions

    @Test func controlsForwardToThePlayer() {
        let player = RecordingPlayer(snapshot: playing(at: 0))
        let viewModel = makeViewModel(player: player)

        viewModel.togglePlayPause()
        viewModel.next()
        viewModel.previous()
        viewModel.toggleShuffle()
        viewModel.cycleRepeatMode()

        #expect(player.calls == [.togglePlayPause, .next, .previous, .toggleShuffle, .cycleRepeatMode])
    }

    // MARK: - Equalizer indicator

    @Test(arguments: [
        (EQSettings(isEnabled: true, gains: [0, 0, 3, 0, 0, 0, 0, 0, 0, 0]), true),
        (EQSettings(isEnabled: true), false),
        (EQSettings(isEnabled: false, gains: Array(repeating: 6, count: EQBands.count)), false),
    ])
    func equalizerIsActiveOnlyWhenEnabledAndNotFlat(settings: EQSettings, expected: Bool) {
        #expect(PlayerViewModel.isActive(settings) == expected)
    }

    @Test func equalizerIndicatorFollowsSettings() async {
        let settings = InMemorySettingsRepository()
        let viewModel = makeViewModel(player: RecordingPlayer(), settings: settings)
        #expect(!viewModel.isEqualizerActive)

        let task = Task { await viewModel.observeEqualizer() }
        defer { task.cancel() }
        var updated = settings.load()
        updated.equalizer = EQSettings(isEnabled: true, gains: [4, 2, 0, 0, 0, 0, 0, 0, 2, 4])
        settings.save(updated)

        #expect(await waitUntil { viewModel.isEqualizerActive })
    }
}
