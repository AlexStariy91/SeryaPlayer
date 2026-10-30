import SwiftUI

/// A gallery of every DesignSystem component for visual checks (previews, simulator).
public struct DesignSystemCatalog: View {
    @State private var current: TimeInterval = 83
    @State private var gains: [Double] = [0, 3, -4.5, 6, 0, -8, 2.5, 0, 9, -2]
    @State private var accent = AccentPalette.serya
    @State private var lastSeek: TimeInterval?

    private let colors: [Color] = [.indigo, .pink, .orange, .teal]
    private let bands = ["32", "64", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]

    public init() {}

    public var body: some View {
        TabView {
            Tab("Library", systemImage: "music.note.list") { catalog }
            Tab("Folders", systemImage: "folder") { emptyState }
        }
        .miniPlayerHost {
            HStack(spacing: Spacing.m) {
                ArtworkView(url: nil, size: .mini)
                Text("Midnight City").font(AppFont.headline).lineLimit(1)
                Spacer()
                Image(systemName: "play.fill")
                Image(systemName: "forward.fill")
            }
            .padding(.horizontal, Spacing.m)
        }
        .adaptiveTabBarMinimize()
        .tint(accent.color)
    }

    private var emptyState: some View {
        EmptyStateView(
            "No Music Yet",
            systemImage: "music.note.house",
            message: "Import audio files to get started.",
            actionTitle: "Import Files"
        ) {}
    }

    private var catalog: some View {
        NavigationStack {
            List {
                accentSection
                Section("Track rows") {
                    TrackRow(title: "Midnight City", subtitle: "M83 · Hurry Up, We're Dreaming", duration: 244)
                    TrackRow(title: "Now Playing Track With a Really Long Title That Truncates", subtitle: "Artist", duration: 3725, isPlaying: true)
                    TrackRow(title: "No Subtitle")
                }
                Section("Artwork sizes") {
                    HStack(spacing: Spacing.m) {
                        ArtworkView(url: nil, size: .row)
                        ArtworkView(url: nil, size: .grid)
                    }
                }
                Section("Timeline slider") {
                    TimelineSlider(current: current, duration: 245) { current = $0; lastSeek = $0 }
                    if let lastSeek {
                        Text("Seek to \(TimeFormat.clock(lastSeek))").font(AppFont.caption)
                    }
                }
                Section("Gain sliders") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.s) {
                            ForEach(bands.indices, id: \.self) { index in
                                VerticalGainSlider(gain: $gains[index], label: bands[index])
                            }
                        }
                    }
                }
                Section("Artwork background") {
                    ArtworkBackground(colors: colors)
                        .frame(height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
                        .listRowInsets(EdgeInsets())
                }
                Section("Glass") {
                    GlassGroup(spacing: Spacing.s) {
                        HStack {
                            Label("Shuffle", systemImage: "shuffle").lineLimit(1).padding(Spacing.m).adaptiveGlass()
                            Label("Repeat", systemImage: "repeat").lineLimit(1).padding(Spacing.m).adaptiveGlass(interactive: true)
                            Button("Play") {}.adaptiveButtonStyle(prominent: true)
                        }
                    }
                }
            }
            .miniPlayerContentInset()
            .navigationTitle("Design System")
        }
    }

    private var accentSection: some View {
        Section("Accent") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(AccentPalette.all) { option in
                        Button { accent = option } label: {
                            Circle().fill(option.color).frame(width: 32, height: 32)
                                .overlay {
                                    if option.id == accent.id {
                                        Image(systemName: "checkmark").foregroundStyle(.white)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(option.localizedName))
                    }
                }
            }
        }
    }
}

#Preview("Catalog") {
    DesignSystemCatalog()
}

#Preview("Catalog dark") {
    DesignSystemCatalog().preferredColorScheme(.dark)
}
