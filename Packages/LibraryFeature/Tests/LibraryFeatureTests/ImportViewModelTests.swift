import Domain
import DomainTestSupport
import Foundation
@testable import LibraryFeature
import Testing

@MainActor
struct ImportViewModelTests {
    @Test func summaryCountsAddedDuplicatesAndUnsupported() async {
        let deps = TestDependencies(tracks: [.make("dup")])
        deps.files.setHash("dup", forFileNamed: "dup.mp3")
        deps.metadata.markUnsupported(["notes.txt"])
        let importer = deps.makeContext().importer
        let urls = ["a.mp3", "b.m4a", "dup.mp3", "notes.txt"].map { URL(fileURLWithPath: "/import/\($0)") }

        await importer.importURLs(urls)

        let summary = importer.summary
        #expect(summary?.added == 2)
        #expect(summary?.duplicates == 1)
        #expect(summary?.unsupported == 1)
        #expect(summary?.message == "Added 2 · Duplicates 1 · Unsupported 1")
        #expect(importer.isShowingSummary)
        #expect(!importer.isImporting)
        #expect(deps.tracks.snapshot.count == 3)
    }

    @Test func summaryAppearsAtOnceWhenTheImportEnds() async {
        let importer = TestDependencies().makeContext().importer
        await importer.importURLs([URL(fileURLWithPath: "/import/a.mp3")])
        #expect(!importer.isImporting)
        #expect(importer.isShowingSummary)
    }

    @Test func failuresAreAppendedToTheSummary() {
        let summary = ImportSummary(ImportResult(added: [], duplicates: [], unsupported: [], failed: ["x"]))
        #expect(summary.message == "Added 0 · Duplicates 0 · Unsupported 0 · Failed 1")
    }

    @Test func pickerSourceSelectsContentTypes() {
        let importer = TestDependencies().makeContext().importer
        importer.present(.folder)
        #expect(importer.isPickerPresented)
        #expect(importer.source.contentTypes == [.folder])
        #expect(!importer.source.allowsMultipleSelection)
        importer.present(.files)
        #expect(importer.source.contentTypes.contains(.audio))
        #expect(importer.source.allowsMultipleSelection)
    }
}

@MainActor
struct ImportActivityTests {
    @Test func externalProgressIsShownAndCleared() async {
        let center = ImportProgressCenter()
        let deps = TestDependencies()
        let importer = ImportViewModel(importTracks: deps.importTracks, activity: center)
        let observing = Task { await importer.observeActivity() }
        defer { observing.cancel() }

        center.report(ImportProgress(completed: 3, total: 10))
        await waitUntil { importer.activeProgress == ImportProgress(completed: 3, total: 10) }
        #expect(importer.isImporting)

        center.finish()
        await waitUntil { importer.activeProgress == nil }
        #expect(!importer.isImporting)
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0 ..< 200 where !condition() {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}
