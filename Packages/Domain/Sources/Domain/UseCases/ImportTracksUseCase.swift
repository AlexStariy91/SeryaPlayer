import Foundation

public struct ImportTracksUseCase: Sendable {
    private let files: any FileStoring
    private let metadata: any MetadataReading
    private let artwork: any ArtworkStoring
    private let tracks: any TrackRepository
    private let folders: any FolderRepository
    private let progressCenter: ImportProgressCenter?
    private let batchSize: Int

    /// `progressCenter` publishes progress of every import (picker, inbox, Open in…) to the UI.
    /// New tracks are written in chunks of `batchSize`, so observers refresh once per chunk, not per file.
    public init(
        files: any FileStoring,
        metadata: any MetadataReading,
        artwork: any ArtworkStoring,
        tracks: any TrackRepository,
        folders: any FolderRepository,
        progressCenter: ImportProgressCenter? = nil,
        batchSize: Int = 20
    ) {
        self.files = files
        self.metadata = metadata
        self.artwork = artwork
        self.tracks = tracks
        self.folders = folders
        self.progressCenter = progressCenter
        self.batchSize = max(1, batchSize)
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
        let report: @Sendable (ImportProgress) -> Void = { update in
            progress?(update)
            progressCenter?.report(update)
        }
        report(ImportProgress(completed: 0, total: total))
        var batch = Batch()
        for (offset, candidate) in candidates.enumerated() {
            await importOne(candidate, batch: &batch, into: &result)
            if batch.tracks.count >= batchSize {
                await flush(&batch, into: &result)
            }
            report(ImportProgress(completed: offset + 1, total: total))
        }
        await flush(&batch, into: &result)
        progressCenter?.finish()
        return result
    }

    /// Tracks stored on disk but not yet written to the repository.
    private struct Batch {
        var tracks: [Track] = []
        var hashes: Set<String> = []
    }

    /// Writes the batch in one call; if that fails, retries track by track so one bad row fails only itself.
    private func flush(_ batch: inout Batch, into result: inout ImportResult) async {
        guard !batch.tracks.isEmpty else { return }
        let pending = batch.tracks
        batch.tracks = []
        do {
            try await tracks.add(pending)
            result.added.append(contentsOf: pending)
        } catch {
            for track in pending {
                do {
                    try await tracks.add([track])
                    result.added.append(track)
                } catch {
                    try? await files.deleteFile(relativePath: track.relativePath)
                    result.failed.append(track.originalFileName)
                }
            }
        }
    }

    private func importOne(_ candidate: Candidate, batch: inout Batch, into result: inout ImportResult) async {
        let url = candidate.url
        let name = url.lastPathComponent
        do {
            let hash = try await files.contentHash(of: url)
            let isStored = try await tracks.track(withContentHash: hash) != nil
            if isStored || batch.hashes.contains(hash) {
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
            batch.tracks.append(track)
            batch.hashes.insert(stored.contentHash)
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
