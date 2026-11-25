import Foundation

struct EngineSnapshot: Codable, Equatable {
    var mode: SessionMode
    var phase: SessionPhase
    var endDate: Date?
    var pausedRemaining: TimeInterval?
    var completedAt: Date?
}

/// Wall-clock session timer. It owns no timers: callers invoke `tick()`.
@MainActor
final class SessionEngine: ObservableObject {
    @Published private(set) var mode: SessionMode = .work25
    @Published private(set) var phase: SessionPhase = .idle
    @Published private(set) var completedAt: Date?
    @Published private(set) var cascadeStart: Date?

    var onComplete: ((SessionMode) -> Void)?

    private let clock: () -> Date
    private var endDate: Date?
    private var pausedRemaining: TimeInterval?

    init(clock: @escaping () -> Date = Date.init) {
        self.clock = clock
    }

    var remaining: TimeInterval {
        switch phase {
        case .idle: mode.duration
        case .running: max(0, min(mode.duration, (endDate ?? clock()).timeIntervalSince(clock())))
        case .paused: max(0, pausedRemaining ?? mode.duration)
        case .done: 0
        }
    }

    /// Work rises 0 to 1; breaks fall 1 to 0. Always clamped to 0...1.
    var fillLevel: Double {
        let progress = 1 - remaining / mode.duration
        let level = mode.isWork ? progress : 1 - progress
        return min(1, max(0, level))
    }

    func select(_ newMode: SessionMode) {
        reset()
        mode = newMode
    }

    func start() {
        switch phase {
        case .done:
            reset()
            start()
        case .idle:
            endDate = clock().addingTimeInterval(mode.duration)
            cascadeStart = mode.isWork ? clock() : nil
            phase = .running
        case .paused:
            endDate = clock().addingTimeInterval(pausedRemaining ?? mode.duration)
            pausedRemaining = nil
            phase = .running
        case .running:
            break
        }
    }

    func pause() {
        guard phase == .running else { return }
        pausedRemaining = remaining
        endDate = nil
        phase = .paused
    }

    func reset() {
        phase = .idle
        endDate = nil
        pausedRemaining = nil
        completedAt = nil
        cascadeStart = nil
    }

    /// Returns the finished mode exactly once, on the first tick at or after the end date.
    @discardableResult
    func tick() -> SessionMode? {
        guard phase == .running, let end = endDate, clock() >= end else { return nil }
        phase = .done
        completedAt = clock()
        endDate = nil
        let finished = mode
        onComplete?(finished)
        return finished
    }

    func snapshot() -> EngineSnapshot {
        EngineSnapshot(mode: mode, phase: phase, endDate: endDate, pausedRemaining: pausedRemaining, completedAt: completedAt)
    }

    func restore(_ s: EngineSnapshot) {
        mode = s.mode
        phase = s.phase
        endDate = s.endDate
        pausedRemaining = s.pausedRemaining
        cascadeStart = nil
        completedAt = s.phase == .done ? s.completedAt : nil
    }
}
