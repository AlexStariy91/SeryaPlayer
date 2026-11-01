import Domain
import Foundation
import MediaPlayer
import UIKit

/// Publishes the current track to the Lock Screen, Control Center and connected accessories.
/// `NowPlayingInfo.rate` is the effective rate: 0 while paused.
@MainActor
public final class NowPlayingCenter: NowPlayingPublishing {
    private let infoCenter: MPNowPlayingInfoCenter
    private var artwork: (url: URL, artwork: MPMediaItemArtwork?)?
    /// Built once and reused for every track without a usable cover.
    private let placeholder: MPMediaItemArtwork?

    /// `placeholderArtwork` is shown when a track has no artwork or the file can't be decoded.
    /// It is injected because Playback must not depend on DesignSystem.
    public init(infoCenter: MPNowPlayingInfoCenter = .default(), placeholderArtwork: UIImage? = nil) {
        self.infoCenter = infoCenter
        placeholder = placeholderArtwork.map(Self.makeArtwork)
    }

    public func update(_ info: NowPlayingInfo) {
        infoCenter.nowPlayingInfo = nowPlayingValues(for: info)
    }

    func nowPlayingValues(for info: NowPlayingInfo) -> [String: Any] {
        var values: [String: Any] = [
            MPMediaItemPropertyTitle: info.title,
            MPMediaItemPropertyArtist: info.artist,
            MPMediaItemPropertyAlbumTitle: info.album,
            MPMediaItemPropertyPlaybackDuration: info.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: info.position,
            MPNowPlayingInfoPropertyPlaybackRate: info.rate,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: info.defaultRate,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
        ]
        if let artwork = artwork(for: info.artworkURL) ?? placeholder {
            values[MPMediaItemPropertyArtwork] = artwork
        }
        return values
    }

    public func clear() {
        infoCenter.nowPlayingInfo = nil
        artwork = nil
    }

    /// Caches the artwork per URL: `update` is called on every pause, seek and rate change.
    private func artwork(for url: URL?) -> MPMediaItemArtwork? {
        guard let url else { return nil }
        if let cached = artwork, cached.url == url {
            return cached.artwork
        }
        let made = UIImage(contentsOfFile: url.path).map(Self.makeArtwork)
        artwork = (url, made)
        return made
    }

    /// Nonisolated so the request handler isn't main-actor isolated: MediaPlayer calls it on a
    /// background queue, and an isolated closure would trap there under Swift 6.
    private nonisolated static func makeArtwork(_ image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }
}
