import DesignSystem
import Domain
import SwiftUI

/// Multi-select track picker with search, used to add songs to a playlist.
struct TrackPickerView: View {
    let tracks: [Track]
    let resolver: ArtworkResolver
    let onAdd: ([Track.ID]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [Track]?
    @State private var selection: [Track.ID] = []

    var body: some View {
        NavigationStack {
            List(results ?? tracks) { track in
                Button {
                    toggle(track.id)
                } label: {
                    HStack {
                        TrackRow(title: track.title, subtitle: Strings.subtitle(for: track), duration: track.duration)
                        Image(systemName: selection.contains(track.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selection.contains(track.id) ? Color.accentColor : SemanticColor.textTertiary)
                            .imageScale(.large)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection.contains(track.id) ? .isSelected : [])
            }
            .listStyle(.plain)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
            .task(id: query) {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                let query = query
                let tracks = tracks
                let found = query.trimmingCharacters(in: .whitespaces).isEmpty
                    ? nil
                    : await Task.detached { TrackSearchIndex.filter(tracks, query: query, scope: .all) }.value
                guard !Task.isCancelled else { return }
                results = found
            }
            .navigationTitle(Text("Add Songs", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel", bundle: .module)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Add (\(selection.count))", bundle: .module)) {
                        onAdd(selection)
                        dismiss()
                    }
                    .disabled(selection.isEmpty)
                }
            }
        }
    }

    private func toggle(_ id: Track.ID) {
        if let index = selection.firstIndex(of: id) {
            selection.remove(at: index)
        } else {
            selection.append(id)
        }
    }
}
