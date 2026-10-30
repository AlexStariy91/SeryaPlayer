import Domain
import SwiftUI

/// A pending name prompt or delete confirmation.
enum PresetEdit: Identifiable, Equatable {
    case save
    case rename(EQPreset)
    case delete(EQPreset)

    var id: String {
        switch self {
        case .save: "save"
        case let .rename(preset): "rename-\(preset.id)"
        case let .delete(preset): "delete-\(preset.id)"
        }
    }
}

/// Alerts shared by the sheet and the manager: name prompt, delete confirmation, error.
private struct PresetEditAlerts: ViewModifier {
    let viewModel: EqualizerViewModel
    @Binding var edit: PresetEdit?
    @State private var name = ""

    func body(content: Content) -> some View {
        content
            .onChange(of: edit) { _, newValue in
                if case let .rename(preset) = newValue {
                    name = preset.name
                } else if newValue == .save {
                    name = ""
                }
            }
            .alert(namePromptTitle, isPresented: Binding(get: { isNamePrompt }, set: {
                if !$0 {
                    edit = nil
                }
            })) {
                TextField(String(localized: "Name", bundle: .module), text: $name)
                Button(String(localized: "Save", bundle: .module)) { commitName() }
                Button(String(localized: "Cancel", bundle: .module), role: .cancel) {}
            }
            .confirmationDialog(
                String(localized: "Delete this preset?", bundle: .module),
                isPresented: Binding(get: { deleteTarget != nil }, set: {
                    if !$0 {
                        edit = nil
                    }
                }),
                titleVisibility: .visible
            ) {
                if let preset = deleteTarget {
                    Button(String(localized: "Delete", bundle: .module), role: .destructive) {
                        Task { await viewModel.delete(preset) }
                    }
                }
            }
            .alert(
                String(localized: "Something Went Wrong", bundle: .module),
                isPresented: Binding(get: { viewModel.errorMessage != nil }, set: {
                    if !$0 {
                        viewModel.errorMessage = nil
                    }
                })
            ) {
                Button(String(localized: "OK", bundle: .module), role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
    }

    private var isNamePrompt: Bool {
        switch edit {
        case .save, .rename: true
        default: false
        }
    }

    private var deleteTarget: EQPreset? {
        if case let .delete(preset) = edit {
            preset
        } else {
            nil
        }
    }

    private var namePromptTitle: String {
        if case .rename = edit {
            String(localized: "Rename Preset", bundle: .module)
        } else {
            String(localized: "Save Preset", bundle: .module)
        }
    }

    private func commitName() {
        let name = name
        switch edit {
        case .save: Task { await viewModel.saveCurrent(as: name) }
        case let .rename(preset): Task { await viewModel.rename(preset, to: name) }
        default: break
        }
    }
}

extension View {
    func presetEditAlerts(viewModel: EqualizerViewModel, edit: Binding<PresetEdit?>) -> some View {
        modifier(PresetEditAlerts(viewModel: viewModel, edit: edit))
    }
}
