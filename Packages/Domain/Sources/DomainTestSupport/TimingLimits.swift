import Foundation

/// Wall-clock limits are checked on developer machines only. Shared CI runners are too noisy for them, and
/// they would turn into false red builds; correctness checks stay on everywhere.
///
/// The tests run inside the iOS simulator, which doesn't see the host's `CI`. `scripts/test.sh` forwards it as
/// `TEST_RUNNER_CI`, which xcodebuild exposes to the test process as `CI`.
public enum TimingLimits {
    /// `true` unless the tests run on CI.
    public static let areEnforced: Bool = {
        let value = ProcessInfo.processInfo.environment["CI"]?.lowercased()
        return value == nil || value == "" || value == "false" || value == "0"
    }()
}
