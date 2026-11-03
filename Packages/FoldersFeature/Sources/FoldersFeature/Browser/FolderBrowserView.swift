import DesignSystem
import Domain
import SwiftUI

/// The library root or one folder: subfolders (reorderable), songs, multi-select and batch actions.
struct FolderBrowserView: View {
    @State private var viewModel: FolderBrowserViewModel

    init(folderID: Folder.ID?, context: FoldersContext) {
        _viewModel = State(initialValue: FolderBrowserViewModel(folderID: folderID, context: context))
    }

    init(viewModel: FolderBrowserViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var isEditing: Bool {
        viewModel.isEditing
    }

    private var editMode: Binding<EditMode> {
        Binding(
            get: { viewModel.isEditing ? .active : .inactive },
            set: { viewModel.isEditing = $0.isEditing }
        )
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        // Selection exists only while editing. Bound outside edit mode, the list mirrors it into the
        // collection view's own selection: a tapped folder can stay highlighted after navigating back,
        // and every cell pays for selection bookkeeping while scrolling. iOS 26 needs it bound from the start
        // to show checkmarks, so there it is bound but empty outside edit mode (see `EditingSelection`).
        List(selection: EditingSelection.binding($viewModel.selection, isEditing: isEditing)) {
            if let results = viewModel.searchResults, viewModel.isSearching {
                searchContent(results)
            } else {
                browseContent
            }
        }
        .listStyle(.plain)
        .pinnedSectionHeaders()
        .searchable(text: $viewModel.searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: searchPrompt)
        .task(id: viewModel.searchKey) {
            // Debounce: a newer keystroke cancels this task before it searches.
            if viewModel.isSearching, viewModel.searchResults != nil {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
            }
            await viewModel.search()
        }
        .overlay { emptyState }
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(viewModel.folderID == nil ? .large : .inline)
        // While selecting, "Select All" is the only item at the leading edge (as in Files and Photos), so it does not
        // fight the back label for space; this also turns off swipe-back. Done leaves the mode.
        .navigationBarBackButtonHidden(isEditing)
        .environment(\.editMode, editMode)
        .toolbar { toolbar }
        .onChange(of: viewModel.isEmpty) { _, isEmpty in
            // Deleted elsewhere (or by a batch here): nothing is left to select.
            if isEmpty {
                viewModel.isEditing = false
            }
        }
        .modifier(FolderDialogs(viewModel: viewModel))
    }

    @ViewBuilder
    private var browseContent: some View {
        if !viewModel.subfolders.isEmpty {
            Section {
                ForEach(viewModel.subfolders) { folder in
                    NavigationLink(value: FoldersRoute.folder(folder.id)) {
                        FolderRow(folder: folder, songCount: viewModel.songCount(in: folder))
                    }
                    .tag(FolderItem.folder(folder.id))
                    .contextMenu { folderMenu(folder) }
                    .swipeActions(edge: .trailing) {
                        // No destructive role: SwiftUI would remove the row before the deletion is
                        // confirmed, and the real removal then crashes the list.
                        Button {
                            Task { await viewModel.requestDelete(items: [.folder(folder.id)]) }
                        } label: {
                            Label(String(localized: "Delete", bundle: .module), systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }
                .onMove { source, destination in
                    Task { await viewModel.moveFolders(fromOffsets: source, toOffset: destination) }
                }
            } header: {
                Text("Folders", bundle: .module)
            }
        }
        if !viewModel.tracks.isEmpty {
            Section {
                ForEach(viewModel.tracks) { track in
                    FolderTrackRow(
                        track: track,
                        playback: viewModel.playback,
                        resolver: viewModel.artwork,
                        isEditing: isEditing
                    ) { viewModel.play(track) }
                        .tag(FolderItem.track(track.id))
                        .contextMenu { trackMenu(track) }
                        .swipeActions(edge: .trailing) {
                            // No destructive role: see the folder row above.
                            Button {
                                Task { await viewModel.requestDelete(items: [.track(track.id)]) }
                            } label: {
                                Label(String(localized: "Delete", bundle: .module), systemImage: "trash")
                            }
                            .tint(.red)
                        }
                }
            } header: {
                Text("Songs", bundle: .module)
            }
        }
    }

    @ViewBuilder
    private func searchContent(_ results: FolderSearchResults) -> some View {
        if !results.folders.isEmpty {
            Section {
                ForEach(results.folders) { folder in
                    NavigationLink(value: FoldersRoute.folder(folder.id)) {
                        FolderRow(folder: folder, songCount: viewModel.songCount(in: folder))
                    }
                    .contextMenu { folderMenu(folder) }
                }
            } header: {
                Text("Folders", bundle: .module)
            }
        }
        if !results.tracks.isEmpty {
            Section {
                ForEach(results.tracks) { track in
                    FolderTrackRow(
                        track: track,
                        playback: viewModel.playback,
                        resolver: viewModel.artwork
                    ) { viewModel.playSearchResult(track) }
                        .contextMenu { trackMenu(track) }
                }
            } header: {
                Text("Songs", bundle: .module)
            }
        }
    }

    private var searchPrompt: Text {
        viewModel.folderID == nil
            ? Text("Folders and Songs", bundle: .module)
            : Text("Search in This Folder", bundle: .module)
    }

    @ViewBuilder
    private var emptyState: some View {
        if viewModel.isSearching {
            if viewModel.searchResults?.isEmpty == true {
                ContentUnavailableView.search(text: viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        } else if viewModel.isMissing {
            ContentUnavailableView(String(localized: "Folder Not Found", bundle: .module), systemImage: "folder.badge.questionmark")
        } else if viewModel.isLoaded, viewModel.isEmpty {
            if viewModel.folderID == nil {
                ContentUnavailableView {
                    Label(String(localized: "No Folders", bundle: .module), systemImage: "folder")
                } description: {
                    Text("Create a folder to organize your music.", bundle: .module)
                } actions: {
                    Button(String(localized: "New Folder", bundle: .module), action: viewModel.beginCreate)
                        .buttonStyle(.borderedProminent)
                }
            } else {
                ContentUnavailableView {
                    Label(String(localized: "Empty Folder", bundle: .module), systemImage: "folder")
                } description: {
                    Text("Move songs here from All Songs or create a subfolder.", bundle: .module)
                } actions: {
                    Button(String(localized: "New Folder", bundle: .module), action: viewModel.beginCreate)
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if isEditing {
            ToolbarItem(placement: .topBarLeading) {
                Button(
                    viewModel.isAllSelected
                        ? String(localized: "Deselect All", bundle: .module)
                        : String(localized: "Select All", bundle: .module),
                    action: viewModel.toggleSelectAll
                )
                .accessibilityIdentifier("folders.selectAll")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(String(localized: "Move…", bundle: .module), systemImage: "folder") {
                        viewModel.beginMove(viewModel.selection)
                    }
                    Button(String(localized: "Delete", bundle: .module), systemImage: "trash", role: .destructive) {
                        Task { await viewModel.requestDelete(items: viewModel.selection) }
                    }
                } label: {
                    Label(String(localized: "Actions", bundle: .module), systemImage: "ellipsis.circle")
                }
                .disabled(viewModel.selection.isEmpty)
                .accessibilityIdentifier("folders.actions")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: "Done", bundle: .module)) { viewModel.isEditing = false }
                    .accessibilityIdentifier("folders.done")
            }
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: "Select", bundle: .module)) { viewModel.isEditing = true }
                    .disabled(viewModel.isEmpty || viewModel.isSearching)
                    .accessibilityIdentifier("folders.select")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: "New Folder", bundle: .module), systemImage: "folder.badge.plus", action: viewModel.beginCreate)
                    .accessibilityIdentifier("folders.new")
            }
        }
    }

    @ViewBuilder
    private func folderMenu(_ folder: Folder) -> some View {
        Button(String(localized: "Play", bundle: .module), systemImage: "play") {
            viewModel.play(folder: folder.id, shuffled: false)
        }
        Button(String(localized: "Shuffle", bundle: .module), systemImage: "shuffle") {
            viewModel.play(folder: folder.id, shuffled: true)
        }
        Button(String(localized: "Rename", bundle: .module), systemImage: "pencil") {
            viewModel.beginRename(folder)
        }
        Button(String(localized: "Move…", bundle: .module), systemImage: "folder") {
            viewModel.beginMove([.folder(folder.id)])
        }
        Button(String(localized: "Delete", bundle: .module), systemImage: "trash", role: .destructive) {
            Task { await viewModel.requestDelete(items: [.folder(folder.id)]) }
        }
    }

    @ViewBuilder
    private func trackMenu(_ track: Track) -> some View {
        Button(String(localized: "Move…", bundle: .module), systemImage: "folder") {
            viewModel.beginMove([.track(track.id)])
        }
        Button(String(localized: "Delete", bundle: .module), systemImage: "trash", role: .destructive) {
            Task { await viewModel.requestDelete(items: [.track(track.id)]) }
        }
    }
}

/// Alerts, the delete confirmation and the move picker of a folder screen.
private struct FolderDialogs: ViewModifier {
    @Bindable var viewModel: FolderBrowserViewModel

    func body(content: Content) -> some View {
        content
            .alert(
                namePromptTitle,
                isPresented: Binding(get: { viewModel.namePrompt != nil }, set: {
                    if !$0 {
                        viewModel.namePrompt = nil
                    }
                }),
                presenting: viewModel.namePrompt
            ) { prompt in
                TextField(String(localized: "Name", bundle: .module), text: $viewModel.nameText)
                Button(String(localized: "Cancel", bundle: .module), role: .cancel) {}
                Button(prompt == .create ? String(localized: "Create", bundle: .module) : String(localized: "Rename", bundle: .module)) {
                    Task { await viewModel.commitName(for: prompt) }
                }
            }
            .confirmationDialog(
                viewModel.pendingDeletion?.title ?? "",
                isPresented: Binding(get: { viewModel.pendingDeletion != nil }, set: {
                    if !$0 {
                        viewModel.cancelDeletion()
                    }
                }),
                titleVisibility: .visible,
                presenting: viewModel.pendingDeletion
            ) { request in
                if request.folderTrackCount > 0 {
                    Button(String(localized: "Delete Songs", bundle: .module), role: .destructive) {
                        Task { await viewModel.performDeletion(request, policy: .deleteTracks) }
                    }
                    Button(String(localized: "Keep Songs in Library", bundle: .module)) {
                        Task { await viewModel.performDeletion(request, policy: .moveTracksToRoot) }
                    }
                } else {
                    Button(String(localized: "Delete", bundle: .module), role: .destructive) {
                        Task { await viewModel.performDeletion(request, policy: .moveTracksToRoot) }
                    }
                }
                Button(String(localized: "Cancel", bundle: .module), role: .cancel) {}
            } message: { request in
                Text(deletionMessage(request))
            }
            .modifier(FolderMoveAndErrorDialogs(viewModel: viewModel))
    }

    private var namePromptTitle: String {
        if case .rename = viewModel.namePrompt {
            String(localized: "Rename Folder", bundle: .module)
        } else {
            String(localized: "New Folder", bundle: .module)
        }
    }

    private func deletionMessage(_ request: DeletionRequest) -> String {
        if request.folderTrackCount > 0 {
            String(localized: "\(request.folderTrackCount) songs are inside. Delete them from the device or keep them in the library?", bundle: .module)
        } else {
            String(localized: "This also removes the audio files from the device.", bundle: .module)
        }
    }
}

/// The move picker sheet and the error alert of a folder screen.
private struct FolderMoveAndErrorDialogs: ViewModifier {
    @Bindable var viewModel: FolderBrowserViewModel

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: Binding(get: { viewModel.movingItems != nil }, set: {
                if !$0 {
                    viewModel.movingItems = nil
                }
            })) {
                if let items = viewModel.movingItems {
                    FolderMovePickerView(items: items, viewModel: viewModel)
                }
            }
            .alert(
                String(localized: "Something Went Wrong", bundle: .module),
                isPresented: Binding(get: { viewModel.errorMessage != nil }, set: {
                    if !$0 {
                        viewModel.errorMessage = nil
                    }
                }),
                presenting: viewModel.errorMessage
            ) { _ in
                Button(String(localized: "OK", bundle: .module), role: .cancel) {}
            } message: { message in
                Text(message)
            }
    }
}
