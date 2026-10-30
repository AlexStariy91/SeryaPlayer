import Domain

/// Destinations pushed onto the Library `NavigationStack`.
enum LibraryRoute: Hashable {
    case allTracks
    case artists
    case albums
    case playlists
    /// An artist or album, by `TrackGroup.id`.
    case group(String)
    case playlist(Playlist.ID)
}
