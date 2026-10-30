import Domain
import Foundation
import Shared
import Synchronization

/// `AppSettings` as one JSON value in the App Group `UserDefaults`.
public final class UserDefaultsSettingsRepository: SettingsRepository {
    public static let defaultKey = "appSettings"

    // `nonisolated(unsafe)`: `UserDefaults` is documented as thread-safe but not annotated `Sendable`.
    private nonisolated(unsafe) let defaults: UserDefaults
    private let key: String
    private let subscribers = Mutex<[UUID: AsyncStream<AppSettings>.Continuation]>([:])

    /// - Parameter defaults: `AppGroup.userDefaults` (suite `AppGroup.id`) in the app; a throwaway suite in tests.
    public init(defaults: UserDefaults = AppGroup.userDefaults, key: String = UserDefaultsSettingsRepository.defaultKey) {
        self.defaults = defaults
        self.key = key
    }

    /// Defaults when nothing is stored or the stored value cannot be decoded.
    public func load() -> AppSettings {
        guard let data = defaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else {
            return AppSettings()
        }
        return settings
    }

    public func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
        let continuations = subscribers.withLock { Array($0.values) }
        for continuation in continuations {
            continuation.yield(settings)
        }
    }

    /// The current settings first, then every `save`.
    public func observe() -> AsyncStream<AppSettings> {
        let (stream, continuation) = AsyncStream.makeStream(of: AppSettings.self, bufferingPolicy: .bufferingNewest(1))
        let id = UUID()
        subscribers.withLock { $0[id] = continuation }
        continuation.onTermination = { [weak self] _ in
            _ = self?.subscribers.withLock { $0.removeValue(forKey: id) }
        }
        continuation.yield(load())
        return stream
    }
}
