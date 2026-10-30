@testable import DesignSystem
import Testing

struct AccentPaletteTests {
    @Test func idsAreUniqueAndStable() {
        let ids = AccentPalette.all.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(ids.first == "serya")
        #expect(AccentPalette.all.count >= 7)
    }

    @Test func unknownIdFallsBackToDefault() {
        #expect(AccentPalette.option(id: "nope").id == "serya")
        #expect(AccentPalette.option(id: "teal").id == "teal")
    }

    @Test(arguments: AccentPalette.all)
    func contrastAgainstLightBackground(option: AccentOption) {
        #expect(option.lightContrast >= 3, "\(option.id) light: \(option.lightContrast)")
    }

    @Test(arguments: AccentPalette.all)
    func contrastAgainstDarkBackground(option: AccentOption) {
        #expect(option.darkContrast >= 3, "\(option.id) dark: \(option.darkContrast)")
    }

    @Test func contrastMathMatchesWCAGReference() {
        #expect(abs(ContrastRatio.ratio(0x000000, 0xFFFFFF) - 21) < 0.001)
        #expect(abs(ContrastRatio.ratio(0xFFFFFF, 0xFFFFFF) - 1) < 0.001)
    }
}

extension AccentOption: CustomTestStringConvertible {
    public var testDescription: String {
        id
    }
}
