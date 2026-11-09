import DesignSystem
import Domain
import SwiftUI

/// A small progress ring in the navigation bar while an import runs (the way Files and Safari show
/// downloads). Tapping it opens a popover with the counts. Leaves the title area to the system.
struct ImportProgressIndicator: View {
    let progress: ImportProgress
    @State private var isShowingDetails = false

    var body: some View {
        Button {
            isShowingDetails = true
        } label: {
            ring
                .frame(width: 22, height: 22)
        }
        .popover(isPresented: $isShowingDetails) {
            details
                .presentationCompactAdaptation(.popover)
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
        ImportProgressIndicator(progress: importer.activeProgress ?? ImportProgress(completed: 0, total: 0))
    }
}

extension View {
    /// Adds the import progress ring as a trailing toolbar item while an import runs. Apply on every Library
    /// screen so progress stays visible while browsing.
    func importProgressIndicator(_ importer: ImportViewModel) -> some View {
        toolbar {
            // Only presence is read here; the ring observes progress itself, so the toolbar is not rebuilt per tick.
            if importer.isImporting {
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
