import Domain
import Foundation
import Testing

struct EqualizerMathTests {
    @Test func clampsToTwelveDecibels() {
        #expect(EqualizerMath.clamp(20) == 12)
        #expect(EqualizerMath.clamp(-20) == -12)
        #expect(EqualizerMath.clamp(3.5) == 3.5)
    }

    @Test func normalizedPadsTruncatesAndClamps() {
        #expect(EqualizerMath.normalized([20, -20]) == [12, -12, 0, 0, 0, 0, 0, 0, 0, 0])
        #expect(EqualizerMath.normalized(Array(repeating: 1, count: 12)).count == EQBands.count)
        #expect(EqualizerMath.normalized([]) == Array(repeating: 0, count: EQBands.count))
    }

    @Test func autoPreampIsMinusLargestBoost() {
        #expect(EqualizerMath.autoPreamp(for: [0, 2, 6, -3, 0, 0, 0, 0, 0, 0]) == -6)
        #expect(EqualizerMath.autoPreamp(for: [30, 0]) == -12)
    }

    @Test func autoPreampIsZeroWithoutBoost() {
        #expect(EqualizerMath.autoPreamp(for: []) == 0)
        #expect(EqualizerMath.autoPreamp(for: [0, 0]) == 0)
        #expect(EqualizerMath.autoPreamp(for: [-4, -1]) == 0)
    }
}

struct BuiltInPresetsTests {
    @Test func hasSixteenPresetsWithExpectedNames() {
        #expect(BuiltInPresets.all.map(\.name) == [
            "Flat", "Rock", "Pop", "Dance", "Electronic", "Hip-Hop", "Jazz", "Classical",
            "Acoustic", "R&B", "Bass Booster", "Treble Booster", "Vocal", "Loudness", "Late Night", "Spoken Word",
        ])
    }

    @Test func idsAreUniqueAndStable() {
        #expect(Set(BuiltInPresets.all.map(\.id)).count == 16)
        #expect(BuiltInPresets.all.map(\.id) == BuiltInPresets.all.map(\.id))
        #expect(BuiltInPresets.all[0].id.uuidString == "5E7A0000-0000-4000-8000-000000000001")
        #expect(BuiltInPresets.all[15].id.uuidString == "5E7A0000-0000-4000-8000-000000000016")
    }

    @Test func curvesAreValid() {
        for preset in BuiltInPresets.all {
            #expect(preset.isBuiltIn)
            #expect(preset.gains.count == EQBands.count)
            #expect(preset.gains.allSatisfy { EQBands.gainRange.contains($0) })
            #expect(preset.preamp == EqualizerMath.autoPreamp(for: preset.gains))
        }
    }

    @Test func flatIsFlat() {
        #expect(BuiltInPresets.flat.gains.allSatisfy { $0 == 0 })
        #expect(BuiltInPresets.flat.preamp == 0)
    }

    @Test func lookupByID() {
        let rock = BuiltInPresets.all[1]
        #expect(BuiltInPresets.preset(withID: rock.id)?.name == "Rock")
        #expect(BuiltInPresets.preset(withID: UUID()) == nil)
    }

    @Test func bassBoosterBoostsLowsTrebleBoosterBoostsHighs() {
        let bass = BuiltInPresets.all[10].gains
        let treble = BuiltInPresets.all[11].gains
        #expect(bass[0] > bass[9])
        #expect(treble[9] > treble[0])
    }
}
