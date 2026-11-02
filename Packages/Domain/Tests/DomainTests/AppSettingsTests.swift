import Domain
import Foundation
import Testing

struct AppSettingsTests {
    @Test func decodesSettingsSavedBeforeTheVisualizerSetting() throws {
        let json = #"{"theme":"dark","accentColorID":"pink","librarySort":{"field":"title","ascending":true},"#
            + #""equalizer":{"isEnabled":true,"gains":[1,2,3,4,5,6,7,8,9,10],"preamp":-10}}"#
        let old = Data(json.utf8)

        let settings = try JSONDecoder().decode(AppSettings.self, from: old)

        #expect(settings.theme == .dark)
        #expect(settings.accentColorID == "pink")
        #expect(settings.equalizer.gains.last == 10)
        #expect(!settings.showsVisualizer)
    }

    @Test func roundTripsTheVisualizerSetting() throws {
        var settings = AppSettings()
        settings.showsVisualizer = true

        let decoded = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))

        #expect(decoded == settings)
    }
}
