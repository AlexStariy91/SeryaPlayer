import Domain
import Foundation
import MediaPlayer

/// Routes Lock Screen, Control Center, headphone and CarPlay commands to a `PlaybackControlling`.
@MainActor
public final class RemoteCommands {
    private let commandCenter: MPRemoteCommandCenter
    private weak var controller: (any PlaybackControlling)?
    private var registrations: [(command: MPRemoteCommand, target: Any)] = []

    public init(commandCenter: MPRemoteCommandCenter = .shared()) {
        self.commandCenter = commandCenter
    }

    /// Registers the handlers. The controller is held weakly.
    public func attach(to controller: any PlaybackControlling) {
        detach()
        self.controller = controller

        register(commandCenter.playCommand, Self.handler { [weak self] _, _ in
            guard let controller = self?.controller, !controller.snapshot.isPlaying else { return }
            controller.togglePlayPause()
        })
        register(commandCenter.pauseCommand, Self.handler { [weak self] _, _ in
            guard let controller = self?.controller, controller.snapshot.isPlaying else { return }
            controller.togglePlayPause()
        })
        register(commandCenter.togglePlayPauseCommand, Self.handler { [weak self] _, _ in
            self?.controller?.togglePlayPause()
        })
        register(commandCenter.nextTrackCommand, Self.handler { [weak self] _, _ in
            self?.controller?.next()
        })
        register(commandCenter.previousTrackCommand, Self.handler { [weak self] _, _ in
            self?.controller?.previous()
        })
        register(commandCenter.changePlaybackPositionCommand, Self.handler { [weak self] position, _ in
            guard let position else { return }
            self?.controller?.seek(to: position)
        })
        commandCenter.changePlaybackRateCommand.supportedPlaybackRates = PlaybackRate.options.map { NSNumber(value: $0) }
        register(commandCenter.changePlaybackRateCommand, Self.handler { [weak self] _, rate in
            guard let rate else { return }
            self?.controller?.setRate(rate)
        })
    }

    public func detach() {
        for registration in registrations {
            registration.command.removeTarget(registration.target)
            registration.command.isEnabled = false
        }
        registrations.removeAll()
        controller = nil
    }

    private func register(_ command: MPRemoteCommand, _ handler: @escaping @Sendable (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus) {
        command.isEnabled = true
        registrations.append((command, command.addTarget(handler: handler)))
    }

    /// Builds the handler outside the main actor (MediaPlayer may call it on any thread) and hops to
    /// the main actor for the action. The position and rate are extracted first because the event isn't Sendable.
    private nonisolated static func handler(
        _ action: @escaping @MainActor @Sendable (_ position: TimeInterval?, _ rate: Float?) -> Void
    ) -> @Sendable (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        { event in
            let position = (event as? MPChangePlaybackPositionCommandEvent)?.positionTime
            let rate = (event as? MPChangePlaybackRateCommandEvent)?.playbackRate
            if Thread.isMainThread {
                MainActor.assumeIsolated { action(position, rate) }
            } else {
                Task { @MainActor in action(position, rate) }
            }
            return .success
        }
    }
}
