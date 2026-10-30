import Foundation

enum Strings {
    static func songCount(_ count: Int) -> String {
        String(localized: "\(count) songs", bundle: .module)
    }
}
