import DesignSystem
import Domain
import SwiftUI

/// The user's presets: rename, delete, export, import. Embedded in Settings.
struct PresetManagerView: View {
    @State private var viewModel: EqualizerViewModel
    @State private var edit: PresetEdit?
    @State private var isImporting = false

    init(viewModel: EqualizerViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List {
            Section {
                if viewModel.userPresets.isEmpty {
                    ContentUnavailableView(
                        String(localized: "No Saved Presets", bundle: .module),
                        systemImage: "slider.vertical.3",
                        description: Text("Shape the curve in the equalizer and choose Save As… to keep it here.", bundle: .module)
                    )
                } else {
                    ForEach(viewModel.userPresets) { preset in
                        row(for: preset)
                    }
                }
            }
            Section {
                Button(String(localized: "Import Presets…", bundle: .module), systemImage: "square.and.arrow.down") {
                    isImporting = true
                }
                if !viewModel.userPresets.isEmpty {
                    let file = viewModel.exportFile(for: viewModel.userPresets)
                    ShareLink(item: file, preview: SharePreview(file.fileName)) {
                        Label(String(localized: "Export All", bundle: .module), systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .navigationTitle(Text("Equalizer Presets", bundle: .module))
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.eqPresets, .json], allowsMultipleSelection: true) { result in
            guard case let .success(urls) = result else { return }
            Task { await viewModel.importPresets(from: urls) }
        }
        .presetEditAlerts(viewModel: viewModel, edit: $edit)
        .task { await viewModel.start() }
    }

    /// Tapping a row opens its actions; swipe keeps the quick Rename/Delete.
    private func row(for preset: EQPreset) -> some View {
        Menu {
            actions(for: preset)
        } label: {
            HStack {
                Text(preset.name)
                    .foregroundStyle(SemanticColor.textPrimary)
                Spacer()
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .swipeActions(edge: .trailing) {
            // No destructive role: SwiftUI would remove the row before the deletion is confirmed,
            // and the real removal then crashes the list ("attempt to delete item 1 …").
            Button(String(localized: "Delete", bundle: .module), systemImage: "trash") { edit = .delete(preset) }
                .tint(.red)
            Button(String(localized: "Rename", bundle: .module), systemImage: "pencil") { edit = .rename(preset) }
                .tint(.accentColor)
        }
    }

    @ViewBuilder
    private func actions(for preset: EQPreset) -> some View {
        let file = viewModel.exportFile(for: [preset])
        Button(String(localized: "Rename", bundle: .module), systemImage: "pencil") { edit = .rename(preset) }
        ShareLink(item: file, preview: SharePreview(preset.name)) {
            Label(String(localized: "Export", bundle: .module), systemImage: "square.and.arrow.up")
        }
        Button(String(localized: "Delete", bundle: .module), systemImage: "trash", role: .destructive) { edit = .delete(preset) }
    }
}
