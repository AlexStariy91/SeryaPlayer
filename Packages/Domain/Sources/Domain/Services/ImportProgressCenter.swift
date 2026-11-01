import Foundation

/// Broadcasts the progress of the import that is running, whoever started it (file picker, inbox,
/// "Open in…"). `nil` means no import is running. Pass one instance to every `ImportTracksUseCase`.
public final class ImportProgressCenter: @unchecked Sendable { // all state is guarded by `lock`
    private let lock = NSLock()
    private var current: ImportProgress?
    private var continuations: [UUID: AsyncStream<ImportProgress?>.Continuation] = [:]

    public init() {}

    /// The current value first, then every change; only the newest value is kept for a slow reader.
    public func updates() -> AsyncStream<ImportProgress?> {
        let id = UUID()
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            lock.withLock {
                continuation.yield(current)
                continuations[id] = continuation
            }
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                lock.withLock { _ = continuations.removeValue(forKey: id) }
            }
        }
    }

    public func report(_ progress: ImportProgress) {
        publish(progress)
    }

    public func finish() {
        publish(nil)
    }

    private func publish(_ value: ImportProgress?) {
        lock.withLock {
            current = value
            for continuation in continuations.values {
                continuation.yield(value)
            }
        }
    }
}
