import DesignSystem
import Domain
import SwiftUI

/// The progress ring itself. One view for every state (preparing, running), so it is never replaced mid-import.
struct ImportProgressRing: View {
    let progress: ImportProgress?

    var body: some View {
        ZStack {
            Circle().stroke(.tertiary, lineWidth: Self.lineWidth)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(.tint, style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(Self.lineWidth / 2)
        .frame(width: 22, height: 22)
        // A determinate `.circular` ProgressView is a spinner on iOS 18, so the ring is drawn.
        .animation(.default, value: fraction)
    }

    private static let lineWidth: CGFloat = 3

    private var fraction: Double {
        Self.fraction(of: progress)
    }

    /// The drawn arc. Empty while the import is being prepared (no progress yet, or the total is not known), so
    /// within one import it only ever grows from empty: `completed` never decreases and `total` is fixed once known.
    static func fraction(of progress: ImportProgress?) -> Double {
        guard let progress, progress.total > 0 else { return 0 }
        return min(1, max(0, Double(progress.completed) / Double(progress.total)))
    }
}

/// The ring bound to the import: a plain, non-interactive progress indicator (no button, no popover). It
/// observes progress itself, so the toolbar that hosts it is not rebuilt per tick.
struct ImportProgressIndicator: View {
    let importer: ImportViewModel

    var body: some View {
        ImportProgressRing(progress: importer.activeProgress)
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityAddTraits(.updatesFrequently)
            .accessibilityIdentifier("library.importProgress")
    }

    private var label: String {
        guard let progress = importer.activeProgress, progress.total > 0 else {
            return String(localized: "Preparing Import…", bundle: .module)
        }
        return String(localized: "Importing, \(progress.completed) of \(progress.total)", bundle: .module)
    }
}

extension View {
    /// Adds the import progress ring as a trailing toolbar item while an import runs. Apply on every pushed
    /// Library screen so progress stays visible while browsing; Library home swaps it in for "+" instead.
    func importProgressIndicator(_ importer: ImportViewModel) -> some View {
        toolbar {
            // Only presence is read here; the ring observes progress itself, so the toolbar is not rebuilt per tick.
            if importer.isImporting {
                ToolbarItem(placement: .primaryAction) {
                    ImportProgressIndicator(importer: importer)
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
                    ImportProgressRing(progress: ImportProgress(completed: 340, total: 1000))
                }
            }
    }
}
