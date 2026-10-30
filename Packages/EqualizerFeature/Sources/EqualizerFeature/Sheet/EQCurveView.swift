import DesignSystem
import Domain
import SwiftUI

/// The frequency-response curve. Dragging anywhere moves the band nearest to where the drag started.
struct EQCurveView: View {
    let gains: [Float]
    let isEnabled: Bool
    let onChange: (Int, Float) -> Void

    @State private var activeBand: Int?

    private let horizontalInset: CGFloat = 20
    private let topInset: CGFloat = 12
    private let bottomInset: CGFloat = 22

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                draw(in: &context, size: size)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(size: proxy.size))
        }
        .frame(minHeight: 150)
        .frame(maxWidth: .infinity)
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityElement()
        .accessibilityLabel(Text("Equalizer curve", bundle: .module))
        .accessibilityHint(Text("Use the band sliders to adjust gains", bundle: .module))
    }

    // MARK: - Geometry

    private func plot(for size: CGSize) -> CGRect {
        CGRect(
            x: horizontalInset,
            y: topInset,
            width: max(size.width - horizontalInset * 2, 1),
            height: max(size.height - topInset - bottomInset, 1)
        )
    }

    private func point(band: Int, gain: Float, in plot: CGRect) -> CGPoint {
        let ratio = Double(gain - EQBands.gainRange.lowerBound) / Double(EQBands.gainRange.upperBound - EQBands.gainRange.lowerBound)
        return CGPoint(
            x: plot.minX + plot.width * CGFloat(band) / CGFloat(EQBands.count - 1),
            y: plot.maxY - plot.height * CGFloat(ratio)
        )
    }

    private func gain(atY y: CGFloat, in plot: CGRect) -> Float {
        let ratio = Float(min(max((plot.maxY - y) / plot.height, 0), 1))
        let raw = EQBands.gainRange.lowerBound + ratio * (EQBands.gainRange.upperBound - EQBands.gainRange.lowerBound)
        let stepped = (raw * 2).rounded() / 2
        return abs(stepped) < 0.6 ? 0 : stepped
    }

    private func nearestBand(toX x: CGFloat, in plot: CGRect) -> Int {
        let position = (x - plot.minX) / plot.width * CGFloat(EQBands.count - 1)
        return min(max(Int(position.rounded()), 0), EQBands.count - 1)
    }

    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard isEnabled else { return }
                let plot = plot(for: size)
                let band = activeBand ?? nearestBand(toX: value.startLocation.x, in: plot)
                activeBand = band
                onChange(band, gain(atY: value.location.y, in: plot))
            }
            .onEnded { _ in activeBand = nil }
    }

    // MARK: - Drawing

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let plot = plot(for: size)
        drawGrid(in: &context, plot: plot)
        let points = gains.enumerated().map { point(band: $0.offset, gain: $0.element, in: plot) }
        guard points.count > 1 else { return }

        let curve = smoothPath(through: points)
        var fill = curve
        fill.addLine(to: CGPoint(x: points[points.count - 1].x, y: point(band: 0, gain: 0, in: plot).y))
        fill.addLine(to: CGPoint(x: points[0].x, y: point(band: 0, gain: 0, in: plot).y))
        fill.closeSubpath()
        context.fill(fill, with: .color(.accentColor.opacity(0.15)))
        context.stroke(curve, with: .color(.accentColor), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

        for (index, center) in points.enumerated() {
            let radius: CGFloat = index == activeBand ? 9 : 6
            let dot = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: dot), with: .color(.white))
            context.stroke(Path(ellipseIn: dot), with: .color(.accentColor), lineWidth: 2.5)
        }
    }

    private func drawGrid(in context: inout GraphicsContext, plot: CGRect) {
        let lineColor = Color.secondary.opacity(0.25)
        for gain in stride(from: Float(-12), through: 12, by: 6) {
            let y = point(band: 0, gain: gain, in: plot).y
            var line = Path()
            line.move(to: CGPoint(x: plot.minX, y: y))
            line.addLine(to: CGPoint(x: plot.maxX, y: y))
            let isZero = gain == 0
            context.stroke(
                line,
                with: .color(isZero ? Color.secondary.opacity(0.5) : lineColor),
                style: StrokeStyle(lineWidth: isZero ? 1.5 : 1, dash: isZero ? [] : [4, 4])
            )
        }
        for band in EQBands.frequencies.indices where band.isMultiple(of: 3) || band == EQBands.count - 1 {
            let x = point(band: band, gain: 0, in: plot).x
            let label = Text(Strings.frequency(EQBands.frequencies[band])).font(AppFont.caption).foregroundStyle(Color.secondary)
            context.draw(label, at: CGPoint(x: x, y: plot.maxY + 12), anchor: .center)
        }
    }

    /// Catmull-Rom spline converted to cubic Béziers.
    private func smoothPath(through points: [CGPoint]) -> Path {
        var path = Path()
        path.move(to: points[0])
        for index in 0 ..< points.count - 1 {
            let p0 = points[max(index - 1, 0)]
            let p1 = points[index]
            let p2 = points[index + 1]
            let p3 = points[min(index + 2, points.count - 1)]
            let control1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let control2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: control1, control2: control2)
        }
        return path
    }
}
