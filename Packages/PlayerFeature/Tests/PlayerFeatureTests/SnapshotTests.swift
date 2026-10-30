import DesignSystem
import Domain
import DomainTestSupport
@testable import PlayerFeature
import SnapshotTesting
import SwiftUI
import Testing
import UIKit

/// Reference images are recorded on iPhone 16 / iOS 18.1 at 2x. Delete a reference to re-record it.
@MainActor
struct SnapshotTests {
    private static let styles: [(name: String, style: UIUserInterfaceStyle)] = [("light", .light), ("dark", .dark)]

    private func makeViewModel() async -> PlayerViewModel {
        var tracks = makeQueue(4)
        tracks[1].title = "Midnight City"
        tracks[1].artist = "M83"
        let player = RecordingPlayer(snapshot: PlaybackSnapshot(nowPlaying: tracks[1], isPlaying: true, queue: tracks, currentIndex: 1))
        let viewModel = PlayerViewModel(
            player: player,
            artworkStore: StubArtworkStore(),
            settingsRepository: InMemorySettingsRepository(),
            colorExtractor: { _ in [.indigo, .pink, .orange, .teal] }
        )
        await viewModel.observePlayback()
        player.currentTime = 83
        viewModel.progress.tick()
        return viewModel
    }

    private func check(
        _ name: String,
        size: CGSize,
        compact: Bool = false,
        fileID: StaticString = #fileID,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        content: () -> some View
    ) {
        let view = content()
        for variant in Self.styles {
            var traits: [UITraitCollection] = [
                UITraitCollection(userInterfaceStyle: variant.style),
                UITraitCollection(displayScale: 2),
            ]
            if compact {
                traits.append(UITraitCollection(verticalSizeClass: .compact))
                traits.append(UITraitCollection(horizontalSizeClass: .regular))
            }
            assertSnapshot(
                of: view.tint(AccentPalette.serya.color),
                as: .image(
                    precision: 0.95,
                    perceptualPrecision: 0.9,
                    layout: .fixed(width: size.width, height: size.height),
                    traits: UITraitCollection(traitsFrom: traits)
                ),
                named: "\(name)-\(variant.name)",
                fileID: fileID,
                file: file,
                testName: testName,
                line: line
            )
        }
    }

    @Test func miniPlayer() async {
        let viewModel = await makeViewModel()
        check("mini", size: CGSize(width: 390, height: 92)) {
            MiniPlayerView(viewModel: viewModel) {}
                .frame(height: 60)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
                .padding(Spacing.s)
                .frame(maxHeight: .infinity)
                .background(SemanticColor.background)
        }
    }

    @Test func fullPlayerPortrait() async {
        let viewModel = await makeViewModel()
        check("portrait", size: CGSize(width: 393, height: 852)) {
            FullPlayerView(viewModel: viewModel) { EmptyView() }
        }
    }

    @Test func fullPlayerLandscape() async {
        let viewModel = await makeViewModel()
        check("landscape", size: CGSize(width: 852, height: 393), compact: true) {
            FullPlayerView(viewModel: viewModel) { EmptyView() }
        }
    }

    @Test func fullPlayerPaused() async {
        let viewModel = await makeViewModel()
        let paused = RecordingPlayer(snapshot: PlaybackSnapshot(
            nowPlaying: viewModel.snapshot.nowPlaying,
            isPlaying: false,
            queue: viewModel.snapshot.queue,
            currentIndex: 1,
            isShuffled: true,
            repeatMode: .one
        ))
        let pausedViewModel = PlayerViewModel(
            player: paused,
            artworkStore: StubArtworkStore(),
            settingsRepository: InMemorySettingsRepository(settings: AppSettings(equalizer: EQSettings(
                isEnabled: true,
                gains: [6, 4, 0, 0, 0, 0, 0, 0, 0, 0]
            ))),
            colorExtractor: { _ in [.teal, .blue] }
        )
        await pausedViewModel.observePlayback()
        check("paused", size: CGSize(width: 393, height: 852)) {
            FullPlayerView(viewModel: pausedViewModel) { EmptyView() }
        }
    }

    @Test func queue() async {
        let viewModel = await makeViewModel()
        check("queue", size: CGSize(width: 393, height: 600)) {
            QueueView(viewModel: viewModel)
        }
    }
}
