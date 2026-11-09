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
    private(set) var progress: ImportProgress? {
        didSet { refreshIsImporting() }
    }

    private(set) var summary: ImportSummary?
    var isShowingSummary = false
    /// Progress of an import started elsewhere (inbox, "Open in…"), from `ImportProgressCenter`.
    private(set) var externalProgress: ImportProgress? {
        didSet { refreshIsImporting() }
    }

    /// What the banner shows: this view model's own import, else one running elsewhere.
    var activeProgress: ImportProgress? {
        progress ?? externalProgress
    }

    /// Stored, not derived from `activeProgress`: views that only care whether an import runs (the toolbar item's
    /// presence, the disabled "+") must not be invalidated by every progress tick.
    private(set) var isImporting = false

    /// True while the progress popover is on screen (including its dismissal). The toolbar item that anchors the
    /// popover must outlive it: removing a popover's source button mid-presentation crashes UIKit on iOS 26.
    private(set) var isDetailsOpen = false
    /// A finished import's summary waits for the popover to go: an alert presented over it is dropped.
    @ObservationIgnored private var isSummaryPending = false

    /// Whether the toolbar item should exist: while importing, and until the popover is fully gone.
    var showsIndicator: Bool {
        isImporting || isDetailsOpen
    }

    func detailsDidAppear() {
        isDetailsOpen = true
    }

    func detailsDidDisappear() {
        guard isDetailsOpen else { return }
        isDetailsOpen = false
        if isSummaryPending {
            isSummaryPending = false
            isShowingSummary = true
        }
    }

    private func refreshIsImporting() {
        let importing = activeProgress != nil
        if importing != isImporting {
            isImporting = importing
        }
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
        if isDetailsOpen {
            isSummaryPending = true
        } else {
            isShowingSummary = true
        }
    }
}
