import Foundation

/// Ties the engine to settings, statistics, notifications, sound and persistence.
@MainActor
final class AppCoordinator: ObservableObject {
    let engine: SessionEngine
    let settings: AppSettings
    let stats: StatsStore

    @Published var completion: CompletionMessage?

    private let notifier: Notifying
    private let sound: SoundPlaying
    private let defaults: UserDefaults
    private var lastWorkMode: SessionMode

    private enum Key {
        static let snapshot = "engineSnapshot"
        static let lastWork = "lastWorkMode"
    }

    init(engine: SessionEngine, settings: AppSettings, stats: StatsStore, notifier: Notifying, sound: SoundPlaying, defaults: UserDefaults = .standard) {
        self.engine = engine
        self.settings = settings
        self.stats = stats
        self.notifier = notifier
        self.sound = sound
        self.defaults = defaults
        lastWorkMode = defaults.string(forKey: Key.lastWork).flatMap(SessionMode.init(rawValue:)).flatMap { $0.isWork ? $0 : nil } ?? .work25
        engine.onComplete = { [weak self] mode in self?.handleCompletion(mode) }
    }

    // MARK: Controls (always go through here so statistics and persistence stay correct)

    func start() { engine.start(); saveState() }
    func pause() { engine.pause(); saveState() }

    func reset() {
        recordSkippedIfInProgress()
        engine.reset()
        completion = nil
        saveState()
    }

    func select(_ mode: SessionMode) {
        recordSkippedIfInProgress()
        if mode.isWork { lastWorkMode = mode; defaults.set(mode.rawValue, forKey: Key.lastWork) }
        engine.select(mode)
        completion = nil
        saveState()
    }

    @discardableResult
    func tick() -> SessionMode? { engine.tick() }

    func startNext() {
        completion = nil
        let current = engine.mode
        let next: SessionMode = current.isWork ? (current == .work50 ? .break10 : .break5) : lastWorkMode
        engine.select(next)
        engine.start()
        saveState()
    }

    func dismissCompletion() { completion = nil }

    // MARK: Persistence

    func saveState() {
        guard let data = try? JSONEncoder().encode(engine.snapshot()) else { return }
        defaults.set(data, forKey: Key.snapshot)
    }

    func restoreState() {
        guard let data = defaults.data(forKey: Key.snapshot),
              let snapshot = try? JSONDecoder().decode(EngineSnapshot.self, from: data) else { return }
        engine.restore(snapshot)
    }

    // MARK: Private

    private func handleCompletion(_ mode: SessionMode) {
        if mode.isWork { lastWorkMode = mode; defaults.set(mode.rawValue, forKey: Key.lastWork) }
        stats.add(SessionRecord(id: UUID(), mode: mode, date: engine.completedAt ?? Date(), completed: true))
        let message = CompletionMessage.make(finished: mode, vessel: settings.vessel)
        notifier.notify(message)
        sound.play(settings.alertSound)
        let auto = mode.isWork ? settings.autoStartBreaks : settings.autoStartWork
        if auto {
            startNext()
        } else {
            completion = message
            saveState()
        }
    }

    private func recordSkippedIfInProgress() {
        guard engine.phase == .running || engine.phase == .paused else { return }
        stats.add(SessionRecord(id: UUID(), mode: engine.mode, date: Date(), completed: false))
    }
}
