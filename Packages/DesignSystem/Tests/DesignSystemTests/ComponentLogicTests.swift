import CoreGraphics
@testable import DesignSystem
import SwiftUI
import Testing
import UIKit

struct ComponentLogicTests {
    private struct RGB {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
    }

    private struct Fill {
        let red: UInt8
        let green: UInt8
        let blue: UInt8
    }

    @Test func clockFormatting() {
        #expect(TimeFormat.clock(0) == "0:00")
        #expect(TimeFormat.clock(-5) == "0:00")
        #expect(TimeFormat.clock(.nan) == "0:00")
        #expect(TimeFormat.clock(65.9) == "1:05")
        #expect(TimeFormat.clock(3725) == "1:02:05")
    }

    @Test func gainSnapsToZeroAndHalfDecibels() {
        let range = -12.0 ... 12.0
        #expect(VerticalGainSlider.snap(0.4, range: range) == 0)
        #expect(VerticalGainSlider.snap(-0.5, range: range) == 0)
        #expect(VerticalGainSlider.snap(3.3, range: range) == 3.5)
        #expect(VerticalGainSlider.snap(99, range: range) == 12)
        #expect(VerticalGainSlider.snap(-99, range: range) == -12)
    }

    @Test func gainFormatting() {
        #expect(VerticalGainSlider.format(0) == "0 dB")
        #expect(VerticalGainSlider.format(3) == "+3.0 dB")
        #expect(VerticalGainSlider.format(-4.5) == "-4.5 dB")
    }

    @Test func artworkSizes() {
        #expect(ArtworkSize.row.points == 48)
        #expect(ArtworkSize.custom(100).points == 100)
    }

    @Test func dominantColorsFindsBothHalves() throws {
        let image = try #require(Self.makeImage(left: Fill(red: 230, green: 20, blue: 20), right: Fill(red: 20, green: 40, blue: 230)))
        let colors = DominantColors.extract(from: image, count: 4)
        #expect(colors.count == 2)
        let components = colors.map { color -> RGB in
            var rgb = RGB()
            UIColor(color).getRed(&rgb.red, green: &rgb.green, blue: &rgb.blue, alpha: nil)
            return rgb
        }
        #expect(components.contains { $0.red > 0.8 && $0.blue < 0.2 })
        #expect(components.contains { $0.blue > 0.8 && $0.red < 0.2 })
    }

    @Test func dominantColorsRespectsCount() throws {
        let image = try #require(Self.makeImage(left: Fill(red: 230, green: 20, blue: 20), right: Fill(red: 20, green: 40, blue: 230)))
        #expect(DominantColors.extract(from: image, count: 1).count == 1)
    }

    @Test func artworkCacheDecodesAndCaches() async throws {
        let image = try #require(Self.makeImage(left: Fill(red: 10, green: 200, blue: 10), right: Fill(red: 10, green: 200, blue: 10)))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("artwork-\(UUID().uuidString).png")
        let data = try #require(UIImage(cgImage: image).pngData())
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(ArtworkCache.shared.cached(url, maxPixel: 32) == nil)
        let decoded = await ArtworkCache.shared.image(for: url, maxPixel: 32)
        #expect(decoded != nil)
        #expect(ArtworkCache.shared.cached(url, maxPixel: 32) != nil)
        #expect(await ArtworkCache.shared.image(for: URL(fileURLWithPath: "/nonexistent.png"), maxPixel: 32) == nil)
    }

    private static func makeImage(left: Fill, right: Fill) -> CGImage? {
        let side = 64
        guard let context = CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.setFillColor(red: CGFloat(left.red) / 255, green: CGFloat(left.green) / 255, blue: CGFloat(left.blue) / 255, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: side / 2, height: side))
        context.setFillColor(red: CGFloat(right.red) / 255, green: CGFloat(right.green) / 255, blue: CGFloat(right.blue) / 255, alpha: 1)
        context.fill(CGRect(x: side / 2, y: 0, width: side / 2, height: side))
        return context.makeImage()
    }
}
