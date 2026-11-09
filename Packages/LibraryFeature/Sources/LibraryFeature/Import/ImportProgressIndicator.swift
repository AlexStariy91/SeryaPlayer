import DesignSystem
import Domain
import SwiftUI

/// The progress ring itself. One view for every state (preparing, running, finished), so the bar item that
/// hosts it is never replaced mid-import: on iOS 26 a popover morphs out of its source button and crashes
/// UIKit if that view is swapped or removed while the popover is up.
struct ImportProgressRing: View {
    let progress: ImportProgress

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

    /// A short arc while the total is not known yet, so the ring is never empty.
    private var fraction: Double {
        guard progress.total > 0 else { return 0.08 }
        return min(1, max(0, Double(progress.completed) / Double(progress.total)))
    }
}

/// The bar item: the ring plus a popover with the counts. The popover is only ever opened and closed by the
/// user. The item outlives the import until the popover is gone (`ImportViewModel.showsIndicator`), and the
/// popover shows a "done" state if the import ends while it is open.
struct ImportProgressIndicator: View {
    let importer: ImportViewModel
    @State private var isShowingDetails = false

    var body: some View {
        Button {
            isShowingDetails = true
        } label: {
            ImportProgressRing(progress: importer.activeProgress ?? ImportProgress(completed: 1, total: 1))
        }
        .popover(isPresented: $isShowingDetails) {
            ImportProgressDetails(importer: importer)
                .presentationCompactAdaptation(.popover)
                .onAppear(perform: importer.detailsDidAppear)
                .onDisappear(perform: importer.detailsDidDisappear)
        }
        .onDisappear {
            // The item left the hierarchy (screen popped): make sure the bar does not wait for a popover.
            importer.detailsDidDisappear()
        }
        .accessibilityLabel(label)
        .accessibilityIdentifier("library.importProgress")
    }

    private var label: String {
        guard let progress = importer.activeProgress else {
            return String(localized: "Import Complete", bundle: .module)
        }
        return progress.total > 0
            ? String(localized: "Importing, \(progress.completed) of \(progress.total)", bundle: .module)
            : String(localized: "Preparing Import…", bundle: .module)
    }
}

private struct ImportProgressDetails: View {
    let importer: ImportViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            if let progress = importer.activeProgress {
                if progress.total > 0 {
                    Text("Importing \(progress.completed) of \(progress.total)", bundle: .module)
                        .monospacedDigit()
                    ProgressView(value: Double(progress.completed), total: Double(progress.total))
                } else {
                    Text("Preparing Import…", bundle: .module)
                    ProgressView().progressViewStyle(.linear)
                }
            } else {
                Text("Import Complete", bundle: .module)
                if let summary = importer.summary {
                    Text(summary.message)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .font(.subheadline)
        .padding()
        .frame(minWidth: 220, alignment: .leading)
        .accessibilityElement(children: .combine)
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
