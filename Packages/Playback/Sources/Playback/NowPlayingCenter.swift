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

    public init(infoCenter: MPNowPlayingInfoCenter = .default()) {
        self.infoCenter = infoCenter
    }

    public func update(_ info: NowPlayingInfo) {
        var values: [String: Any] = [
            MPMediaItemPropertyTitle: info.title,
            MPMediaItemPropertyArtist: info.artist,
            MPMediaItemPropertyAlbumTitle: info.album,
            MPMediaItemPropertyPlaybackDuration: info.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: info.position,
            MPNowPlayingInfoPropertyPlaybackRate: info.rate,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
        ]
        if let artwork = artwork(for: info.artworkURL) {
            values[MPMediaItemPropertyArtwork] = artwork
        }
        infoCenter.nowPlayingInfo = values
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
