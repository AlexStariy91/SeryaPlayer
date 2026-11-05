import CoreGraphics
@testable import DesignSystem
import SwiftUI
import Testing

/// The Lock Screen placeholder is rendered from `NoArtworkCover`; it must come out opaque, dark and with a light note.
@MainActor
struct NoArtworkCoverTests {
    @Test func rendersDarkOpaqueCoverWithLightNote() throws {
        let side = 120
        let renderer = ImageRenderer(content: NoArtworkCover().frame(width: CGFloat(side), height: CGFloat(side)))
        renderer.scale = 1
        renderer.isOpaque = true
        let image = try #require(renderer.cgImage)
        let pixels = try Self.rgba(image)

        func brightness(x: Int, y: Int) -> Double {
            let index = (y * image.width + x) * 4
            return (Double(pixels[index]) + Double(pixels[index + 1]) + Double(pixels[index + 2])) / 3
        }

        let corners = [(2, 2), (image.width - 3, 2), (2, image.height - 3), (image.width - 3, image.height - 3)]
        for (x, y) in corners {
            #expect(brightness(x: x, y: y) < 80, "corner (\(x), \(y)) should be graphite")
        }
        let center = (0 ..< image.height).flatMap { y in (0 ..< image.width).map { brightness(x: $0, y: y) } }
        #expect(try #require(center.max()) > 140, "the note should be light")
        #expect(image.alphaInfo == .noneSkipLast || image.alphaInfo == .noneSkipFirst || image.alphaInfo == .none)
    }

    private static func rgba(_ image: CGImage) throws -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = try #require(CGContext(
            data: &pixels,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return pixels
    }
}
