import XCTest
@testable import NitroBrew

final class FakeNotifier: Notifying {
    var messages: [CompletionMessage] = []
    var authorizationRequests = 0
    func requestAuthorization() async { authorizationRequests += 1 }
    func notify(_ message: CompletionMessage) { messages.append(message) }
}

final class FakeSound: SoundPlaying {
    var played: [AlertSound] = []
    func play(_ sound: AlertSound) { played.append(sound) }
}

/// A notifier whose permission was denied: it accepts calls and shows nothing.
final class DeniedNotifier: Notifying {
    func requestAuthorization() async {}
    func notify(_ message: CompletionMessage) {}
}

@MainActor
final class AppCoordinatorTests: XCTestCase {
    var now = Date(timeIntervalSince1970: 10_000)
    var defaults: UserDefaults!
    var settings: AppSettings!
    var stats: StatsStore!
    var notifier = FakeNotifier()
    var sound = FakeSound()

    override func setUp() async throws {
        let name = "nitrobrew.coordinator.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: name)
        defaults.removePersistentDomain(forName: name)
        settings = AppSettings(defaults: defaults)
        stats = StatsStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("nbc-\(UUID().uuidString).json"))
        notifier = FakeNotifier()
        sound = FakeSound()
    }

    func make(notifier n: Notifying? = nil) -> AppCoordinator {
        let engine = SessionEngine(clock: { [unowned self] in self.now })
        return AppCoordinator(engine: engine, settings: settings, stats: stats, notifier: n ?? notifier, sound: sound, defaults: defaults)
    }

    func finishWork(_ c: AppCoordinator) {
        c.start()
        now.addTimeInterval(c.engine.mode.duration + 1)
        c.tick()
    }

    func testCompletionRecordsNotifiesAndPlays() {
        let c = make()
        finishWork(c)
        XCTAssertEqual(stats.records.count, 1)
        XCTAssertEqual(stats.records.first?.mode, .work25)
        XCTAssertEqual(stats.records.first?.completed, true)
        XCTAssertEqual(notifier.messages, [CompletionMessage.make(finished: .work25, vessel: .pint)])
        XCTAssertEqual(sound.played, [.softChime])
        XCTAssertEqual(c.completion, CompletionMessage.make(finished: .work25, vessel: .pint))
    }

    func testAutoStartBreaksStartsBreak() {
        settings.autoStartBreaks = true
        let c = make()
        finishWork(c)
        XCTAssertEqual(c.engine.mode, .break5)
        XCTAssertEqual(c.engine.phase, .running)
        XCTAssertNil(c.completion)
        XCTAssertEqual(notifier.messages.count, 1)
    }

    func testAutoStartOffLeavesDone() {
        let c = make()
        finishWork(c)
        XCTAssertEqual(c.engine.phase, .done)
    }

    func testAutoStartWorkAfterBreak() {
        settings.autoStartWork = true
        let c = make()
        c.select(.break5)
        finishWork(c)
        XCTAssertEqual(c.engine.mode, .work25)
        XCTAssertEqual(c.engine.phase, .running)
    }

    func testStartNextFromWorkStartsBreak() {
        let c = make()
        c.select(.work50)
        finishWork(c)
        c.startNext()
        XCTAssertEqual(c.engine.mode, .break10)
        XCTAssertEqual(c.engine.phase, .running)
        XCTAssertNil(c.completion)
    }

    func testStartNextFromBreakReturnsToLastWorkMode() {
        let c = make()
        c.select(.work50)
        finishWork(c)
        c.startNext()
        now.addTimeInterval(601)
        c.tick()
        XCTAssertEqual(c.engine.phase, .done)
        c.startNext()
        XCTAssertEqual(c.engine.mode, .work50)
        XCTAssertEqual(c.engine.phase, .running)
    }

    func testRelaunchAfterEndRecordsExactlyOnce() {
        let first = make()
        first.start()
        first.saveState()
        now.addTimeInterval(5_000)
        let second = make()
        second.restoreState()
        second.tick()
        second.tick()
        XCTAssertEqual(stats.records.count, 1)
        XCTAssertEqual(notifier.messages.count, 1)
    }

    func testRelaunchBeforeEndKeepsRunning() {
        let first = make()
        first.start()
        first.saveState()
        now.addTimeInterval(300)
        let second = make()
        second.restoreState()
        second.tick()
        XCTAssertEqual(second.engine.phase, .running)
        XCTAssertEqual(second.engine.remaining, 1200, accuracy: 0.001)
        XCTAssertTrue(stats.records.isEmpty)
    }

    func testRestoreWithNothingSavedIsIdle() {
        let c = make()
        c.restoreState()
        XCTAssertEqual(c.engine.phase, .idle)
    }

    func testDeniedNotificationStillPlaysSoundAndRecords() {
        let c = make(notifier: DeniedNotifier())
        finishWork(c)
        XCTAssertEqual(sound.played, [.softChime])
        XCTAssertEqual(stats.records.count, 1)
        XCTAssertNotNil(c.completion)
    }

    func testResetMidSessionRecordsSkippedNotCompleted() {
        let c = make()
        c.start()
        now.addTimeInterval(100)
        c.reset()
        XCTAssertEqual(c.engine.phase, .idle)
        XCTAssertEqual(stats.records.count, 1)
        XCTAssertEqual(stats.records.first?.completed, false)
        XCTAssertEqual(stats.totalWorkSessions, 0)
        XCTAssertTrue(notifier.messages.isEmpty)
        XCTAssertTrue(sound.played.isEmpty)
    }

    func testSelectMidSessionRecordsSkipped() {
        let c = make()
        c.start()
        c.select(.break5)
        XCTAssertEqual(stats.records.first?.completed, false)
        XCTAssertEqual(c.engine.mode, .break5)
        XCTAssertEqual(c.engine.phase, .idle)
    }

    func testResetWhenIdleRecordsNothing() {
        let c = make()
        c.reset()
        XCTAssertTrue(stats.records.isEmpty)
    }

    func testDismissingCompletionClearsIt() {
        let c = make()
        finishWork(c)
        c.dismissCompletion()
        XCTAssertNil(c.completion)
    }
}
