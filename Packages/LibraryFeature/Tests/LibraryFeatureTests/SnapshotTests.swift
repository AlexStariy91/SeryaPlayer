import DesignSystem
import Domain
import DomainTestSupport
@testable import LibraryFeature
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
    private static let tracks: [Track] = [
        ("Midnight City", "M83", "Hurry Up, We're Dreaming"),
        ("Wait", "M83", "Hurry Up, We're Dreaming"),
        ("Teardrop", "Massive Attack", "Mezzanine"),
        ("Angel", "Massive Attack", "Mezzanine"),
        ("Svefn-g-englar", "Sigur Rós", "Ágætis byrjun"),
        ("Nude", "Radiohead", "In Rainbows"),
        ("Windowlicker", "Aphex Twin", "Windowlicker"),
    ].enumerated().map { index, item in
        Track.make(
            item.0,
            artist: item.1,
            album: item.2,
            duration: Double(180 + index * 37),
            added: Double(index),
            lastPlayed: index.isMultiple(of: 3) ? Double(index) : nil
        )
    }

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

    private func loadedContext(tracks: [Track] = SnapshotTests.tracks) async throws -> (TestDependencies, LibraryContext) {
        let deps = TestDependencies(tracks: tracks)
        if !tracks.isEmpty {
            let playlist = Playlist(name: "Late Night")
            try await deps.playlists.create(playlist)
            try await deps.playlists.append(trackIDs: tracks.prefix(4).map(\.id), to: playlist.id)
        }
        let context = deps.makeContext()
        await context.store.load()
        return (deps, context)
    }

    @Test func home() async throws {
        let (_, context) = try await loadedContext()
        check("home") {
            NavigationStack {
                LibraryHomeView(context: context).navigationTitle("Library")
            }
        }
    }

    @Test func emptyLibrary() async throws {
        let (_, context) = try await loadedContext(tracks: [])
        check("empty") {
            NavigationStack {
                LibraryHomeView(context: context).navigationTitle("Library")
            }
        }
    }

    @Test func allTracks() async throws {
        let (deps, context) = try await loadedContext()
        let viewModel = AllTracksViewModel(tracks: deps.tracks, settings: deps.settings)
        await viewModel.load()
        check("allTracks") {
            NavigationStack {
                AllTracksView(context: context, viewModel: viewModel)
            }
        }
    }

    @Test func playlist() async throws {
        let (deps, context) = try await loadedContext()
        let playlist = try #require(context.store.playlists.first)
        let viewModel = PlaylistDetailViewModel(playlistID: playlist.id, playlists: deps.playlists, store: context.store)
        await viewModel.load()
        check("playlist") {
            NavigationStack {
                PlaylistDetailView(context: context, playlistID: playlist.id, viewModel: viewModel)
            }
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
