import Domain
import Foundation

/// The alert shown after an import: "Added N · Duplicates M · Unsupported K" (+ failed, when any).
struct ImportSummary: Identifiable, Equatable {
    let id = UUID()
    let added: Int
    let duplicates: Int
    let unsupported: Int
    let failed: Int

    init(_ result: ImportResult) {
        added = result.added.count
        duplicates = result.duplicates.count
        unsupported = result.unsupported.count
        failed = result.failed.count
    }

    var message: String {
        var parts = [
            String(localized: "Added \(added)", bundle: .module),
            String(localized: "Duplicates \(duplicates)", bundle: .module),
            String(localized: "Unsupported \(unsupported)", bundle: .module),
        ]
        if failed > 0 {
            parts.append(String(localized: "Failed \(failed)", bundle: .module))
        }
        return parts.joined(separator: " · ")
    }
}
