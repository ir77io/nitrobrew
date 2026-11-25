import Foundation

enum SessionMode: String, CaseIterable, Codable {
    case work25, work50, break5, break10

    var minutes: Int {
        switch self {
        case .work25: 25
        case .work50: 50
        case .break5: 5
        case .break10: 10
        }
    }

    var duration: TimeInterval { TimeInterval(minutes * 60) }

    var isWork: Bool {
        switch self {
        case .work25, .work50: true
        case .break5, .break10: false
        }
    }
}

enum SessionPhase: String, Codable {
    case idle, running, paused, done
}
