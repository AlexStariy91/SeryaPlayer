import AVFoundation
import Domain
import Foundation

/// Reads tags with `AVURLAsset`. Missing tags come back as `nil`; the import use case falls back
/// to the file name.
public struct MetadataReader: MetadataReading {
    public init() {}

    public func read(from url: URL) async throws -> TrackMetadata {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let asset = AVURLAsset(url: url)
        let isPlayable: Bool
        let duration: CMTime
        let tracks: [AVAssetTrack]
        do {
            (isPlayable, duration, tracks) = try await asset.load(.isPlayable, .duration, .tracks)
        } catch {
            throw Self.isMissingFile(url) ? MetadataError.unreadable : MetadataError.unsupportedFormat
        }
        guard isPlayable, tracks.contains(where: { $0.mediaType == .audio }) else {
            throw MetadataError.unsupportedFormat
        }

        let items = await Self.metadataItems(of: asset)
        let tags = Tags(items: items)
        var metadata = await TrackMetadata(
            title: tags.string(for: Self.titleIDs),
            artist: tags.string(for: Self.artistIDs),
            album: tags.string(for: Self.albumIDs),
            albumArtist: tags.string(for: Self.albumArtistIDs),
            trackNumber: tags.trackNumber(),
            duration: duration.isNumeric ? max(duration.seconds, 0) : 0,
            artworkData: tags.data(for: Self.artworkIDs)
        )
        if url.pathExtension.lowercased() == "flac", let flac = FLACMetadata(url: url) {
            Self.fill(&metadata, from: flac)
        }
        return metadata
    }

    /// Fills only the fields AVFoundation left empty.
    static func fill(_ metadata: inout TrackMetadata, from flac: FLACMetadata) {
        func comment(_ keys: String...) -> String? {
            keys.lazy.compactMap { flac.comments[$0]?.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty }
        }
        metadata.title = metadata.title ?? comment("TITLE")
        metadata.artist = metadata.artist ?? comment("ARTIST")
        metadata.album = metadata.album ?? comment("ALBUM")
        metadata.albumArtist = metadata.albumArtist ?? comment("ALBUMARTIST", "ALBUM ARTIST")
        metadata.trackNumber = metadata.trackNumber ?? comment("TRACKNUMBER")
            .flatMap { Int($0.split(separator: "/").first ?? "") }
            .flatMap { $0 > 0 ? $0 : nil }
        metadata.artworkData = metadata.artworkData ?? flac.pictureData
    }

    // MARK: - Identifiers, in priority order

    static let titleIDs: [AVMetadataIdentifier] = [.commonIdentifierTitle, .iTunesMetadataSongName, .id3MetadataTitleDescription, vorbis("TITLE")]
    static let artistIDs: [AVMetadataIdentifier] = [.commonIdentifierArtist, .iTunesMetadataArtist, .id3MetadataLeadPerformer, vorbis("ARTIST")]
    static let albumIDs: [AVMetadataIdentifier] = [.commonIdentifierAlbumName, .iTunesMetadataAlbum, .id3MetadataAlbumTitle, vorbis("ALBUM")]
    static let albumArtistIDs: [AVMetadataIdentifier] = [.iTunesMetadataAlbumArtist, .id3MetadataBand, vorbis("ALBUMARTIST"), vorbis("ALBUM ARTIST")]
    static let artworkIDs: [AVMetadataIdentifier] = [.commonIdentifierArtwork, .iTunesMetadataCoverArt, .id3MetadataAttachedPicture]
    static let trackNumberIDs: [AVMetadataIdentifier] = [.iTunesMetadataTrackNumber, .id3MetadataTrackNumber, vorbis("TRACKNUMBER")]

    /// FLAC/Ogg Vorbis comments have no predefined identifiers; AVFoundation reports them as `vorb/<KEY>`.
    static func vorbis(_ key: String) -> AVMetadataIdentifier {
        AVMetadataIdentifier(rawValue: "vorb/\(key)")
    }

    /// Common metadata plus every format-specific item (ID3, iTunes, QuickTime).
    private static func metadataItems(of asset: AVURLAsset) async -> [AVMetadataItem] {
        var items = await (try? asset.load(.commonMetadata)) ?? []
        let formats = await (try? asset.load(.availableMetadataFormats)) ?? []
        for format in formats {
            await items += (try? asset.loadMetadata(for: format)) ?? []
        }
        return items
    }

    private static func isMissingFile(_ url: URL) -> Bool {
        !FileManager.default.isReadableFile(atPath: url.path)
    }
}

/// Lookup over loaded metadata items.
private struct Tags {
    let items: [AVMetadataItem]

    private func items(for identifiers: [AVMetadataIdentifier]) -> [AVMetadataItem] {
        // Vorbis comment keys are case-insensitive.
        identifiers.flatMap { identifier in
            items.filter { $0.identifier?.rawValue.caseInsensitiveCompare(identifier.rawValue) == .orderedSame }
        }
    }

    func string(for identifiers: [AVMetadataIdentifier]) async -> String? {
        for item in items(for: identifiers) {
            let value = try? await item.load(.stringValue)
            if let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                return value
            }
        }
        return nil
    }

    func data(for identifiers: [AVMetadataIdentifier]) async -> Data? {
        for item in items(for: identifiers) {
            if let data = try? await item.load(.dataValue), !data.isEmpty {
                return data
            }
        }
        return nil
    }

    /// iTunes `trkn` is binary (big-endian track number at bytes 2–3); ID3 `TRCK` and Vorbis
    /// `TRACKNUMBER` are text like "3/12".
    func trackNumber() async -> Int? {
        for item in items(for: MetadataReader.trackNumberIDs) {
            if let number = try? await item.load(.numberValue), number.intValue > 0 {
                return number.intValue
            }
            if let text = try? await item.load(.stringValue),
               let number = Int(text.split(separator: "/").first?.trimmingCharacters(in: .whitespaces) ?? ""), number > 0 {
                return number
            }
            if let data = try? await item.load(.dataValue), data.count >= 4 {
                let number = Int(data[data.startIndex + 2]) << 8 | Int(data[data.startIndex + 3])
                if number > 0 {
                    return number
                }
            }
        }
        return nil
    }
}
