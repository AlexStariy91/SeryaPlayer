import Foundation

enum TimeFormat {
    /// `m:ss`, or `h:mm:ss` from an hour up. Negative and non-finite values give `0:00`.
    static func clock(_ time: TimeInterval) -> String {
        guard time.isFinite, time > 0 else { return "0:00" }
        let total = Int(time.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Spoken form for VoiceOver.
    static func spoken(_ time: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .spellOut
        formatter.allowedUnits = [.hour, .minute, .second]
        return formatter.string(from: max(0, time.isFinite ? time : 0)) ?? ""
    }
}
