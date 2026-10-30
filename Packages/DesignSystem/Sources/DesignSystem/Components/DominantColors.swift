import CoreGraphics
import SwiftUI

/// Extracts a palette of dominant colors from an image (for the player background).
public enum DominantColors {
    private struct RGB {
        var red: Double
        var green: Double
        var blue: Double
    }

    /// Up to `count` visually distinct colors, most prominent first. Empty if the image can't be read.
    public static func extract(from image: CGImage, count: Int = 4) -> [Color] {
        guard let pixels = downsample(image, side: 40) else { return [] }
        struct Bucket {
            var red = 0, green = 0, blue = 0, count = 0
        }
        var buckets: [Int: Bucket] = [:]
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let red = Int(pixels[index]), green = Int(pixels[index + 1]), blue = Int(pixels[index + 2])
            guard pixels[index + 3] > 127 else { continue }
            // 4 bits per channel.
            let key = (red >> 4) << 8 | (green >> 4) << 4 | (blue >> 4)
            var bucket = buckets[key, default: Bucket()]
            bucket.red += red
            bucket.green += green
            bucket.blue += blue
            bucket.count += 1
            buckets[key] = bucket
        }

        // Favor saturated, mid-brightness colors over near-white and near-black.
        let scored = buckets.values.map { bucket -> (rgb: RGB, score: Double) in
            let red = Double(bucket.red) / Double(bucket.count) / 255
            let green = Double(bucket.green) / Double(bucket.count) / 255
            let blue = Double(bucket.blue) / Double(bucket.count) / 255
            let maxChannel = max(red, green, blue), minChannel = min(red, green, blue)
            let saturation = maxChannel == 0 ? 0 : (maxChannel - minChannel) / maxChannel
            let brightnessPenalty = (maxChannel < 0.15 || minChannel > 0.92) ? 0.15 : 1
            return (RGB(red: red, green: green, blue: blue), Double(bucket.count) * (0.3 + saturation) * brightnessPenalty)
        }.sorted { $0.score > $1.score }

        var picked: [RGB] = []
        for candidate in scored {
            let far = picked.allSatisfy { distance($0, candidate.rgb) > 0.25 }
            if far {
                picked.append(candidate.rgb)
            }
            if picked.count == count {
                break
            }
        }
        return picked.map { Color(red: $0.red, green: $0.green, blue: $0.blue) }
    }

    private static func distance(_ lhs: RGB, _ rhs: RGB) -> Double {
        let dr = lhs.red - rhs.red, dg = lhs.green - rhs.green, db = lhs.blue - rhs.blue
        return (dr * dr + dg * dg + db * db).squareRoot()
    }

    /// RGBA8 pixels of the image scaled to `side` × `side`.
    private static func downsample(_ image: CGImage, side: Int) -> [UInt8]? {
        var data = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = data.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: side,
                height: side,
                bitsPerComponent: 8,
                bytesPerRow: side * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .low
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        return drawn ? data : nil
    }
}
