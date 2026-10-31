import EqualizerFeature
import FoldersFeature
import LibraryFeature
import PlayerFeature
import SettingsFeature

// The container already exposes every requirement under the same name; see "Feature package contract"
// in docs/ARCHITECTURE.md.
extension AppContainer: LibraryDependencies {}
extension AppContainer: FoldersDependencies {}
extension AppContainer: PlayerDependencies {}
extension AppContainer: EqualizerDependencies {}
extension AppContainer: SettingsDependencies {}
