import DesignSystem
import Domain
import DomainTestSupport
@testable import PlayerFeature
import SnapshotTesting
import SwiftUI
import Testing
import UIKit

@MainActor
struct VisualizerTests {
    @Test func visualizerChoiceIsReadFromSettings() {
        let settings = InMemorySettingsRepository(settings: AppSettings(showsVisualizer: true))
        let viewModel = PlayerViewModel(player: RecordingPlayer(), sleepTimer: StubSleepTimer(), artworkStore: StubArtworkStore(), settingsRepository: settings)
        #expect(viewModel.showsVisualizer)
    }

    @Test func togglingPersistsTheChoiceAndKeepsOtherSettings() {
        let settings = InMemorySettingsRepository(settings: AppSettings(accentColorID: "pink"))
        let viewModel = PlayerViewModel(player: RecordingPlayer(), sleepTimer: StubSleepTimer(), artworkStore: StubArtworkStore(), settingsRepository: settings)
        #expect(!viewModel.showsVisualizer)

        viewModel.toggleVisualizer()
        #expect(viewModel.showsVisualizer)
        #expect(settings.load().showsVisualizer)
        #expect(settings.load().accentColorID == "pink")

        viewModel.toggleVisualizer()
        #expect(!settings.load().showsVisualizer)
    }
}

/// Reference images are recorded on iPhone 16 / iOS 18.1 at 2x, like `SnapshotTests`.
@MainActor
struct VisualizerSnapshotTests {
    private func check(
        _ name: String,
        size: CGSize,
        compact: Bool = false,
        testName: String = #function,
        line: UInt = #line,
        content: () -> some View
    ) {
        let view = content()
        for (styleName, style) in [("light", UIUserInterfaceStyle.light), ("dark", .dark)] {
            var traits = [UITraitCollection(userInterfaceStyle: style), UITraitCollection(displayScale: 2)]
            if compact {
                traits += [UITraitCollection(verticalSizeClass: .compact), UITraitCollection(horizontalSizeClass: .regular)]
            }
            assertSnapshot(
                of: view.tint(AccentPalette.serya.color),
                as: .image(
                    precision: 0.95,
                    perceptualPrecision: 0.9,
                    layout: .fixed(width: size.width, height: size.height),
                    traits: UITraitCollection(traitsFrom: traits)
                ),
                named: "\(name)-\(styleName)",
                testName: testName,
                line: line
            )
        }
    }

    @Test func barsWithPaletteColors() {
        check("bars", size: CGSize(width: 360, height: 360)) {
            PlayerVisualizer(
                spectrum: FakeAudioSpectrum(),
                colors: [.indigo, .pink],
                side: 320,
                levels: PreviewSpectrumLevels.sample
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { ArtworkBackground(colors: [.indigo, .pink, .orange, .teal]) }
            .environment(\.colorScheme, .dark)
        }
    }

    @Test func barsWithTheAccentWhenThereIsNoArtwork() {
        check("accent", size: CGSize(width: 360, height: 360)) {
            PlayerVisualizer(spectrum: FakeAudioSpectrum(), colors: [], side: 320, levels: PreviewSpectrumLevels.sample)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background { ArtworkBackground(colors: []) }
                .environment(\.colorScheme, .dark)
        }
    }

    private func makeVisualizerViewModel() async -> PlayerViewModel {
        let tracks = makeQueue(3)
        let player = RecordingPlayer(snapshot: PlaybackSnapshot(nowPlaying: tracks[0], isPlaying: true, queue: tracks, currentIndex: 0))
        let viewModel = PlayerViewModel(
            player: player,
            sleepTimer: StubSleepTimer(),
            artworkStore: StubArtworkStore(),
            settingsRepository: InMemorySettingsRepository(settings: AppSettings(showsVisualizer: true)),
            spectrum: FakeAudioSpectrum(),
            colorExtractor: { _ in [.indigo, .pink, .orange, .teal] }
        )
        await viewModel.observePlayback()
        return viewModel
    }

    @Test func fullPlayerInVisualizerModeAtRest() async {
        let viewModel = await makeVisualizerViewModel()
        check("full-portrait", size: CGSize(width: 393, height: 852)) {
            FullPlayerView(viewModel: viewModel) { EmptyView() }
        }
    }

    @Test func fullPlayerInVisualizerModeLandscape() async {
        let viewModel = await makeVisualizerViewModel()
        check("full-landscape", size: CGSize(width: 852, height: 393), compact: true) {
            FullPlayerView(viewModel: viewModel) { EmptyView() }
        }
    }
}
