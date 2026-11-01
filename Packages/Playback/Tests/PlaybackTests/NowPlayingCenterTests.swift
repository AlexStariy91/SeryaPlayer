import Domain
import Foundation
import MediaPlayer
@testable import Playback
import Testing
import UIKit

@MainActor
struct NowPlayingCenterTests {
    private let placeholder = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { context in
        UIColor.gray.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
    }

    private func info(artworkURL: URL?) -> NowPlayingInfo {
        NowPlayingInfo(title: "T", artist: "A", album: "B", artworkURL: artworkURL, duration: 10, position: 0, rate: 1)
    }

    @Test func usesPlaceholderWhenThereIsNoArtworkURL() {
        let center = NowPlayingCenter(placeholderArtwork: placeholder)
        let values = center.nowPlayingValues(for: info(artworkURL: nil))
        #expect(values[MPMediaItemPropertyArtwork] is MPMediaItemArtwork)
    }

    @Test func usesPlaceholderWhenTheFileIsNotAnImage() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
        try Data("not an image".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let center = NowPlayingCenter(placeholderArtwork: placeholder)
        let values = center.nowPlayingValues(for: info(artworkURL: url))
        #expect(values[MPMediaItemPropertyArtwork] is MPMediaItemArtwork)
    }

    @Test func usesTheTrackArtworkOverThePlaceholder() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).png")
        try #require(placeholder.pngData()).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let center = NowPlayingCenter(placeholderArtwork: nil)
        let values = center.nowPlayingValues(for: info(artworkURL: url))
        #expect(values[MPMediaItemPropertyArtwork] is MPMediaItemArtwork)
    }

    @Test func setsNoArtworkWithoutAPlaceholder() {
        let center = NowPlayingCenter()
        let values = center.nowPlayingValues(for: info(artworkURL: nil))
        #expect(values[MPMediaItemPropertyArtwork] == nil)
    }
}
