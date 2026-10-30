#if DEBUG
    import Domain
    import SwiftUI

    /// Fixed data for `#Preview`s; writes are ignored.
    @MainActor
    private struct PreviewDependencies: FoldersDependencies {
        let rock = Folder(name: "Rock")
        var folderRepository: any FolderRepository {
            PreviewFolders(folders: [rock, Folder(name: "Jazz", sortIndex: 1), Folder(name: "Live", parentID: rock.id)])
        }

        var trackRepository: any TrackRepository {
            PreviewTracks(tracks: ["Midnight City", "Teardrop", "Nude"].enumerated().map { index, title in
                Track(
                    title: title, artist: "Artist", album: "Album", duration: Double(200 + index * 20),
                    relativePath: "Media/\(index).mp3", originalFileName: "\(title).mp3", fileSize: 1, contentHash: title,
                    folderID: index == 0 ? nil : rock.id
                )
            })
        }

        var fileStore: any FileStoring {
            PreviewFiles()
        }

        var artworkStore: any ArtworkStoring {
            PreviewArtwork()
        }

        var player: any PlaybackControlling {
            PreviewPlayer()
        }
    }

    #Preview("Folders") {
        FoldersFeature.makeRootView(dependencies: PreviewDependencies())
    }

    private func once<T: Sendable>(_ value: T) -> AsyncStream<T> {
        AsyncStream { $0.yield(value) }
    }

    private struct PreviewFolders: FolderRepository {
        let folders: [Folder]
        func observeFolders() -> AsyncStream<[Folder]> {
            once(folders)
        }

        func folders() async throws -> [Folder] {
            folders
        }

        func create(_: Folder) async throws {}
        func update(_: Folder) async throws {}
        func delete(id _: Folder.ID) async throws {}
    }

    private struct PreviewTracks: TrackRepository {
        let tracks: [Track]
        func observeTracks(sortedBy _: TrackSort) -> AsyncStream<[Track]> {
            once(tracks)
        }

        func tracks(ids: [Track.ID]) async throws -> [Track] {
            tracks.filter { ids.contains($0.id) }
        }

        func tracks(inFolder folderID: Folder.ID?, includeSubfolders _: Bool) async throws -> [Track] {
            tracks.filter { $0.folderID == folderID }
        }

        func search(_: String, sortedBy _: TrackSort) async throws -> [Track] {
            []
        }

        func track(withContentHash _: String) async throws -> Track? {
            nil
        }

        func add(_: [Track]) async throws {}
        func update(_: Track) async throws {}
        func move(trackIDs _: [Track.ID], toFolder _: Folder.ID?) async throws {}
        func delete(ids _: [Track.ID]) async throws {}
        func markPlayed(id _: Track.ID, at _: Date) async throws {}
    }

    private struct PreviewFiles: FileStoring {
        func contentHash(of _: URL) async throws -> String {
            ""
        }

        func importFile(from url: URL) async throws -> StoredFile {
            StoredFile(relativePath: url.lastPathComponent, originalFileName: url.lastPathComponent, fileSize: 0, contentHash: "")
        }

        func url(forRelativePath path: String) -> URL {
            URL(fileURLWithPath: path)
        }

        func deleteFile(relativePath _: String) async throws {}
        func librarySize() async -> Int64 {
            0
        }

        func pendingInboxFiles() async -> [URL] {
            []
        }

        func removeFromInbox(_: URL) async throws {}
    }

    private struct PreviewArtwork: ArtworkStoring {
        func store(_: Data) async throws -> String {
            ""
        }

        func url(for _: String, size _: ArtworkSize) async -> URL? {
            nil
        }

        func clearCache() async throws {}
    }

    @MainActor
    private final class PreviewPlayer: PlaybackControlling {
        var snapshot = PlaybackSnapshot()
        var currentTime: TimeInterval = 0
        func snapshots() -> AsyncStream<PlaybackSnapshot> {
            once(snapshot)
        }

        func play(_: [Track], startingAt _: Int, shuffled _: Bool) {}
        func togglePlayPause() {}
        func next() {}
        func previous() {}
        func seek(to _: TimeInterval) {}
        func toggleShuffle() {}
        func cycleRepeatMode() {}
        func playNext(_: [Track]) {}
        func addToQueue(_: [Track]) {}
        func moveQueueItems(fromOffsets _: IndexSet, toOffset _: Int) {}
        func removeQueueItems(atOffsets _: IndexSet) {}
        func jump(toQueueIndex _: Int) {}
        func setRate(_: Float) {}
        func apply(_: EQSettings) {}
        func restore() async {}
        func persist() async {}
    }
#endif
