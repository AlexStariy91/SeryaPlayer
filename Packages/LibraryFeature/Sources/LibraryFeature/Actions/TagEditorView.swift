import DesignSystem
import Domain
import PhotosUI
import SwiftUI

/// "Edit Tags…": title, artist, album and artwork from the photo library.
struct TagEditorView: View {
    @State var viewModel: TagEditorViewModel
    let artwork: ArtworkResolver

    @Environment(\.dismiss) private var dismiss
    @State private var photo: PhotosPickerItem?
    @State private var currentArtworkURL: URL?

    var body: some View {
        // PhotosPicker's label closure is nonisolated in the iOS 18 SDK, so capture plain values.
        let pickedData = viewModel.artworkData
        let currentURL = currentArtworkURL
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $photo, matching: .images) {
                            VStack(spacing: Spacing.s) {
                                TagArtworkPreview(data: pickedData, currentURL: currentURL)
                                Text("Choose Artwork", bundle: .module)
                                    .font(AppFont.rowSubtitle)
                            }
                        }
                        .accessibilityIdentifier("tags.artwork")
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)

                Section {
                    TextField(String(localized: "Title", bundle: .module), text: $viewModel.title)
                        .accessibilityIdentifier("tags.title")
                    TextField(String(localized: "Artist", bundle: .module), text: $viewModel.artist)
                    TextField(String(localized: "Album", bundle: .module), text: $viewModel.album)
                } footer: {
                    if let message = viewModel.errorMessage {
                        Text(message).foregroundStyle(.red)
                    } else {
                        Text("Changes are saved in the library only; the audio file isn't modified.", bundle: .module)
                    }
                }
            }
            .navigationTitle(Text("Edit Tags", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel", bundle: .module)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save", bundle: .module)) {
                        Task {
                            if await viewModel.save() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.canSave || !viewModel.hasChanges)
                }
            }
            .task(id: photo) {
                guard let photo else { return }
                await viewModel.setArtwork(try? photo.loadTransferable(type: Data.self))
            }
            .task {
                currentArtworkURL = await artwork.url(for: viewModel.track.artworkKey, size: .large)
            }
        }
        .interactiveDismissDisabled(viewModel.hasChanges)
    }
}

/// The newly picked image, or the current artwork.
private struct TagArtworkPreview: View {
    let data: Data?
    let currentURL: URL?

    var body: some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: DesignSystem.ArtworkSize.grid.points, height: DesignSystem.ArtworkSize.grid.points)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.ArtworkSize.grid.cornerRadius, style: .continuous))
                .accessibilityHidden(true)
        } else {
            ArtworkView(url: currentURL, size: .grid)
        }
    }
}
