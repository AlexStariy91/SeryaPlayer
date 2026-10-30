import SwiftUI

/// An empty list / screen state with an optional action button. Wraps `ContentUnavailableView`.
public struct EmptyStateView: View {
    private let title: LocalizedStringKey
    private let systemImage: String
    private let message: LocalizedStringKey?
    private let actionTitle: LocalizedStringKey?
    private let action: (() -> Void)?

    public init(
        _ title: LocalizedStringKey,
        systemImage: String,
        message: LocalizedStringKey? = nil,
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            if let message {
                Text(message)
            }
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview("Empty state") {
    EmptyStateView("No Music Yet", systemImage: "music.note.house", message: "Import audio files to get started.", actionTitle: "Import Files") {}
}
