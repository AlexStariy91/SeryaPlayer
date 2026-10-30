import Foundation

/// Minimal reader for FLAC metadata blocks: Vorbis comments and the front-cover PICTURE.
/// AVFoundation exposes FLAC Vorbis comments on macOS but not on iOS 18, so `MetadataReader`
/// falls back to this for `.flac` files.
struct FLACMetadata: Equatable {
    /// Upper-cased keys (Vorbis comment keys are case-insensitive); the first value wins.
    var comments: [String: String] = [:]
    var pictureData: Data?

    /// Stop reading metadata blocks past this offset; real-world tags and covers fit easily.
    static let maxMetadataLength = 16 * 1024 * 1024

    /// `nil` if the file is not FLAC or its metadata is malformed.
    init?(url: URL) {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard (try? handle.read(upToCount: 4)) == Data("fLaC".utf8) else { return nil }

        var consumed = 4
        var isLast = false
        while !isLast, consumed < Self.maxMetadataLength {
            guard let header = try? handle.read(upToCount: 4), header.count == 4 else { return nil }
            isLast = header[header.startIndex] & 0x80 != 0
            let type = header[header.startIndex] & 0x7F
            let length = Int(header[header.startIndex + 1]) << 16 | Int(header[header.startIndex + 2]) << 8 | Int(header[header.startIndex + 3])
            consumed += 4 + length
            switch type {
            case 4, 6:
                guard let body = try? handle.read(upToCount: length), body.count == length else { return nil }
                var reader = ByteReader(data: body)
                if type == 4 {
                    parseVorbisComments(&reader)
                } else {
                    parsePicture(&reader)
                }
            default:
                guard (try? handle.seek(toOffset: UInt64(consumed))) != nil else { return nil }
            }
        }
    }

    private mutating func parseVorbisComments(_ reader: inout ByteReader) {
        guard let vendorLength = reader.uint32LE(), reader.skip(Int(vendorLength)), let count = reader.uint32LE() else { return }
        for _ in 0 ..< count {
            guard let length = reader.uint32LE(), let bytes = reader.bytes(Int(length)) else { return }
            guard let comment = String(data: bytes, encoding: .utf8), let separator = comment.firstIndex(of: "=") else { continue }
            let key = comment[..<separator].uppercased()
            let value = String(comment[comment.index(after: separator)...])
            if comments[key] == nil {
                comments[key] = value
            }
        }
    }

    /// Prefers the front cover (type 3); otherwise keeps the first picture.
    private mutating func parsePicture(_ reader: inout ByteReader) {
        guard let pictureType = reader.uint32BE(),
              let mimeLength = reader.uint32BE(), reader.skip(Int(mimeLength)),
              let descriptionLength = reader.uint32BE(), reader.skip(Int(descriptionLength)),
              reader.skip(16), // width, height, depth, colors
              let dataLength = reader.uint32BE(), let data = reader.bytes(Int(dataLength)), !data.isEmpty
        else { return }
        if pictureData == nil || pictureType == 3 {
            pictureData = data
        }
    }
}

private struct ByteReader {
    let data: Data
    var offset = 0

    mutating func bytes(_ count: Int) -> Data? {
        guard (0 ... data.count - offset).contains(count) else { return nil }
        let start = data.startIndex + offset
        offset += count
        return data.subdata(in: start ..< start + count)
    }

    mutating func skip(_ count: Int) -> Bool {
        bytes(count) != nil
    }

    mutating func uint32LE() -> UInt32? {
        bytes(4).map { $0.reversed().reduce(0) { $0 << 8 | UInt32($1) } }
    }

    mutating func uint32BE() -> UInt32? {
        bytes(4).map { $0.reduce(0) { $0 << 8 | UInt32($1) } }
    }
}
