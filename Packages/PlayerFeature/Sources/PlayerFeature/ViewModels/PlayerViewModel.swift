import Domain
import Foundation
import Observation
import SwiftUI

/// State and actions shared by the mini player, the full player and the queue sheet.
@MainActor
@Observable
final class PlayerViewModel {
    typealias ColorExtractor = @Sendable (URL) async -> [Color]

    private(set) var snapshot: PlaybackSnapshot
    /// Large artwork for the full player.
    private(set) var artworkURL: URL?
    /// Small artwork for the mini player.
    private(set) var thumbnailURL: URL?
    private(set) var backgroundColors: [Color] = []
    /// The equalizer is on and not flat: the EQ button shows an indicator.
    private(set) var isEqualizerActive = false

    let progress: PlaybackProgress

    @ObservationIgnored private let player: any PlaybackControlling
    @ObservationIgnored private let artworkStore: any ArtworkStoring
    @ObservationIgnored private let settingsRepository: any SettingsRepository
    @ObservationIgnored private let colorExtractor: ColorExtractor
    /// Track whose artwork is resolved (or being resolved), so play/pause doesn't reload it.
    @ObservationIgnored private var artworkTrackID: Track.ID?
    @ObservationIgnored private var artworkKey: String?

    init(
        player: any PlaybackControlling,
        artworkStore: any ArtworkStoring,
        settingsRepository: any SettingsRepository,
        progressInterval: Duration = .milliseconds(200),
        colorExtractor: @escaping ColorExtractor = { await ArtworkPalette.colors(from: $0) }
    ) {
        self.player = player
        self.artworkStore = artworkStore
        self.settingsRepository = settingsRepository
        self.colorExtractor = colorExtractor
        snapshot = player.snapshot
        progress = PlaybackProgress(player: player, interval: progressInterval)
        isEqualizerActive = Self.isActive(settingsRepository.load().equalizer)
    }

    // MARK: - Derived state

    var isQueued: Bool {
        !snapshot.queue.isEmpty
    }

    /// The track shown by the players: the loaded one, or the current queue item before anything is loaded.
    var track: Track? {
        snapshot.nowPlaying ?? nowPlayingItem?.track
    }

    var duration: TimeInterval {
        track?.duration ?? 0
    }

    var nowPlayingItem: QueueItem? {
        guard let index = snapshot.currentIndex, snapshot.queue.indices.contains(index) else { return nil }
        return QueueItem(index: index, track: snapshot.queue[index])
    }

    /// Items after the current one.
    var upNext: [QueueItem] {
        let start = upNextStart
        guard start < snapshot.queue.count else { return [] }
        return (start ..< snapshot.queue.count).map { QueueItem(index: $0, track: snapshot.queue[$0]) }
    }

    private var upNextStart: Int {
        snapshot.currentIndex.map { $0 + 1 } ?? 0
    }

    static func isActive(_ equalizer: EQSettings) -> Bool {
        equalizer.isEnabled && equalizer.gains.contains { abs($0) >= 0.05 }
    }

    // MARK: - Observation

    /// Follows the player and the settings until the calling task is cancelled.
    func observe() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.observePlayback() }
            group.addTask { await self.observeEqualizer() }
        }
    }

    func observePlayback() async {
        for await snapshot in player.snapshots() {
            apply(snapshot)
            await refreshArtwork()
        }
    }

    func observeEqualizer() async {
        for await settings in settingsRepository.observe() {
            let active = Self.isActive(settings.equalizer)
            if active != isEqualizerActive {
                isEqualizerActive = active
            }
        }
    }

    private func apply(_ snapshot: PlaybackSnapshot) {
        if snapshot != self.snapshot {
            self.snapshot = snapshot
        }
    }

    private func refreshArtwork() async {
        let current = track
        guard current?.id != artworkTrackID || current?.artworkKey != artworkKey else { return }
        artworkTrackID = current?.id
        artworkKey = current?.artworkKey
        guard let current, let key = current.artworkKey else {
            artworkURL = nil
            thumbnailURL = nil
            backgroundColors = []
            return
        }
        let large = await artworkStore.url(for: key, size: .large)
        let thumbnail = await artworkStore.url(for: key, size: .thumbnail)
        guard artworkTrackID == current.id else { return }
        artworkURL = large
        thumbnailURL = thumbnail ?? large
        var colors: [Color] = []
        if let large {
            colors = await colorExtractor(large)
        }
        guard artworkTrackID == current.id else { return }
        backgroundColors = colors
    }

    /// Small artwork for a queue row.
    func thumbnailURL(for track: Track) async -> URL? {
        guard let key = track.artworkKey else { return nil }
        return await artworkStore.url(for: key, size: .thumbnail)
    }

    // MARK: - Actions

    func togglePlayPause() {
        player.togglePlayPause()
    }

    func next() {
        player.next()
    }

    func previous() {
        player.previous()
    }

    func toggleShuffle() {
        player.toggleShuffle()
    }

    func cycleRepeatMode() {
        player.cycleRepeatMode()
    }

    func play(_ item: QueueItem) {
        player.jump(toQueueIndex: item.index)
    }

    /// Offsets are relative to `upNext`.
    func moveUpNext(fromOffsets source: IndexSet, toOffset destination: Int) {
        let start = upNextStart
        player.moveQueueItems(fromOffsets: IndexSet(source.map { $0 + start }), toOffset: destination + start)
    }

    /// Offsets are relative to `upNext`.
    func removeUpNext(atOffsets offsets: IndexSet) {
        let start = upNextStart
        player.removeQueueItems(atOffsets: IndexSet(offsets.map { $0 + start }))
    }
}
