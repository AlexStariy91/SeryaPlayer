import CoreData
import Foundation

/// Bridges `NSFetchedResultsController` to an `AsyncStream`: one controller on its own private-queue
/// context per subscriber. The first element is the current state; the controller is torn down when
/// the stream terminates (cancellation or the consumer dropping the stream).
/// `@unchecked Sendable`: the controller and context are touched only inside `context.perform`;
/// the continuation is Sendable.
final class FetchedResultsObserver<Object: NSManagedObject, Value: Sendable>: NSObject, NSFetchedResultsControllerDelegate,
    @unchecked Sendable {
    private let context: NSManagedObjectContext
    private let request: NSFetchRequest<Object>
    private let transform: ([Object]) -> Value
    private let continuation: AsyncStream<Value>.Continuation
    private var controller: NSFetchedResultsController<Object>?

    private init(
        context: NSManagedObjectContext,
        request: NSFetchRequest<Object>,
        transform: @escaping ([Object]) -> Value,
        continuation: AsyncStream<Value>.Continuation
    ) {
        self.context = context
        self.request = request
        self.transform = transform
        self.continuation = continuation
    }

    /// `makeRequest` and `transform` run on the observation context's queue.
    static func stream(
        in persistence: PersistenceController,
        request makeRequest: @escaping @Sendable () -> NSFetchRequest<Object>,
        transform: @escaping @Sendable ([Object]) -> Value
    ) -> AsyncStream<Value> {
        // Subscribers only need the latest state, so older snapshots are dropped.
        let (stream, continuation) = AsyncStream.makeStream(of: Value.self, bufferingPolicy: .bufferingNewest(1))
        let context = persistence.newObservationContext()
        context.perform {
            let observer = FetchedResultsObserver(context: context, request: makeRequest(), transform: transform, continuation: continuation)
            continuation.onTermination = { _ in observer.stop() }
            observer.start()
        }
        return stream
    }

    private func start() {
        let controller = NSFetchedResultsController(fetchRequest: request, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
        controller.delegate = self
        self.controller = controller
        do {
            try controller.performFetch()
            publish()
        } catch {
            continuation.finish()
        }
    }

    private func stop() {
        context.perform { self.tearDown() }
    }

    private func tearDown() {
        controller?.delegate = nil
        controller = nil
    }

    private func publish() {
        guard let controller else { return }
        if case .terminated = continuation.yield(transform(controller.fetchedObjects ?? [])) {
            // The stream ended before `onTermination` was installed; break the retain cycle here.
            tearDown()
            continuation.onTermination = nil
        }
    }

    func controllerDidChangeContent(_: NSFetchedResultsController<any NSFetchRequestResult>) {
        publish()
    }
}
