import Foundation

/// Pure playback queue logic: no timers, audio or storage.
///
/// The contract was fixed in stage 0 so the Playback package can be built in parallel.
///
/// Invariant: while shuffle is off, `originalOrder == items`. While it is on, `originalOrder` holds
/// the order to restore and `items` the shuffled playback order. A track may occur in the queue
/// more than once, so while shuffled the engine also remembers, for every item, which position of
/// `originalOrder` it came from (`originalPositions`). That keeps the current occurrence current when
/// shuffle is turned off. The positions are not persisted: after `init(state:)` they are rebuilt by matching
/// duplicates in order of appearance, so after a relaunch the occurrence may differ for duplicated tracks.
public struct QueueEngine: Sendable {
    public private(set) var items: [Track.ID] = []
    public private(set) var originalOrder: [Track.ID] = []
    public private(set) var currentIndex: Int?
    public private(set) var isShuffled = false
    public var repeatMode: RepeatMode = .off

    /// While shuffled: `originalPositions[i]` is the index in `originalOrder` of `items[i]`. Empty otherwise.
    private var originalPositions: [Int] = []

    /// Threshold for "Previous": after this time the button restarts the current track.
    public static let restartThreshold: TimeInterval = 3

    public init() {}

    public init(state: PlaybackState) {
        items = state.queue
        originalOrder = state.originalQueue
        currentIndex = state.currentIndex
        isShuffled = state.isShuffled
        repeatMode = state.repeatMode
        if isShuffled {
            originalPositions = Self.matchPositions(items: items, originalOrder: originalOrder)
        }
    }

    private var hasPositions: Bool {
        !originalPositions.isEmpty && originalPositions.count == items.count
    }

    /// Index in `originalOrder` of the item at `index`: exact when tracked, else the first occurrence of its ID.
    private func originalPosition(ofItemAt index: Int) -> Int? {
        guard items.indices.contains(index) else { return nil }
        if hasPositions {
            return originalPositions[index]
        }
        return originalOrder.firstIndex(of: items[index])
    }

    /// Pairs each item with an unused position of the same ID in `originalOrder`, in order of appearance.
    /// Returns an empty array if `items` is not a permutation of `originalOrder`.
    private static func matchPositions(items: [Track.ID], originalOrder: [Track.ID]) -> [Int] {
        var free: [Track.ID: [Int]] = [:]
        for (position, id) in originalOrder.enumerated().reversed() {
            free[id, default: []].append(position)
        }
        var result: [Int] = []
        for id in items {
            guard let position = free[id]?.popLast() else { return [] }
            result.append(position)
        }
        return result
    }

    public static func == (lhs: QueueEngine, rhs: QueueEngine) -> Bool {
        lhs.items == rhs.items && lhs.originalOrder == rhs.originalOrder && lhs.currentIndex == rhs.currentIndex
            && lhs.isShuffled == rhs.isShuffled && lhs.repeatMode == rhs.repeatMode
    }

    public var current: Track.ID? {
        currentIndex.flatMap { items.indices.contains($0) ? items[$0] : nil }
    }

    public func state(position: TimeInterval) -> PlaybackState {
        PlaybackState(
            queue: items,
            originalQueue: originalOrder,
            currentIndex: currentIndex,
            position: position,
            isShuffled: isShuffled,
            repeatMode: repeatMode
        )
    }

    /// Sets a new queue. With `shuffled`, the selected track goes first (Fisher–Yates).
    public mutating func start(with ids: [Track.ID], at index: Int, shuffled: Bool, using rng: inout some RandomNumberGenerator) {
        originalOrder = ids
        items = ids
        isShuffled = false
        originalPositions = []
        currentIndex = ids.isEmpty ? nil : min(max(index, 0), ids.count - 1)
        if shuffled {
            setShuffle(true, using: &rng)
        }
    }

    /// Next track after a natural end (`userInitiated == false`) or a button press.
    /// Returns nil when the queue is over; the current index is left unchanged then.
    /// Repeat one repeats the track only on auto-advance; repeat all wraps around to the start.
    public mutating func advance(userInitiated: Bool) -> Track.ID? {
        guard let index = currentIndex, items.indices.contains(index) else { return nil }
        if !userInitiated, repeatMode == .one {
            return items[index]
        }
        if index + 1 < items.count {
            currentIndex = index + 1
        } else if repeatMode == .all {
            currentIndex = 0
        } else {
            return nil
        }
        return current
    }

    /// "Previous": past `restartThreshold`, returns the current track (restart it).
    /// Otherwise goes to the previous track; at the start it restarts the current one
    /// (or wraps to the last track with repeat all).
    public mutating func goBack(currentTime: TimeInterval) -> Track.ID? {
        guard let index = currentIndex, items.indices.contains(index) else { return nil }
        if currentTime > Self.restartThreshold {
            return items[index]
        }
        if index > 0 {
            currentIndex = index - 1
        } else if repeatMode == .all {
            currentIndex = items.count - 1
        }
        return current
    }

    /// Enabling: the current track goes first, the rest are shuffled.
    /// Disabling: restores the original order; the current track stays current.
    public mutating func setShuffle(_ enabled: Bool, using rng: inout some RandomNumberGenerator) {
        guard enabled != isShuffled else { return }
        isShuffled = enabled
        if enabled {
            originalOrder = items
            var order = Array(items.indices)
            if let index = currentIndex, items.indices.contains(index) {
                var rest = order
                let first = rest.remove(at: index)
                Self.fisherYates(&rest, using: &rng)
                order = [first] + rest
                currentIndex = 0
            } else {
                Self.fisherYates(&order, using: &rng)
            }
            items = order.map { originalOrder[$0] }
            originalPositions = order
        } else {
            let restoredIndex = currentIndex.flatMap { originalPosition(ofItemAt: $0) }
            items = originalOrder
            currentIndex = restoredIndex
            originalPositions = []
        }
    }

    /// Inserts right after the current track (Play Next).
    public mutating func insertNext(_ ids: [Track.ID]) {
        guard !ids.isEmpty else { return }
        let position = currentIndex.map { $0 + 1 } ?? items.count
        let tracked = hasPositions
        let originalPosition = currentIndex.flatMap { self.originalPosition(ofItemAt: $0) }.map { $0 + 1 } ?? originalOrder.count
        items.insert(contentsOf: ids, at: position)
        if isShuffled {
            originalOrder.insert(contentsOf: ids, at: originalPosition)
            if tracked {
                originalPositions = originalPositions.map { $0 >= originalPosition ? $0 + ids.count : $0 }
                originalPositions.insert(contentsOf: originalPosition ..< originalPosition + ids.count, at: min(position, originalPositions.count))
            }
        } else {
            originalOrder = items
        }
    }

    /// Adds to the end of the queue (Play Last).
    public mutating func append(_ ids: [Track.ID]) {
        guard !ids.isEmpty else { return }
        if hasPositions {
            originalPositions.append(contentsOf: originalOrder.count ..< originalOrder.count + ids.count)
        }
        items.append(contentsOf: ids)
        originalOrder.append(contentsOf: ids)
    }

    /// Same semantics as `Array.move(fromOffsets:toOffset:)`. The current track stays current.
    /// While shuffled only the playback order changes; `originalOrder` is untouched.
    public mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.filter { items.indices.contains($0) }
        guard !moving.isEmpty else { return }
        let destination = min(max(destination, 0), items.count)
        var order = Array(items.indices)
        let moved = moving.map { order[$0] }
        for offset in moving.reversed() {
            order.remove(at: offset)
        }
        let insertionPoint = destination - moving.filter { $0 < destination }.count
        order.insert(contentsOf: moved, at: insertionPoint)
        items = order.map { items[$0] }
        if hasPositions {
            originalPositions = order.map { originalPositions[$0] }
        }
        currentIndex = currentIndex.flatMap { order.firstIndex(of: $0) }
        if !isShuffled {
            originalOrder = items
        }
    }

    /// Removes items. If the current track is removed, the one after it becomes current
    /// (the first one with repeat all when it was last); with nothing left to play there is no current track.
    public mutating func remove(atOffsets offsets: IndexSet) {
        let removed = offsets.filter { items.indices.contains($0) }
        guard !removed.isEmpty else { return }
        let removedBeforeCurrent = currentIndex.map { index in removed.filter { $0 < index }.count } ?? 0
        let currentWasRemoved = currentIndex.map { removed.contains($0) } ?? false

        let removedPositions = removed.compactMap { originalPosition(ofItemAt: $0) }
        let tracked = hasPositions
        for offset in removed.reversed() {
            items.remove(at: offset)
        }
        if isShuffled {
            for position in removedPositions.sorted(by: >) {
                originalOrder.remove(at: position)
            }
            if tracked {
                for offset in removed.reversed() {
                    originalPositions.remove(at: offset)
                }
                originalPositions = originalPositions.map { position in
                    position - removedPositions.filter { $0 < position }.count
                }
            }
        } else {
            originalOrder = items
        }

        guard let index = currentIndex else { return }
        let shifted = index - removedBeforeCurrent
        if !currentWasRemoved {
            currentIndex = shifted
        } else if shifted < items.count {
            currentIndex = shifted
        } else {
            currentIndex = repeatMode == .all && !items.isEmpty ? 0 : nil
        }
    }

    /// Makes the item at `index` current. Out-of-range indices are ignored.
    public mutating func jump(to index: Int) {
        guard items.indices.contains(index) else { return }
        currentIndex = index
    }

    private static func fisherYates(_ array: inout [some Any], using rng: inout some RandomNumberGenerator) {
        guard array.count > 1 else { return }
        for i in stride(from: array.count - 1, to: 0, by: -1) {
            let j = Int.random(in: 0 ... i, using: &rng)
            array.swapAt(i, j)
        }
    }
}
