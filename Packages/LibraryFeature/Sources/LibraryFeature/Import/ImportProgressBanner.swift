import DesignSystem
import Domain
import SwiftUI

/// Floating "Importing 3 of 10" capsule shown while an import runs.
struct ImportProgressBanner: View {
    let progress: ImportProgress

    var body: some View {
        HStack(spacing: Spacing.m) {
            if progress.total > 0 {
                ProgressView(value: Double(progress.completed), total: Double(progress.total))
                    .frame(width: 80)
                Text("Importing \(progress.completed) of \(progress.total)", bundle: .module)
                    .monospacedDigit()
            } else {
                ProgressView()
                Text("Preparing Import…", bundle: .module)
            }
        }
        .font(AppFont.rowSubtitle)
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.m)
        .adaptiveGlass()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("library.importProgress")
    }
}

#Preview {
    ImportProgressBanner(progress: ImportProgress(completed: 3, total: 10))
        .padding()
}
