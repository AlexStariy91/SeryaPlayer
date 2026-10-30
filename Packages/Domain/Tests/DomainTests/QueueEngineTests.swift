@testable import Domain
import DomainTestSupport
import Foundation
import Testing

private func ids(_ count: Int) -> [Track.ID] {
    (0 ..< count).map { _ in UUID() }
}

private func engine(_ queue: [Track.ID], at index: Int = 0, shuffled: Bool = false, repeatMode: RepeatMode = .off) -> QueueEngine {
    var rng = SeededGenerator(seed: 1)
    var engine = QueueEngine()
    engine.start(with: queue, at: index, shuffled: shuffled, using: &rng)
    engine.repeatMode = repeatMode
    return engine
}

struct QueueStartTests {
    @Test func startSetsQueueAndCurrent() {
        let q = ids(4)
        let e = engine(q, at: 2)
        #expect(e.items == q)
        #expect(e.originalOrder == q)
        #expect(e.current == q[2])
        #expect(!e.isShuffled)
    }

    @Test func startClampsIndex() {
        let q = ids(3)
        #expect(engine(q, at: 99).currentIndex == 2)
        #expect(engine(q, at: -5).currentIndex == 0)
    }

    @Test func emptyQueue() {
        var e = engine([])
        #expect(e.current == nil)
        #expect(e.advance(userInitiated: true) == nil)
        #expect(e.advance(userInitiated: false) == nil)
        #expect(e.goBack(currentTime: 0) == nil)
        e.jump(to: 0)
        e.remove(atOffsets: [0])
        e.move(fromOffsets: [0], toOffset: 1)
        var rng = SeededGenerator(seed: 1)
        e.setShuffle(true, using: &rng)
        #expect(e.items.isEmpty)
        #expect(e.currentIndex == nil)
    }

    @Test func startShuffledPutsSelectedFirstAndKeepsOriginal() {
        let q = ids(20)
        let e = engine(q, at: 7, shuffled: true)
        #expect(e.isShuffled)
        #expect(e.current == q[7])
        #expect(e.currentIndex == 0)
        #expect(e.items.first == q[7])
        #expect(Set(e.items) == Set(q))
        #expect(e.items.count == q.count)
        #expect(e.originalOrder == q)
        #expect(e.items != q)
    }

    @Test func shuffleIsDeterministicForSeed() {
        let q = ids(10)
        #expect(engine(q, at: 0, shuffled: true).items == engine(q, at: 0, shuffled: true).items)
    }

    @Test func restoreFromState() {
        let q = ids(3)
        var e = engine(q, at: 1, repeatMode: .all)
        _ = e.advance(userInitiated: true)
        let restored = QueueEngine(state: e.state(position: 12))
        #expect(restored == e)
    }
}

struct QueueNavigationTests {
    @Test func advanceMovesForwardThenEnds() {
        let q = ids(3)
        var e = engine(q)
        #expect(e.advance(userInitiated: false) == q[1])
        #expect(e.advance(userInitiated: true) == q[2])
        #expect(e.advance(userInitiated: false) == nil)
        #expect(e.current == q[2])
    }

    @Test func repeatAllWraps() {
        let q = ids(2)
        var e = engine(q, at: 1, repeatMode: .all)
        #expect(e.advance(userInitiated: false) == q[0])
        #expect(e.currentIndex == 0)
    }

    @Test func repeatOneRepeatsOnAutoAdvanceOnly() {
        let q = ids(3)
        var e = engine(q, at: 0, repeatMode: .one)
        #expect(e.advance(userInitiated: false) == q[0])
        #expect(e.currentIndex == 0)
        #expect(e.advance(userInitiated: true) == q[1])
    }

    @Test func repeatOneAtEndWithButtonStops() {
        let q = ids(2)
        var e = engine(q, at: 1, repeatMode: .one)
        #expect(e.advance(userInitiated: true) == nil)
    }

    @Test func goBackAfterThresholdRestartsCurrent() {
        let q = ids(3)
        var e = engine(q, at: 1)
        #expect(e.goBack(currentTime: 3.1) == q[1])
        #expect(e.currentIndex == 1)
    }

    @Test func goBackWithinThresholdGoesToPrevious() {
        let q = ids(3)
        var e = engine(q, at: 2)
        #expect(e.goBack(currentTime: 3) == q[1])
        #expect(e.goBack(currentTime: 0) == q[0])
    }

    @Test func goBackAtStartRestartsCurrent() {
        let q = ids(3)
        var e = engine(q, at: 0)
        #expect(e.goBack(currentTime: 1) == q[0])
        #expect(e.currentIndex == 0)
    }

    @Test func goBackAtStartWrapsWithRepeatAll() {
        let q = ids(3)
        var e = engine(q, at: 0, repeatMode: .all)
        #expect(e.goBack(currentTime: 1) == q[2])
    }

    @Test func jumpSetsCurrentAndIgnoresInvalid() {
        let q = ids(4)
        var e = engine(q)
        e.jump(to: 3)
        #expect(e.current == q[3])
        e.jump(to: 10)
        e.jump(to: -1)
        #expect(e.current == q[3])
    }
}

struct QueueShuffleTests {
    @Test func enablingKeepsCurrentFirstAndOriginal() {
        let q = ids(15)
        var e = engine(q, at: 4)
        var rng = SeededGenerator(seed: 42)
        e.setShuffle(true, using: &rng)
        #expect(e.isShuffled)
        #expect(e.current == q[4])
        #expect(e.currentIndex == 0)
        #expect(e.originalOrder == q)
        #expect(Set(e.items) == Set(q))
    }

    @Test func disablingRestoresOrderAndKeepsCurrent() {
        let q = ids(15)
        var e = engine(q, at: 4)
        var rng = SeededGenerator(seed: 42)
        e.setShuffle(true, using: &rng)
        _ = e.advance(userInitiated: true)
        let playing = e.current
        e.setShuffle(false, using: &rng)
        #expect(!e.isShuffled)
        #expect(e.items == q)
        #expect(e.originalOrder == q)
        #expect(e.current == playing)
    }

    @Test func settingSameValueIsNoOp() {
        let q = ids(5)
        var e = engine(q)
        var rng = SeededGenerator(seed: 1)
        e.setShuffle(false, using: &rng)
        #expect(e.items == q)
        e.setShuffle(true, using: &rng)
        let shuffled = e.items
        e.setShuffle(true, using: &rng)
        #expect(e.items == shuffled)
    }

    @Test func singleItemShuffle() {
        let q = ids(1)
        var e = engine(q)
        var rng = SeededGenerator(seed: 1)
        e.setShuffle(true, using: &rng)
        #expect(e.items == q)
        #expect(e.current == q[0])
    }

    @Test func fisherYatesIsUnbiasedEnough() {
        // Over many seeds each of the 3 remaining tracks lands in position 1 about a third of the time.
        let q = ids(4)
        var counts: [Track.ID: Int] = [:]
        for seed in 0 ..< 600 {
            var e = engine(q)
            var rng = SeededGenerator(seed: UInt64(seed))
            e.setShuffle(true, using: &rng)
            counts[e.items[1], default: 0] += 1
        }
        #expect(counts.count == 3)
        #expect(counts.values.allSatisfy { $0 > 140 && $0 < 260 })
    }
}

struct QueueEditingTests {
    @Test func insertNextGoesAfterCurrent() {
        let q = ids(3)
        let extra = ids(2)
        var e = engine(q, at: 1)
        e.insertNext(extra)
        #expect(e.items == [q[0], q[1], extra[0], extra[1], q[2]])
        #expect(e.current == q[1])
        #expect(e.originalOrder == e.items)
    }

    @Test func insertNextOnEmptyQueue() {
        var e = engine([])
        let extra = ids(2)
        e.insertNext(extra)
        #expect(e.items == extra)
        #expect(e.originalOrder == extra)
    }

    @Test func appendGoesToEnd() {
        let q = ids(2)
        let extra = ids(2)
        var e = engine(q)
        e.append(extra)
        #expect(e.items == q + extra)
        #expect(e.originalOrder == q + extra)
    }

    @Test func insertNextWhileShuffledUpdatesOriginalAfterCurrent() {
        let q = ids(6)
        let extra = ids(1)
        var e = engine(q, at: 2, shuffled: true)
        e.insertNext(extra)
        #expect(e.items[1] == extra[0])
        #expect(e.originalOrder == [q[0], q[1], q[2], extra[0], q[3], q[4], q[5]])
        var rng = SeededGenerator(seed: 3)
        e.setShuffle(false, using: &rng)
        #expect(e.items == [q[0], q[1], q[2], extra[0], q[3], q[4], q[5]])
        #expect(e.current == q[2])
    }

    @Test func appendWhileShuffledSurvivesUnshuffle() {
        let q = ids(5)
        let extra = ids(2)
        var e = engine(q, at: 0, shuffled: true)
        e.append(extra)
        #expect(e.items.suffix(2) == extra[...])
        var rng = SeededGenerator(seed: 3)
        e.setShuffle(false, using: &rng)
        #expect(e.items == q + extra)
    }

    @Test func moveForwardKeepsCurrent() {
        let q = ids(5)
        var e = engine(q, at: 1)
        e.move(fromOffsets: [0], toOffset: 3)
        #expect(e.items == [q[1], q[2], q[0], q[3], q[4]])
        #expect(e.current == q[1])
        #expect(e.originalOrder == e.items)
    }

    @Test func moveBackwardKeepsCurrent() {
        let q = ids(5)
        var e = engine(q, at: 3)
        e.move(fromOffsets: [4], toOffset: 0)
        #expect(e.items == [q[4], q[0], q[1], q[2], q[3]])
        #expect(e.current == q[3])
    }

    @Test func moveCurrentTrack() {
        let q = ids(4)
        var e = engine(q, at: 0)
        e.move(fromOffsets: [0], toOffset: 4)
        #expect(e.items == [q[1], q[2], q[3], q[0]])
        #expect(e.current == q[0])
        #expect(e.currentIndex == 3)
    }

    @Test func moveMultipleOffsets() {
        let q = ids(5)
        var e = engine(q, at: 4)
        e.move(fromOffsets: [0, 1], toOffset: 4)
        #expect(e.items == [q[2], q[3], q[0], q[1], q[4]])
        #expect(e.current == q[4])
    }

    @Test func moveWhileShuffledLeavesOriginal() {
        let q = ids(6)
        var e = engine(q, at: 0, shuffled: true)
        let first = e.items[1]
        e.move(fromOffsets: [1], toOffset: 4)
        #expect(e.items[3] == first)
        #expect(e.originalOrder == q)
    }

    @Test func removeBeforeCurrentShiftsIndex() {
        let q = ids(5)
        var e = engine(q, at: 3)
        e.remove(atOffsets: [0, 1])
        #expect(e.items == [q[2], q[3], q[4]])
        #expect(e.current == q[3])
        #expect(e.originalOrder == e.items)
    }

    @Test func removeAfterCurrentKeepsIndex() {
        let q = ids(5)
        var e = engine(q, at: 1)
        e.remove(atOffsets: [3, 4])
        #expect(e.currentIndex == 1)
        #expect(e.current == q[1])
    }

    @Test func removeCurrentSelectsFollowing() {
        let q = ids(4)
        var e = engine(q, at: 1)
        e.remove(atOffsets: [1])
        #expect(e.items == [q[0], q[2], q[3]])
        #expect(e.current == q[2])
    }

    @Test func removeCurrentLastEndsQueue() {
        let q = ids(3)
        var e = engine(q, at: 2)
        e.remove(atOffsets: [2])
        #expect(e.current == nil)
        #expect(e.advance(userInitiated: false) == nil)
        #expect(e.items == [q[0], q[1]])
    }

    @Test func removeCurrentLastWrapsWithRepeatAll() {
        let q = ids(3)
        var e = engine(q, at: 2, repeatMode: .all)
        e.remove(atOffsets: [2])
        #expect(e.current == q[0])
    }

    @Test func removeEverything() {
        let q = ids(3)
        var e = engine(q, at: 1)
        e.remove(atOffsets: [0, 1, 2])
        #expect(e.items.isEmpty)
        #expect(e.current == nil)
    }

    @Test func removeIgnoresOutOfRange() {
        let q = ids(2)
        var e = engine(q)
        e.remove(atOffsets: [5])
        #expect(e.items == q)
    }

    @Test func removeWhileShuffledUpdatesOriginal() {
        let q = ids(6)
        var e = engine(q, at: 2, shuffled: true)
        let victim = e.items[3]
        e.remove(atOffsets: [3])
        #expect(!e.items.contains(victim))
        #expect(e.originalOrder == q.filter { $0 != victim })
        #expect(e.current == q[2])
        var rng = SeededGenerator(seed: 3)
        e.setShuffle(false, using: &rng)
        #expect(e.items == q.filter { $0 != victim })
        #expect(e.current == q[2])
    }

    @Test func removeCurrentWhileShuffledThenUnshuffle() {
        let q = ids(5)
        var e = engine(q, at: 2, shuffled: true)
        let next = e.items[1]
        e.remove(atOffsets: [0])
        #expect(e.current == next)
        #expect(e.originalOrder == q.filter { $0 != q[2] })
        var rng = SeededGenerator(seed: 3)
        e.setShuffle(false, using: &rng)
        #expect(e.items == q.filter { $0 != q[2] })
        #expect(e.current == next)
    }
}
