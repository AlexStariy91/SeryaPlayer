import Domain
import Foundation

/// What a search in the Folders tab found: matching folders and songs below the searched folder.
struct FolderSearchResults: Equatable {
    var folders: [Folder] = []
    var tracks: [Track] = []

    var isEmpty: Bool {
        folders.isEmpty && tracks.isEmpty
    }
}

/// Searches a folder tree like the Files app: the scope folder and everything below it, recursively.
enum FolderSearch {
    /// Runs off the main actor: a nonisolated `async` function executes on the global executor.
    static func run(_ query: String, in scope: Folder.ID?, folders: [Folder], tracks: [Track]) async -> FolderSearchResults {
        results(for: query, in: scope, folders: folders, tracks: tracks)
    }

    /// Every whitespace-separated term must appear (ignoring case and diacritics) in a folder's name, or in a
    /// song's title, artist or album. Folders are sorted by name, songs by title. The scope folder itself is
    /// not a result.
    static func results(for query: String, in scope: Folder.ID?, folders: [Folder], tracks: [Track]) -> FolderSearchResults {
        let terms = query.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !terms.isEmpty else { return FolderSearchResults() }
        let inScope = scope.map { descendants(of: $0, in: folders).union([$0]) }

        let matchingFolders = folders.filter { folder in
            folder.id != scope
                && (inScope == nil || folder.parentID.map { inScope?.contains($0) == true } == true)
                && matches(terms, [folder.name])
        }
        let matchingTracks = tracks.filter { track in
            (inScope == nil || track.folderID.map { inScope?.contains($0) == true } == true)
                && matches(terms, [track.title, track.artist, track.album])
        }
        return FolderSearchResults(
            folders: matchingFolders.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending },
            tracks: matchingTracks.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        )
    }

    private static func matches(_ terms: [String], _ fields: [String]) -> Bool {
        terms.allSatisfy { term in
            fields.contains { $0.range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
    }

    private static func descendants(of id: Folder.ID, in folders: [Folder]) -> Set<Folder.ID> {
        let children = Dictionary(grouping: folders, by: \.parentID)
        var result: Set<Folder.ID> = []
        var queue = [id]
        while let next = queue.popLast() {
            for child in children[next] ?? [] where result.insert(child.id).inserted {
                queue.append(child.id)
            }
        }
        return result
    }
}
