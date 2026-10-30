@testable import DesignSystem
import SnapshotTesting
import SwiftUI
import Testing
import UIKit

/// Reference images are recorded on iPhone 16 / iOS 18.1 at 2x. Delete a reference to re-record it.
@MainActor
struct SnapshotTests {
    private struct Variant {
        let name: String
        let style: UIUserInterfaceStyle
        let category: UIContentSizeCategory
    }

    private static let variants = [
        Variant(name: "light", style: .light, category: .large),
        Variant(name: "dark", style: .dark, category: .large),
        Variant(name: "light-xxxl", style: .light, category: .accessibilityExtraExtraExtraLarge),
        Variant(name: "dark-xxxl", style: .dark, category: .accessibilityExtraExtraExtraLarge),
    ]

    private func check(
        _ name: String,
        width: CGFloat = 390,
        height: CGFloat,
        fileID: StaticString = #fileID,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        @ViewBuilder content: () -> some View
    ) {
        let view = content()
        for variant in Self.variants {
            let traits = UITraitCollection(traitsFrom: [
                UITraitCollection(userInterfaceStyle: variant.style),
                UITraitCollection(preferredContentSizeCategory: variant.category),
                UITraitCollection(displayScale: 2),
            ])
            let styled = view.background(SemanticColor.background).tint(AccentPalette.serya.color)
            assertSnapshot(
                of: styled,
                as: .image(precision: 0.95, perceptualPrecision: 0.9, layout: .fixed(width: width, height: height), traits: traits),
                named: "\(name)-\(variant.name)",
                fileID: fileID,
                file: file,
                testName: testName,
                line: line
            )
        }
    }

    @Test func trackRows() {
        check("rows", height: 760) {
            VStack(alignment: .leading, spacing: Spacing.l) {
                TrackRow(title: "Midnight City", subtitle: "M83 · Hurry Up, We're Dreaming", duration: 244)
                TrackRow(title: "A Really Long Track Title That Has To Truncate", subtitle: "Artist", duration: 3725, isPlaying: true)
                TrackRow(title: "No Subtitle")
            }
            .padding(Spacing.screenMargin)
        }
    }

    @Test func timelineSlider() {
        check("timeline", height: 140) {
            TimelineSlider(current: 83, duration: 245) { _ in }
                .padding(Spacing.screenMargin)
        }
    }

    @Test func gainSliders() {
        check("gain", height: 300) {
            HStack(spacing: Spacing.m) {
                VerticalGainSlider(gain: .constant(0), label: "32")
                VerticalGainSlider(gain: .constant(6.5), label: "1k")
                VerticalGainSlider(gain: .constant(-12), label: "16k")
            }
            .padding(Spacing.screenMargin)
        }
    }

    @Test func emptyState() {
        check("empty", height: 380) {
            EmptyStateView("No Music Yet", systemImage: "music.note.house", message: "Import audio files to get started.", actionTitle: "Import Files") {}
        }
    }

    @Test func artworkBackgroundAndPlaceholders() {
        check("artwork", height: 300) {
            ZStack {
                ArtworkBackground(colors: [.indigo, .pink, .orange, .teal])
                HStack {
                    ArtworkView(url: nil, size: .row)
                    ArtworkView(url: nil, size: .custom(120))
                }
            }
        }
    }

    @Test func accentPalette() {
        check("accents", height: 120) {
            HStack {
                ForEach(AccentPalette.all) { option in
                    Circle().fill(option.color).frame(width: 28, height: 28)
                }
            }
            .padding(Spacing.screenMargin)
        }
    }
}
