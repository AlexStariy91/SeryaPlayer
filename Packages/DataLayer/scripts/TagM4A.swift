// Copies an M4A with iTunes tags and artwork: swift TagM4A.swift <input.m4a> <cover.png> <output.m4a>
import AVFoundation

let arguments = CommandLine.arguments
let input = URL(fileURLWithPath: arguments[1])
let cover = try Data(contentsOf: URL(fileURLWithPath: arguments[2]))
let output = URL(fileURLWithPath: arguments[3])
try? FileManager.default.removeItem(at: output)

func item(_ identifier: AVMetadataIdentifier, _ value: NSCopying & NSObjectProtocol, dataType: CFString? = nil) -> AVMetadataItem {
    let item = AVMutableMetadataItem()
    item.identifier = identifier
    item.value = value
    if let dataType {
        item.dataType = dataType as String
    }
    return item
}

let session = AVAssetExportSession(asset: AVURLAsset(url: input), presetName: AVAssetExportPresetPassthrough)!
session.metadata = [
    item(.iTunesMetadataSongName, "Тестовая песня" as NSString),
    item(.iTunesMetadataArtist, "Fixture Artist" as NSString),
    item(.iTunesMetadataAlbum, "Fixture Album" as NSString),
    item(.iTunesMetadataAlbumArtist, "Fixture Band" as NSString),
    item(.iTunesMetadataTrackNumber, Data([0, 0, 0, 3, 0, 12, 0, 0]) as NSData, dataType: kCMMetadataBaseDataType_RawData),
    item(.iTunesMetadataCoverArt, cover as NSData, dataType: kCMMetadataBaseDataType_PNG),
]
try await session.export(to: output, as: .m4a)
