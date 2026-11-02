import Foundation

/// Display smoothing for band levels: bars jump up quickly with a hit and fall back slowly, so they
/// follow the music instead of flickering with every analysis window.
struct SpectrumSmoother {
    /// Time constants: how long a bar takes to cover ~63% of the way to its target.
    static let attack = 0.03
    static let decay = 0.16
    /// Below this, a level counts as silent.
    static let settledLevel: Float = 0.01

    private(set) var values: [Float]

    init(bandCount: Int) {
        values = Array(repeating: 0, count: bandCount)
    }

    /// True when every value is (near) zero.
    var isSettled: Bool {
        values.allSatisfy { $0 < Self.settledLevel }
    }

    /// Moves every value toward its target for `elapsed` seconds. Returns whether anything visibly moved.
    @discardableResult
    mutating func step(toward targets: [Float], elapsed: Double) -> Bool {
        let rise = Float(1 - exp(-elapsed / Self.attack))
        let fall = Float(1 - exp(-elapsed / Self.decay))
        var moved = false
        for index in values.indices {
            let target = index < targets.count ? targets[index] : 0
            let current = values[index]
            var next = current + (target - current) * (target > current ? rise : fall)
            if next < Self.settledLevel, target < Self.settledLevel {
                next = 0
            }
            if abs(next - current) > 0.0005 {
                moved = true
            }
            values[index] = next
        }
        return moved
    }
}
