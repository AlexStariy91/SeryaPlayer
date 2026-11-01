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
    /// Progress of an import started elsewhere (inbox, "Open in…"), from `ImportProgressCenter`.
    private(set) var externalProgress: ImportProgress?
    /// What the banner shows: this view model's own import, else one running elsewhere.
    var activeProgress: ImportProgress? {
        progress ?? externalProgress
    }

    var isImporting: Bool {
        activeProgress != nil
    }

    @ObservationIgnored private let importTracks: ImportTracksUseCase
    @ObservationIgnored private let activity: ImportProgressCenter?

    init(importTracks: ImportTracksUseCase, activity: ImportProgressCenter? = nil) {
        self.importTracks = importTracks
        self.activity = activity
    }

    /// Follows imports started outside the Library until the calling task is cancelled.
    func observeActivity() async {
        guard let activity else { return }
        for await update in activity.updates() where update != externalProgress {
            externalProgress = update
        }
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
