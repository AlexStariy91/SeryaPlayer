import Foundation

public enum EQBands {
    /// Center frequencies of the 10 bands, Hz.
    public static let frequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    public static let count = 10
    public static let gainRange: ClosedRange<Float> = -12 ... 12
}

public struct EQPreset: Identifiable, Hashable, Sendable, Codable {
    public typealias ID = UUID

    public let id: ID
    public var name: String
    /// Exactly `EQBands.count` values in dB.
    public var gains: [Float]
    public var preamp: Float
    public var isBuiltIn: Bool
    public var createdAt: Date

    public init(
        id: ID = UUID(),
        name: String,
        gains: [Float],
        preamp: Float = 0,
        isBuiltIn: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.gains = gains
        self.preamp = preamp
        self.isBuiltIn = isBuiltIn
        self.createdAt = createdAt
    }
}

/// Current equalizer settings applied to the engine.
public struct EQSettings: Sendable, Equatable, Codable {
    public var isEnabled: Bool
    public var gains: [Float]
    public var preamp: Float
    public var presetID: EQPreset.ID?

    public init(isEnabled: Bool = false, gains: [Float] = Array(repeating: 0, count: EQBands.count), preamp: Float = 0, presetID: EQPreset.ID? = nil) {
        self.isEnabled = isEnabled
        self.gains = gains
        self.preamp = preamp
        self.presetID = presetID
    }
}
