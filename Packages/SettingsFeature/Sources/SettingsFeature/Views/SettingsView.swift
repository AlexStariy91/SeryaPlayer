import DesignSystem
import Domain
import SwiftUI

struct SettingsView<PresetManager: View>: View {
    @State private var viewModel: SettingsViewModel
    @State private var isConfirmingClear = false
    @Environment(\.dismiss) private var dismiss
    private let presetManager: () -> PresetManager

    init(viewModel: SettingsViewModel, presetManager: @escaping () -> PresetManager) {
        _viewModel = State(initialValue: viewModel)
        self.presetManager = presetManager
    }

    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                equalizerSection
                storageSection
                aboutSection
            }
            .navigationTitle(Text("Settings", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done", bundle: .module)) { dismiss() }
                }
            }
            .task { await viewModel.observeSettings() }
            .task { await viewModel.refreshSizes() }
            .alert(
                Text("Couldn't Clear Cache", bundle: .module),
                isPresented: Binding(get: { viewModel.errorMessage != nil }, set: {
                    if !$0 {
                        viewModel.errorMessage = nil
                    }
                })
            ) {
                Button(String(localized: "OK", bundle: .module)) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var appearanceSection: some View {
        Section {
            Picker(selection: Binding(get: { viewModel.theme }, set: { viewModel.select(theme: $0) })) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Text(Strings.name(of: theme)).tag(theme)
                }
            } label: {
                Text("Theme", bundle: .module)
            }
            .pickerStyle(.segmented)
            AccentPicker(selectedID: viewModel.accentColorID, onSelect: { viewModel.select(accentColorID: $0) })
        } header: {
            Text("Appearance", bundle: .module)
        }
    }

    private var equalizerSection: some View {
        Section {
            NavigationLink {
                presetManager()
            } label: {
                Label(String(localized: "Equalizer Presets", bundle: .module), systemImage: "slider.vertical.3")
            }
        } header: {
            Text("Equalizer", bundle: .module)
        }
    }

    private var storageSection: some View {
        Section {
            LabeledContent {
                SizeText(bytes: viewModel.librarySize)
            } label: {
                Text("Library", bundle: .module)
            }
            LabeledContent {
                SizeText(bytes: viewModel.artworkCacheSize)
            } label: {
                Text("Artwork Cache", bundle: .module)
            }
            Button(role: .destructive) {
                isConfirmingClear = true
            } label: {
                Text("Clear Artwork Cache", bundle: .module)
            }
            .disabled(viewModel.isClearingArtwork)
            .confirmationDialog(
                Text("Clear Artwork Cache?", bundle: .module),
                isPresented: $isConfirmingClear,
                titleVisibility: .visible
            ) {
                Button(String(localized: "Clear", bundle: .module), role: .destructive) {
                    Task { await viewModel.clearArtworkCache() }
                }
            } message: {
                Text("Covers are rebuilt the next time they are shown. Your music is not affected.", bundle: .module)
            }
        } header: {
            Text("Storage", bundle: .module)
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent {
                Text(viewModel.appInfo.name)
            } label: {
                Text("App", bundle: .module)
            }
            LabeledContent {
                Text(viewModel.appInfo.versionString)
            } label: {
                Text("Version", bundle: .module)
            }
        } header: {
            Text("About", bundle: .module)
        } footer: {
            Text("An offline player for your own music: files, folders and playlists, with a 10-band equalizer.", bundle: .module)
        }
    }
}

private struct SizeText: View {
    let bytes: Int64?
    @Environment(\.locale) private var locale

    var body: some View {
        if let bytes {
            Text(Strings.size(bytes, locale: locale))
        } else {
            ProgressView()
        }
    }
}
