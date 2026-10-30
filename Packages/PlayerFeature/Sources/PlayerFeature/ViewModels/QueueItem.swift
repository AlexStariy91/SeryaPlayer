import Domain

/// A queue position. A track may be queued more than once, so identity includes the index.
struct QueueItem: Identifiable, Hashable {
    let index: Int
    let track: Track

    var id: String {
        "\(index)-\(track.id)"
    }
}
