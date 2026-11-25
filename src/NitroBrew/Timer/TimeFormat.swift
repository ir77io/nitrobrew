import Foundation

enum TimeFormat {
    /// "mm:ss", rounding partial seconds up so a running timer never shows 00:00 early.
    static func mmss(_ t: TimeInterval) -> String {
        let total = max(0, Int(t.isFinite ? t.rounded(.up) : 0))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    /// "25m" or "1h 15m".
    static func hoursMinutes(_ t: TimeInterval) -> String {
        let minutes = max(0, Int(t / 60))
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}
