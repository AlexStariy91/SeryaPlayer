import SwiftUI

public enum PlayerFeature {
    /// Hosts the mini player and the full player. Attach it to the root `TabView`:
    ///
    /// ```swift
    /// TabView { … }
    ///     .modifier(PlayerFeature.host(dependencies: container) { EqualizerFeature.makeSheet(…) })
    /// ```
    ///
    /// The mini player is hidden while the queue is empty. Tapping it presents the full player with a
    /// zoom transition; the full player's EQ button presents `equalizerSheet()`.
    @MainActor
    public static func host(
        dependencies: some PlayerDependencies,
        @ViewBuilder equalizerSheet: @escaping () -> some View
    ) -> some ViewModifier {
        PlayerHostModifier(
            viewModel: PlayerViewModel(
                player: dependencies.player,
                artworkStore: dependencies.artworkStore,
                settingsRepository: dependencies.settingsRepository
            ),
            equalizerSheet: equalizerSheet
        )
    }
}
