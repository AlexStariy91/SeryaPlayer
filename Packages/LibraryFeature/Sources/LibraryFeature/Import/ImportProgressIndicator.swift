import DesignSystem
import Domain
import SwiftUI

/// A small progress ring in the navigation bar while an import runs (the way Files and Safari show
/// downloads). Tapping it opens a popover with the counts. Leaves the title area to the system.
struct ImportProgressIndicator: View {
    let progress: ImportProgress
    /// Called when the popover has appeared / is completely gone, so the owner can keep this view in the bar
    /// until then.
    var onDetailsAppear: () -> Void = {}
    var onDetailsDisappear: () -> Void = {}
    /// The popover is dismissed as soon as this turns false (the import finished).
    var isActive = true
    @State private var isShowingDetails = false

    var body: some View {
        Button {
            isShowingDetails = true
        } label: {
            ring
                .frame(width: 22, height: 22)
        }
        .popover(isPresented: Binding(get: { isShowingDetails && isActive }, set: { isShowingDetails = $0 })) {
            details
                .presentationCompactAdaptation(.popover)
                .onAppear(perform: onDetailsAppear)
                .onDisappear(perform: onDetailsDisappear)
        }
        .onChange(of: isActive) { _, active in
            if !active {
                isShowingDetails = false
            }
        }
        .onDisappear {
            // The bar item left the hierarchy (screen popped): no popover may outlive its anchor.
            isShowingDetails = false
            onDetailsDisappear()
        }
        .accessibilityLabel(label)
        .accessibilityIdentifier("library.importProgress")
    }

    @ViewBuilder
    private var ring: some View {
        if progress.total > 0 {
            // A determinate `.circular` ProgressView is a spinner on iOS 18, so draw the ring.
            ZStack {
                Circle().stroke(.tertiary, lineWidth: Self.lineWidth)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(.tint, style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .padding(Self.lineWidth / 2)
            .animation(.default, value: fraction)
        } else {
            ProgressView()
        }
    }

    private static let lineWidth: CGFloat = 3

    private var fraction: Double {
        min(1, max(0, Double(progress.completed) / Double(max(progress.total, 1))))
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(summary)
                .font(.subheadline)
                .monospacedDigit()
            if progress.total > 0 {
                ProgressView(value: Double(progress.completed), total: Double(progress.total))
            } else {
                ProgressView().progressViewStyle(.linear)
            }
        }
        .padding()
        .frame(minWidth: 220)
        .accessibilityElement(children: .combine)
    }

    private var summary: String {
        progress.total > 0
            ? String(localized: "Importing \(progress.completed) of \(progress.total)", bundle: .module)
            : String(localized: "Preparing Import…", bundle: .module)
    }

    private var label: String {
        progress.total > 0
            ? String(localized: "Importing, \(progress.completed) of \(progress.total)", bundle: .module)
            : String(localized: "Preparing Import…", bundle: .module)
    }
}

/// Reads the live progress so only this small view (not the toolbar) updates per tick.
private struct ImportProgressObserver: View {
    let importer: ImportViewModel

    var body: some View {
        ImportProgressIndicator(
            progress: importer.activeProgress ?? ImportProgress(completed: 1, total: 1),
            onDetailsAppear: importer.detailsDidAppear,
            onDetailsDisappear: importer.detailsDidDisappear,
            isActive: importer.isImporting
        )
    }
}

extension View {
    /// Adds the import progress ring as a trailing toolbar item while an import runs. Apply on every Library
    /// screen so progress stays visible while browsing.
    func importProgressIndicator(_ importer: ImportViewModel) -> some View {
        toolbar {
            // Only presence is read here; the ring observes progress itself, so the toolbar is not rebuilt per tick.
            if importer.showsIndicator {
                ToolbarItem(placement: .primaryAction) {
                    ImportProgressObserver(importer: importer)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        Color.clear
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    ImportProgressIndicator(progress: ImportProgress(completed: 340, total: 1000))
                }
            }
    }
}
