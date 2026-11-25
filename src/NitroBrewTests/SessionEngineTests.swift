import XCTest
@testable import NitroBrew

@MainActor
final class SessionEngineTests: XCTestCase {
    var now = Date(timeIntervalSince1970: 1_000)

    func makeEngine() -> SessionEngine {
        SessionEngine(clock: { [unowned self] in self.now })
    }

    func testWorkLevelRisesLinearly() {
        let e = makeEngine()
        e.start()
        now.addTimeInterval(750)
        XCTAssertEqual(e.fillLevel, 0.5, accuracy: 0.0001)
        XCTAssertEqual(e.remaining, 750, accuracy: 0.0001)
    }

    func testBreakLevelStartsFullAndDrains() {
        let e = makeEngine()
        e.select(.break5)
        XCTAssertEqual(e.fillLevel, 1, accuracy: 0.0001)
        e.start()
        now.addTimeInterval(150)
        XCTAssertEqual(e.fillLevel, 0.5, accuracy: 0.0001)
    }

    func testTickCompletesOnceAndFiresOnComplete() {
        let e = makeEngine()
        var fired: [SessionMode] = []
        e.onComplete = { fired.append($0) }
        e.start()
        now.addTimeInterval(1501)
        XCTAssertEqual(e.tick(), .work25)
        XCTAssertEqual(e.phase, .done)
        XCTAssertNil(e.tick())
        XCTAssertEqual(fired, [.work25])
    }

    func testPauseFreezesRemaining() {
        let e = makeEngine()
        e.start()
        now.addTimeInterval(600)
        e.pause()
        now.addTimeInterval(600)
        XCTAssertEqual(e.remaining, 900, accuracy: 0.0001)
        e.start()
        now.addTimeInterval(100)
        XCTAssertEqual(e.remaining, 800, accuracy: 0.0001)
    }

    func testResumeDoesNotRestartCascade() {
        let e = makeEngine()
        e.start()
        let first = e.cascadeStart
        XCTAssertNotNil(first)
        now.addTimeInterval(30)
        e.pause()
        e.start()
        XCTAssertEqual(e.cascadeStart, first)
    }

    func testSelectOrResetMidSessionDiscards() {
        let e = makeEngine()
        var fired = 0
        e.onComplete = { _ in fired += 1 }
        e.start()
        now.addTimeInterval(100)
        e.select(.break5)
        XCTAssertEqual(e.phase, .idle)
        e.start()
        e.reset()
        XCTAssertEqual(e.phase, .idle)
        now.addTimeInterval(100_000)
        XCTAssertNil(e.tick())
        XCTAssertEqual(fired, 0)
    }

    func testClampsLevel() {
        let e = makeEngine()
        e.start()
        now.addTimeInterval(15_000)
        XCTAssertEqual(e.fillLevel, 1.0, accuracy: 0.0001)
        XCTAssertEqual(e.remaining, 0, accuracy: 0.0001)
    }

    func testRestoreAfterEndDateCompletesOnce() {
        let a = makeEngine()
        a.start()
        let snap = a.snapshot()
        now.addTimeInterval(5_000)
        let b = makeEngine()
        var fired = 0
        b.onComplete = { _ in fired += 1 }
        b.restore(snap)
        XCTAssertEqual(b.tick(), .work25)
        XCTAssertNil(b.tick())
        XCTAssertEqual(fired, 1)
        XCTAssertEqual(b.phase, .done)
    }

    func testRestoreRunningBeforeEndKeepsRunning() {
        let a = makeEngine()
        a.start()
        let snap = a.snapshot()
        now.addTimeInterval(300)
        let b = makeEngine()
        b.restore(snap)
        XCTAssertEqual(b.phase, .running)
        XCTAssertEqual(b.remaining, 1200, accuracy: 0.0001)
    }

    func testRestorePausedKeepsRemaining() {
        let a = makeEngine()
        a.start()
        now.addTimeInterval(400)
        a.pause()
        let snap = a.snapshot()
        now.addTimeInterval(9_999)
        let b = makeEngine()
        b.restore(snap)
        XCTAssertEqual(b.phase, .paused)
        XCTAssertEqual(b.remaining, 1100, accuracy: 0.0001)
    }
}
