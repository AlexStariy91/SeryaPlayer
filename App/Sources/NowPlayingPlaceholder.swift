import SwiftUI
import UIKit

/// Cover shown on the Lock Screen and in Control Center for tracks without artwork.
/// Opaque, with fixed colours: the system draws it over its own blurred background, so semantic
/// (translucent, trait-dependent) fills would look broken there.
enum NowPlayingPlaceholder {
    static let image: UIImage = {
        let side: CGFloat = 600
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        let bounds = CGRect(x: 0, y: 0, width: side, height: side)
        return UIGraphicsImageRenderer(size: bounds.size, format: format).image { context in
            let colors = [UIColor(white: 0.62, alpha: 1).cgColor, UIColor(white: 0.36, alpha: 1).cgColor]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) {
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: .zero,
                    end: CGPoint(x: side, y: side),
                    options: []
                )
            }
            let configuration = UIImage.SymbolConfiguration(pointSize: side * 0.4, weight: .regular)
            guard let symbol = UIImage(systemName: "music.note", withConfiguration: configuration)?
                .withTintColor(UIColor(white: 0.96, alpha: 1), renderingMode: .alwaysOriginal)
            else { return }
            let size = symbol.size
            symbol.draw(in: CGRect(x: (side - size.width) / 2, y: (side - size.height) / 2, width: size.width, height: size.height))
        }
    }()
}
