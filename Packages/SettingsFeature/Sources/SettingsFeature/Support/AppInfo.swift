import Foundation

/// App name and version read from the bundle's Info.plist.
struct AppInfo: Equatable {
    var name: String
    var version: String
    var build: String

    /// "1.2 (45)"
    var versionString: String {
        "\(version) (\(build))"
    }

    init(name: String, version: String, build: String) {
        self.name = name
        self.version = version
        self.build = build
    }

    init(infoDictionary: [String: Any]?) {
        let info = infoDictionary ?? [:]
        name = (info["CFBundleDisplayName"] as? String) ?? (info["CFBundleName"] as? String) ?? "SeryaPlayer"
        version = (info["CFBundleShortVersionString"] as? String) ?? "1.0"
        build = (info["CFBundleVersion"] as? String) ?? "1"
    }

    static var main: AppInfo {
        AppInfo(infoDictionary: Bundle.main.infoDictionary)
    }
}
