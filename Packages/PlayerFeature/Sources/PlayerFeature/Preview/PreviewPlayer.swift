#if DEBUG
    import Domain
    import Foundation
    import SwiftUI

    /// Inline fakes for `#Preview`s: a player that reacts to its buttons, with no audio.
    @MainActor
    final class PreviewPlayer: PlaybackControlling {
        private(set) var snapshot: PlaybackSnapshot {
            didSet { continuations.values.forEach { $0.yield(snapshot) } }
        }

        var currentTime: TimeInterval = 83
        private var continuations: [UUID: AsyncStream<PlaybackSnapshot>.Continuation] = [:]

        init(snapshot: PlaybackSnapshot) {
            self.snapshot = snapshot
        }

        static let tracks: [Track] = [
            ("Midnight City", "M83"), ("Intro", "The xx"), ("Teardrop", "Massive Attack"),
            ("Svefn-g-englar", "Sigur Rós"), ("Windowlicker", "Aphex Twin"),
        ].map { title, artist in
            Track(
                title: title,
                artist: artist,
                album: "Album",
                duration: 245,
                relativePath: "Media/\(title).mp3",
                originalFileName: "\(title).mp3",
                fileSize: 1000,
                contentHash: title
            )
        }

        static func playing() -> (player: PreviewPlayer, viewModel: PlayerViewModel) {
            let player = PreviewPlayer(snapshot: PlaybackSnapshot(
                nowPlaying: tracks[0],
                isPlaying: true,
                queue: tracks,
                currentIndex: 0
            ))
            var settings = AppSettings()
            settings.equalizer = EQSettings(isEnabled: true, gains: [3, 2, 1, 0, 0, 0, 1, 2, 3, 3])
            let viewModel = PlayerViewModel(
                player: player,
                artworkStore: PreviewArtworkStore(),
                settingsRepository: PreviewSettingsRepository(settings: settings),
                colorExtractor: { _ in [] }
            )
            return (player, viewModel)
        }

        func snapshots() -> AsyncStream<PlaybackSnapshot> {
            let (stream, continuation) = AsyncStream.makeStream(of: PlaybackSnapshot.self)
            continuations[UUID()] = continuation
            continuation.yield(snapshot)
            return stream
        }

        func play(_ tracks: [Track], startingAt index: Int, shuffled _: Bool) {
            snapshot.queue = tracks
            jump(toQueueIndex: index)
        }

        func togglePlayPause() {
            snapshot.isPlaying.toggle()
        }

        func next() {
            jump(toQueueIndex: ((snapshot.currentIndex ?? 0) + 1) % max(snapshot.queue.count, 1))
        }

        func previous() {
            jump(toQueueIndex: max((snapshot.currentIndex ?? 0) - 1, 0))
        }

        func seek(to time: TimeInterval) {
            currentTime = time
        }

        func toggleShuffle() {
            snapshot.isShuffled.toggle()
        }

        func cycleRepeatMode() {
            snapshot.repeatMode = switch snapshot.repeatMode {
            case .off: .all
            case .all: .one
            case .one: .off
            }
        }

        func playNext(_: [Track]) {}
        func addToQueue(_: [Track]) {}

        func moveQueueItems(fromOffsets source: IndexSet, toOffset destination: Int) {
            let current = snapshot.currentIndex.map { snapshot.queue[$0] }
            snapshot.queue.move(fromOffsets: source, toOffset: destination)
            snapshot.currentIndex = current.flatMap { snapshot.queue.firstIndex(of: $0) }
        }

        func removeQueueItems(atOffsets offsets: IndexSet) {
            snapshot.queue.remove(atOffsets: offsets)
        }

        func jump(toQueueIndex index: Int) {
            guard snapshot.queue.indices.contains(index) else { return }
            snapshot.currentIndex = index
            snapshot.nowPlaying = snapshot.queue[index]
            currentTime = 0
        }

        func setRate(_: Float) {}
        func apply(_: EQSettings) {}
        func restore() async {}
        func persist() async {}
    }

    struct PreviewArtworkStore: ArtworkStoring {
        func store(_: Data) async throws -> String {
            "preview"
        }

        func url(for _: String, size _: Domain.ArtworkSize) async -> URL? {
            nil
        }

        func clearCache() async throws {}
    }

    struct PreviewSettingsRepository: SettingsRepository {
        let settings: AppSettings

        func load() -> AppSettings {
            settings
        }

        func save(_: AppSettings) {}

        func observe() -> AsyncStream<AppSettings> {
            AsyncStream { $0.yield(settings) }
        }
    }
#endif
