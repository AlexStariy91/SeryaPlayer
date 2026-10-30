@testable import DataLayer
import Domain
import Foundation
import Testing

struct MetadataReaderTests {
    let reader = MetadataReader()

    static func fixture(_ name: String) throws -> URL {
        try #require(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
    }

    @Test(arguments: ["tagged.mp3", "tagged.m4a", "tagged.flac"])
    func readsTagsAndArtwork(file: String) async throws {
        let metadata = try await reader.read(from: Self.fixture(file))
        #expect(metadata.title == "Тестовая песня")
        #expect(metadata.artist == "Fixture Artist")
        #expect(metadata.album == "Fixture Album")
        #expect(metadata.albumArtist == "Fixture Band")
        #expect(metadata.trackNumber == 3)
        #expect(metadata.duration > 0.3)
        let artwork = try #require(metadata.artworkData)
        #expect(artwork.starts(with: [0x89, 0x50, 0x4E, 0x47]))
    }

    @Test func flacParserReadsVorbisCommentsAndPicture() throws {
        let flac = try #require(FLACMetadata(url: Self.fixture("tagged.flac")))
        #expect(flac.comments["TITLE"] == "Тестовая песня")
        #expect(flac.comments["TRACKNUMBER"] == "3")
        #expect(flac.pictureData?.starts(with: [0x89, 0x50, 0x4E, 0x47]) == true)
        #expect(try FLACMetadata(url: Self.fixture("tagged.mp3")) == nil)
    }

    @Test func untaggedWAVHasNilTags() async throws {
        let metadata = try await reader.read(from: Self.fixture("untagged.wav"))
        #expect(metadata.title == nil)
        #expect(metadata.artist == nil)
        #expect(metadata.album == nil)
        #expect(metadata.trackNumber == nil)
        #expect(metadata.artworkData == nil)
        #expect(metadata.duration > 0.3)
    }

    @Test func nonAudioFileIsUnsupported() async throws {
        await #expect(throws: MetadataError.unsupportedFormat) {
            try await reader.read(from: Self.fixture("not-audio.mp3"))
        }
    }

    @Test func missingFileIsUnreadable() async throws {
        await #expect(throws: MetadataError.unreadable) {
            try await reader.read(from: URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString).mp3"))
        }
    }
}
