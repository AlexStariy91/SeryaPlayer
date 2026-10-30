import DesignSystem
import SwiftUI

/// Mini player above the tab bar plus the full player presented from it with a zoom transition.
struct PlayerHostModifier<EqualizerSheet: View>: ViewModifier {
    @State private var viewModel: PlayerViewModel
    @State private var showsFullPlayer = false
    @Namespace private var namespace
    private let equalizerSheet: () -> EqualizerSheet

    private static var transitionID: String {
        "player"
    }

    init(viewModel: PlayerViewModel, equalizerSheet: @escaping () -> EqualizerSheet) {
        _viewModel = State(initialValue: viewModel)
        self.equalizerSheet = equalizerSheet
    }

    func body(content: Content) -> some View {
        content
            .miniPlayerHost(isVisible: viewModel.isQueued) {
                MiniPlayerView(viewModel: viewModel) { showsFullPlayer = true }
                    .matchedTransitionSource(id: Self.transitionID, in: namespace)
            }
            .fullScreenCover(isPresented: $showsFullPlayer) {
                FullPlayerView(viewModel: viewModel, equalizerSheet: equalizerSheet)
                    .navigationTransition(.zoom(sourceID: Self.transitionID, in: namespace))
            }
            .onChange(of: viewModel.isQueued) { _, isQueued in
                if !isQueued {
                    showsFullPlayer = false
                }
            }
            .task { await viewModel.observe() }
    }
}
