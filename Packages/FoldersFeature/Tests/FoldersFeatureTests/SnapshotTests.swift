import DesignSystem
import Domain
import DomainTestSupport
@testable import FoldersFeature
import SnapshotTesting
import SwiftUI
import Testing
import UIKit

/// Reference images are recorded on iPhone 16 / iOS 18.1 at 2x. Delete a reference to re-record it.
/// Full screens take list margins from the host screen, so the suite runs only on the reference
/// simulator and is skipped elsewhere (`scripts/test.sh` picks the first iOS 18 iPhone it finds;
/// pin it with `SIM_ID=<iPhone 16 udid>`).
@MainActor
@Suite(.enabled(if: SnapshotHost.isReference, "Reference images are recorded on iPhone 16 / iOS 18.1"))
struct SnapshotTests {
    private func check(
        _ name: String,
        fileID: StaticString = #fileID,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        @ViewBuilder content: () -> some View
    ) {
        let view = content()
        for (variant, style) in [("light", UIUserInterfaceStyle.light), ("dark", .dark)] {
            let traits = UITraitCollection(traitsFrom: [
                UITraitCollection(userInterfaceStyle: style),
                UITraitCollection(preferredContentSizeCategory: .large),
                UITraitCollection(displayScale: 2),
            ])
            assertSnapshot(
                of: view.tint(AccentPalette.serya.color),
                as: .image(precision: 0.95, perceptualPrecision: 0.9, layout: .device(config: .iPhone13), traits: traits),
                named: "\(name)-\(variant)",
                fileID: fileID,
                file: file,
                testName: testName,
                line: line
            )
        }
    }

    private let rock = Folder(name: "Rock", sortIndex: 0)

    private func context(tracks: [Track], folders: [Folder]) async -> FoldersContext {
        await TestDependencies(folders: folders, tracks: tracks).loadedContext()
    }

    private var sampleTracks: [Track] {
        [
            .fixture("Loose Song", artist: "Artist"),
            .fixture("Anthem", artist: "The Band", album: "Live", folderID: rock.id),
            .fixture("Encore", artist: "The Band", album: "Live", folderID: rock.id),
        ]
    }

    @Test func root() async {
        let context = await context(tracks: sampleTracks, folders: [rock, Folder(name: "Jazz", sortIndex: 1)])
        check("root") {
            NavigationStack { FolderBrowserView(folderID: nil, context: context) }
        }
    }

    @Test func folder() async {
        let context = await context(tracks: sampleTracks, folders: [rock, Folder(name: "Live", parentID: rock.id)])
        check("folder") {
            NavigationStack { FolderBrowserView(folderID: rock.id, context: context) }
        }
    }

    @Test func emptyRoot() async {
        let context = await context(tracks: [], folders: [])
        check("emptyRoot") {
            NavigationStack { FolderBrowserView(folderID: nil, context: context) }
        }
    }
}

enum SnapshotHost {
    /// iPhone 16 (`iPhone17,3`) on iOS 18.1.
    static var isReference: Bool {
        ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] == "iPhone17,3"
            && ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 18
            && ProcessInfo.processInfo.operatingSystemVersion.minorVersion == 1
    }
}
