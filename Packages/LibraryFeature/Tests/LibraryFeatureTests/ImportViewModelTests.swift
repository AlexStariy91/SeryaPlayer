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
