import SwiftUI

/// A track row: artwork, title, subtitle, duration. The current track gets an indicator over the artwork:
/// live spectrum bars while playing (when given a `levels` source), still bars while paused.
public struct TrackRow: View {
    public enum NowPlaying: Sendable, Hashable {
        case playing
        case paused
    }

    private let title: String
    private let subtitle: String?
    private let artworkURL: URL?
    private let duration: TimeInterval?
    private let nowPlaying: NowPlaying?
    private let levels: SpectrumLevelsSource?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(
        title: String,
        subtitle: String? = nil,
        artworkURL: URL? = nil,
        duration: TimeInterval? = nil,
        nowPlaying: NowPlaying? = nil,
        levels: SpectrumLevelsSource? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.artworkURL = artworkURL
        self.duration = duration
        self.nowPlaying = nowPlaying
        self.levels = levels
    }

    public var body: some View {
        HStack(spacing: Spacing.m) {
            ArtworkView(url: artworkURL, size: .row)
                .overlay {
                    if let nowPlaying {
                        nowPlayingIndicator(nowPlaying)
                    }
                }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(AppFont.rowTitle)
                    .foregroundStyle(nowPlaying != nil ? Color.accentColor : SemanticColor.textPrimary)
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
        .accessibilityAddTraits(nowPlaying != nil ? .isSelected : [])
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

    private func nowPlayingIndicator(_ state: NowPlaying) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: ArtworkSize.row.cornerRadius, style: .continuous)
                .fill(.black.opacity(0.45))
            NowPlayingBars(state: state, source: levels)
        }
        .frame(width: ArtworkSize.row.points, height: ArtworkSize.row.points)
        .accessibilityLabel(state == .playing ? Text("Now playing", bundle: .module) : Text("Paused", bundle: .module))
    }
}

#Preview("Track rows") {
    List {
        TrackRow(title: "Midnight City", subtitle: "M83", duration: 244)
        TrackRow(title: "Now Playing", subtitle: "Artist", duration: 3725, nowPlaying: .playing)
        TrackRow(title: "Paused", subtitle: "Artist", duration: 3725, nowPlaying: .paused)
    }
}
