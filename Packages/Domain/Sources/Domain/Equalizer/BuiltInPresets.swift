import Foundation

/// The 16 built-in presets. They live in code, not in storage; IDs are fixed so that
/// `EQSettings.presetID` stays valid across launches.
/// Bands: 32, 64, 125, 250, 500, 1k, 2k, 4k, 8k, 16k Hz.
public enum BuiltInPresets {
    public static let all: [EQPreset] = definitions.enumerated().map { offset, definition in
        let gains = EqualizerMath.normalized(definition.gains)
        return EQPreset(
            id: UUID(uuidString: String(format: "5E7A0000-0000-4000-8000-%012d", offset + 1)) ?? UUID(),
            name: definition.name,
            gains: gains,
            preamp: EqualizerMath.autoPreamp(for: gains),
            isBuiltIn: true,
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }

    public static let flat = all[0]

    public static func preset(withID id: EQPreset.ID) -> EQPreset? {
        all.first { $0.id == id }
    }

    private static let definitions: [(name: String, gains: [Float])] = [
        ("Flat", [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
        ("Rock", [5, 4, 3, 1, -1, -1, 1, 3, 4, 5]),
        ("Pop", [-1, 1, 3, 4, 3, 0, -1, -1, 1, 2]),
        ("Dance", [6, 5, 3, 0, 0, -2, -3, -1, 3, 4]),
        ("Electronic", [5, 4, 1, 0, -2, 2, 1, 2, 4, 5]),
        ("Hip-Hop", [6, 5, 2, 3, -1, -1, 1, -1, 2, 3]),
        ("Jazz", [3, 2, 1, 2, -2, -2, 0, 1, 2, 3]),
        ("Classical", [4, 3, 2, 2, -1, -1, 0, 2, 3, 4]),
        ("Acoustic", [4, 4, 3, 1, 1, 1, 2, 3, 3, 2]),
        ("R&B", [3, 7, 6, 1, -2, -1, 2, 2, 3, 3]),
        ("Bass Booster", [7, 6, 5, 3, 1, 0, 0, 0, 0, 0]),
        ("Treble Booster", [0, 0, 0, 0, 0, 1, 3, 5, 6, 7]),
        ("Vocal", [-2, -3, -3, 1, 4, 4, 3, 1, 0, -1]),
        ("Loudness", [6, 4, 0, 0, -2, 0, -1, -5, 5, 1]),
        ("Late Night", [3, 2, 1, 0, 0, 0, -1, -2, -3, -4]),
        ("Spoken Word", [-3, -2, 0, 2, 4, 5, 5, 4, 2, 0]),
    ]
}
