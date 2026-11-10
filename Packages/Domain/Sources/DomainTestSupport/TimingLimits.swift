import Foundation

/// Wall-clock limits are checked on developer machines only. Shared CI runners are too noisy for them, and
/// they would turn into false red builds; correctness checks stay on everywhere.
///
/// Every elapsed-time expectation in the package tests goes through this switch.
///
/// Tests run inside the iOS simulator, which doesn't see the host's `CI`. `scripts/test.sh` forwards it as
/// `TEST_RUNNER_CI`, which xcodebuild exposes to the test process as `CI`. (With `swift test` on the host,
/// `CI` is read directly.)
public enum TimingLimits {
    /// `false` when `CI` is set to anything other than empty, `false` or `0`; `true` otherwise.
    public static let areEnforced: Bool = {
        let value = ProcessInfo.processInfo.environment["CI"]?.lowercased()
        return value == nil || value == "" || value == "false" || value == "0"
    }()
}
