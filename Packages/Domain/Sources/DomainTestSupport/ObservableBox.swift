import Foundation
import Synchronization

/// Thread-safe value with change streams: the building block of the in-memory repositories.
public final class ObservableBox<Value: Sendable>: Sendable {
    private struct State {
        var value: Value
        var continuations: [UUID: AsyncStream<Value>.Continuation] = [:]
    }

    private let state: Mutex<State>

    public init(_ value: Value) {
        state = Mutex(State(value: value))
    }

    public var value: Value {
        state.withLock { $0.value }
    }

    /// Mutates the value, notifies subscribers and returns the closure's result.
    @discardableResult
    public func mutate<T>(_ body: (inout Value) throws -> T) rethrows -> T {
        try state.withLock { state in
            let result = try body(&state.value)
            for continuation in state.continuations.values {
                continuation.yield(state.value)
            }
            return result
        }
    }

    /// A new stream per call: the current value first, then every change.
    public func stream() -> AsyncStream<Value> {
        AsyncStream { continuation in
            let id = UUID()
            state.withLock { state in
                continuation.yield(state.value)
                state.continuations[id] = continuation
            }
            continuation.onTermination = { [weak self] _ in
                self?.state.withLock { _ = $0.continuations.removeValue(forKey: id) }
            }
        }
    }
}
