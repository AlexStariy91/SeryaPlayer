import DesignSystem
import Domain
import SwiftUI

/// "Importing 3 of 10" bar pinned under the navigation bar while an import runs.
struct ImportProgressBanner: View {
    let progress: ImportProgress

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if progress.total > 0 {
                Text("Importing \(progress.completed) of \(progress.total)", bundle: .module)
                    .monospacedDigit()
                ProgressView(value: Double(progress.completed), total: Double(progress.total))
            } else {
                Text("Preparing Import…", bundle: .module)
                ProgressView()
                    .progressViewStyle(.linear)
            }
        }
        .font(AppFont.rowSubtitle)
        .foregroundStyle(SemanticColor.textSecondary)
        .padding(.horizontal, Spacing.screenMargin)
        .padding(.vertical, Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("library.importProgress")
    }
}

#Preview {
    ImportProgressBanner(progress: ImportProgress(completed: 3, total: 10))
        .padding()
}
