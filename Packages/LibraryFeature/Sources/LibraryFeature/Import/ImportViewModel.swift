import Domain
import Foundation
import Observation
import UniformTypeIdentifiers

/// Drives "+" → Files… / Folder…: the file importer, progress and the summary alert.
@MainActor
@Observable
final class ImportViewModel {
    enum Source {
        case files
        case folder

        var contentTypes: [UTType] {
            switch self {
            case .files: [.audio, .mp3, .mpeg4Audio, .wav, .aiff] + [UTType("org.xiph.flac")].compactMap(\.self)
            case .folder: [.folder]
            }
        }

        var allowsMultipleSelection: Bool {
            self == .files
        }
    }

    var isPickerPresented = false
    private(set) var source: Source = .files
    private(set) var progress: ImportProgress?
    private(set) var summary: ImportSummary?
    var isShowingSummary = false
    var isImporting: Bool {
        progress != nil
    }

    @ObservationIgnored private let importTracks: ImportTracksUseCase

    init(importTracks: ImportTracksUseCase) {
        self.importTracks = importTracks
    }

    func present(_ source: Source) {
        self.source = source
        isPickerPresented = true
    }

    func handlePickerResult(_ result: Result<[URL], any Error>) {
        guard case let .success(urls) = result, !urls.isEmpty else { return }
        Task { await importURLs(urls) }
    }

    func importURLs(_ urls: [URL]) async {
        guard !isImporting else { return }
        progress = ImportProgress(completed: 0, total: 0)
        let (updates, continuation) = AsyncStream.makeStream(of: ImportProgress.self, bufferingPolicy: .bufferingNewest(1))
        let listener = Task {
            for await update in updates {
                progress = update
            }
        }
        let result = await importTracks(urls: urls) { continuation.yield($0) }
        continuation.finish()
        await listener.value
        progress = nil
        summary = ImportSummary(result)
        isShowingSummary = true
    }
}
