import AVFAudio
import Foundation
import os

/// Owns the `.playback` audio session and turns its notifications into events on the main actor.
///
/// Notifications are observed on `OperationQueue.main`, so handlers run on the main thread and use
/// `MainActor.assumeIsolated` instead of an extra async hop: a pause on headphone removal then
/// happens before the next render cycle, not after a task switch.
@MainActor
public final class AudioSessionManager {
    public enum Event: Sendable, Equatable {
        case interruptionBegan
        case interruptionEnded(shouldResume: Bool)
        /// The previous output device disappeared (headphones unplugged, Bluetooth disconnected).
        case routeRequiresPause
        /// `mediaserverd` restarted: every audio object is invalid and must be rebuilt.
        case mediaServicesReset
    }

    /// Set by the owner (the playback engine). Always called on the main actor.
    public var onEvent: ((Event) -> Void)?

    private let session: AVAudioSession
    private let center: NotificationCenter
    private var observers: NotificationObservers?
    private var isActive = false
    private let logger = Logger(subsystem: "com.starodub.SeryaPlayer", category: "AudioSession")

    public init(session: AVAudioSession = .sharedInstance(), center: NotificationCenter = .default) {
        self.session = session
        self.center = center
        observeNotifications()
    }

    /// Sets the `.playback` category. Long-form audio routing lets the system offer AirPlay 2 routes.
    public func configure() throws {
        try session.setCategory(.playback, mode: .default, policy: .longFormAudio)
    }

    /// Activates the session before playback starts. Cheap to call repeatedly.
    public func activate() throws {
        guard !isActive else { return }
        try session.setActive(true)
        isActive = true
    }

    private func observeNotifications() {
        let interruption = center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            let info = notification.userInfo
            let type = (info?[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap(AVAudioSession.InterruptionType.init)
            let options = (info?[AVAudioSessionInterruptionOptionKey] as? UInt).map(AVAudioSession.InterruptionOptions.init)
            MainActor.assumeIsolated {
                self?.handleInterruption(type: type, options: options ?? [])
            }
        }
        let route = center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            let reason = (notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt)
                .flatMap(AVAudioSession.RouteChangeReason.init)
            MainActor.assumeIsolated {
                self?.handleRouteChange(reason: reason)
            }
        }
        let reset = center.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: session,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleMediaServicesReset()
            }
        }
        observers = NotificationObservers(center: center, tokens: [interruption, route, reset])
    }

    private func handleInterruption(type: AVAudioSession.InterruptionType?, options: AVAudioSession.InterruptionOptions) {
        switch type {
        case .began:
            // The system has deactivated the session and stopped the engine.
            isActive = false
            onEvent?(.interruptionBegan)
        case .ended:
            onEvent?(.interruptionEnded(shouldResume: options.contains(.shouldResume)))
        case nil:
            break
        @unknown default:
            break
        }
    }

    private func handleRouteChange(reason: AVAudioSession.RouteChangeReason?) {
        guard reason == .oldDeviceUnavailable else { return }
        onEvent?(.routeRequiresPause)
    }

    private func handleMediaServicesReset() {
        logger.error("Media services were reset")
        isActive = false
        do {
            try configure()
        } catch {
            logger.error("Failed to reconfigure the audio session: \(error.localizedDescription)")
        }
        onEvent?(.mediaServicesReset)
    }
}

/// Removes block-based observers when released. A plain (non-isolated) class so its `deinit` can
/// touch the tokens, which a main-actor class's nonisolated `deinit` can't do in Swift 6.
final class NotificationObservers {
    private let center: NotificationCenter
    private let tokens: [any NSObjectProtocol]

    init(center: NotificationCenter, tokens: [any NSObjectProtocol]) {
        self.center = center
        self.tokens = tokens
    }

    deinit {
        tokens.forEach(center.removeObserver)
    }
}
