import EqualizerFeature
import FoldersFeature
import LibraryFeature
import PlayerFeature

// The container already exposes every requirement under the same name; see "Feature package contract"
// in docs/ARCHITECTURE.md.
extension AppContainer: LibraryDependencies {}
extension AppContainer: FoldersDependencies {}
extension AppContainer: PlayerDependencies {}
extension AppContainer: EqualizerDependencies {}
