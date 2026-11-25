import Foundation

struct CompletionMessage: Equatable {
    let title: String
    let body: String
    let actionTitle: String

    static func make(finished: SessionMode, vessel: Vessel) -> CompletionMessage {
        if finished.isWork {
            let next = finished == .work50 ? 10 : 5
            return CompletionMessage(
                title: String(localized: "Poured"),
                body: String(localized: "Your \(finished.minutes) minute pour is ready. Take a \(next) minute break."),
                actionTitle: String(localized: "Start \(next) min break"))
        }
        return CompletionMessage(
            title: String(localized: "\(vessel.noun.capitalized) is empty"),
            body: String(localized: "Break is over. Ready for the next pour?"),
            actionTitle: String(localized: "Start next pour"))
    }
}

enum StatusText {
    static func make(mode: SessionMode, phase: SessionPhase, level: Double, vessel: Vessel) -> String {
        let pct = Int((min(1, max(0, level.isFinite ? level : 0)) * 100).rounded())
        let noun = vessel.noun
        switch phase {
        case .idle:
            return mode.isWork ? String(localized: "Empty \(noun). Ready to pour.") : String(localized: "Full \(noun). Ready to drain.")
        case .running:
            return mode.isWork ? String(localized: "Pouring, \(pct)% full") : String(localized: "Draining, \(pct)% left")
        case .paused:
            return String(localized: "Paused")
        case .done:
            return mode.isWork ? String(localized: "Poured. Foam is settling.") : String(localized: "\(noun.capitalized) is empty.")
        }
    }
}
