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

    private func row(for preset: EQPreset) -> some View {
        let file = viewModel.exportFile(for: [preset])
        return Text(preset.name)
            .swipeActions(edge: .trailing) {
                Button(String(localized: "Delete", bundle: .module), systemImage: "trash", role: .destructive) { edit = .delete(preset) }
                Button(String(localized: "Rename", bundle: .module), systemImage: "pencil") { edit = .rename(preset) }
                    .tint(.accentColor)
            }
            .contextMenu {
                Button(String(localized: "Rename", bundle: .module), systemImage: "pencil") { edit = .rename(preset) }
                ShareLink(item: file, preview: SharePreview(preset.name)) {
                    Label(String(localized: "Export", bundle: .module), systemImage: "square.and.arrow.up")
                }
                Button(String(localized: "Delete", bundle: .module), systemImage: "trash", role: .destructive) { edit = .delete(preset) }
            }
    }
}
