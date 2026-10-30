import CoreTransferable
import Domain
import Foundation
import UniformTypeIdentifiers

extension UTType {
    /// JSON file with user presets. Declared in the app's Info.plist (`UTExportedTypeDeclarations`), extension `seryaeq`.
    static let eqPresets = UTType(exportedAs: "com.seryaplayer.eq-presets", conformingTo: .json)
}

struct PresetFileError: Error {}

/// The on-disk format of exported presets. Only name, gains and preamp travel; IDs are regenerated on import.
struct PresetFile: Codable, Sendable, Equatable {
    struct Entry: Codable, Sendable, Equatable {
        var name: String
        var gains: [Float]
        var preamp: Float
    }

    static let currentVersion = 1

    var version = PresetFile.currentVersion
    var presets: [Entry]
    /// File name without extension, used when sharing.
    var fileName: String {
        presets.count == 1 ? presets[0].name : "SeryaPlayer Presets"
    }

    init(presets: [EQPreset]) {
        self.presets = presets.map { Entry(name: $0.name, gains: $0.gains, preamp: $0.preamp) }
    }

    func data() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// New user presets (fresh IDs, clamped gains). Entries with an empty name are skipped.
    static func presets(from data: Data) throws -> [EQPreset] {
        guard let file = try? JSONDecoder().decode(PresetFile.self, from: data), file.version == currentVersion else {
            throw PresetFileError()
        }
        let result = file.presets.compactMap { entry -> EQPreset? in
            let name = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            return EQPreset(name: name, gains: EqualizerMath.normalized(entry.gains), preamp: EqualizerMath.clamp(entry.preamp))
        }
        guard !result.isEmpty else { throw PresetFileError() }
        return result
    }
}

extension PresetFile: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .eqPresets) { file in
            let safeName = file.fileName.replacingOccurrences(of: "/", with: "-")
            let url = FileManager.default.temporaryDirectory.appending(path: "\(safeName).seryaeq")
            try file.data().write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}
