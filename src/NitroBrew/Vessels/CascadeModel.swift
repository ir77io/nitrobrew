import Foundation

/// The short "nitro cascade" at the start of a fresh work session.
struct CascadeModel {
    static let duration: TimeInterval = 3

    /// 1 at the start, easing to 0 after `duration`; 0 when there is no cascade.
    static func strength(now: Date, start: Date?) -> Double {
        guard let start else { return 0 }
        let t = now.timeIntervalSince(start)
        if t <= 0 { return 1 }
        if t >= duration { return 0 }
        let x = 1 - t / duration
        return x * x
    }
}
