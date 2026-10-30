import Foundation

public struct ImportTracksUseCase: Sendable {
    private let files: any FileStoring
    private let metadata: any MetadataReading
    private let artwork: any ArtworkStoring
    private let tracks: any TrackRepository
    private let folders: any FolderRepository

    public init(
        files: any FileStoring,
        metadata: any MetadataReading,
        artwork: any ArtworkStoring,
        tracks: any TrackRepository,
        folders: any FolderRepository
    ) {
        self.files = files
        self.metadata = metadata
        self.artwork = artwork
        self.tracks = tracks
        self.folders = folders
    }

    private struct Candidate {
        var url: URL
        var folderID: Folder.ID?
    }

    /// Imports files and folders. A folder repeats its structure through `Folder` (`parentID`).
    /// Duplicates (by `contentHash`) are detected before copying. Never throws: problems are reported in the result.
    public func callAsFunction(
        urls: [URL],
        intoFolder folderID: Folder.ID? = nil,
        progress: (@Sendable (ImportProgress) -> Void)? = nil
    ) async -> ImportResult {
        var result = ImportResult()
        let scoped = urls.filter { $0.startAccessingSecurityScopedResource() }
        defer { scoped.forEach { $0.stopAccessingSecurityScopedResource() } }

        var candidates: [Candidate] = []
        var existingFolders = await (try? folders.folders()) ?? []
        for url in urls {
            if Self.isDirectory(url) {
                await collect(directory: url, parent: folderID, into: &candidates, existing: &existingFolders, result: &result)
            } else {
                candidates.append(Candidate(url: url, folderID: folderID))
            }
        }

        let total = candidates.count
        progress?(ImportProgress(completed: 0, total: total))
        for (offset, candidate) in candidates.enumerated() {
            await importOne(candidate, into: &result)
            progress?(ImportProgress(completed: offset + 1, total: total))
        }
        return result
    }

    private func importOne(_ candidate: Candidate, into result: inout ImportResult) async {
        let url = candidate.url
        let name = url.lastPathComponent
        do {
            let hash = try await files.contentHash(of: url)
            if try await tracks.track(withContentHash: hash) != nil {
                result.duplicates.append(name)
                return
            }
            let info: TrackMetadata
            do {
                info = try await metadata.read(from: url)
            } catch MetadataError.unsupportedFormat {
                result.unsupported.append(name)
                return
            }
            let stored = try await files.importFile(from: url)
            var artworkKey: String?
            if let data = info.artworkData {
                artworkKey = try? await artwork.store(data)
            }
            let track = Track(
                title: Self.title(from: info, fileName: name),
                artist: info.artist ?? "",
                album: info.album ?? "",
                albumArtist: info.albumArtist,
                trackNumber: info.trackNumber,
                duration: info.duration,
                relativePath: stored.relativePath,
                originalFileName: stored.originalFileName,
                fileSize: stored.fileSize,
                contentHash: stored.contentHash,
                artworkKey: artworkKey,
                folderID: candidate.folderID
            )
            do {
                try await tracks.add([track])
            } catch {
                try? await files.deleteFile(relativePath: stored.relativePath)
                throw error
            }
            result.added.append(track)
        } catch {
            result.failed.append(name)
        }
    }

    private func collect(
        directory: URL,
        parent: Folder.ID?,
        into candidates: inout [Candidate],
        existing: inout [Folder],
        result: inout ImportResult
    ) async {
        let name = directory.lastPathComponent
        let folder: Folder
        if let reused = existing.first(where: { $0.parentID == parent && $0.name == name }) {
            folder = reused
        } else {
            let siblings = existing.filter { $0.parentID == parent }.count
            folder = Folder(name: name, parentID: parent, sortIndex: siblings)
            do {
                try await folders.create(folder)
            } catch {
                result.failed.append(name)
                return
            }
            existing.append(folder)
        }

        let children: [URL]
        do {
            children = try FileManager.default
                .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        } catch {
            result.failed.append(name)
            return
        }
        for child in children {
            if Self.isDirectory(child) {
                await collect(directory: child, parent: folder.id, into: &candidates, existing: &existing, result: &result)
            } else {
                candidates.append(Candidate(url: child, folderID: folder.id))
            }
        }
    }

    private static func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private static func title(from info: TrackMetadata, fileName: String) -> String {
        if let title = info.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }
        return (fileName as NSString).deletingPathExtension
    }
}
