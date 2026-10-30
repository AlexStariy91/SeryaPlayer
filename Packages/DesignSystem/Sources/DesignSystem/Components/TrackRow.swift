import SwiftUI

/// A track row: artwork, title, subtitle, duration. A "now playing" indicator is drawn over the artwork.
public struct TrackRow: View {
    private let title: String
    private let subtitle: String?
    private let artworkURL: URL?
    private let duration: TimeInterval?
    private let isPlaying: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(title: String, subtitle: String? = nil, artworkURL: URL? = nil, duration: TimeInterval? = nil, isPlaying: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.artworkURL = artworkURL
        self.duration = duration
        self.isPlaying = isPlaying
    }

    public var body: some View {
        HStack(spacing: Spacing.m) {
            ArtworkView(url: artworkURL, size: .row)
                .overlay {
                    if isPlaying {
                        nowPlayingIndicator
                    }
                }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(AppFont.rowTitle)
                    .foregroundStyle(isPlaying ? Color.accentColor : SemanticColor.textPrimary)
                    .lineLimit(isLargeText ? 2 : 1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(AppFont.rowSubtitle)
                        .foregroundStyle(SemanticColor.textSecondary)
                        .lineLimit(isLargeText ? 2 : 1)
                }
                // At accessibility sizes the duration moves under the text so the title keeps its width.
                if isLargeText, let duration {
                    durationLabel(duration)
                }
            }
            Spacer(minLength: Spacing.s)
            if !isLargeText, let duration {
                durationLabel(duration)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isPlaying ? .isSelected : [])
    }

    private var isLargeText: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private func durationLabel(_ duration: TimeInterval) -> some View {
        Text(TimeFormat.clock(duration))
            .font(AppFont.time)
            .foregroundStyle(SemanticColor.textSecondary)
            .lineLimit(1)
            .fixedSize()
    }

    private var nowPlayingIndicator: some View {
        ZStack {
            RoundedRectangle(cornerRadius: ArtworkSize.row.cornerRadius, style: .continuous)
                .fill(.black.opacity(0.45))
            Image(systemName: "waveform")
                // Fixed size on purpose: the indicator lives in a fixed 48 pt artwork square.
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .symbolEffect(.variableColor.iterative.reversing, options: .repeating, isActive: !reduceMotion)
        }
        .frame(width: ArtworkSize.row.points, height: ArtworkSize.row.points)
        .accessibilityLabel(Text("Now playing"))
    }
}

#Preview("Track rows") {
    List {
        TrackRow(title: "Midnight City", subtitle: "M83", duration: 244)
        TrackRow(title: "Now Playing", subtitle: "Artist", duration: 3725, isPlaying: true)
    }
}
