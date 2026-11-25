import XCTest
@testable import NitroBrew

final class MessagesTests: XCTestCase {
    func testFinishedWork25() {
        let m = CompletionMessage.make(finished: .work25, vessel: .pint)
        XCTAssertEqual(m.title, "Poured")
        XCTAssertEqual(m.body, "Your 25 minute pour is ready. Take a 5 minute break.")
        XCTAssertEqual(m.actionTitle, "Start 5 min break")
    }

    func testFinishedWork50() {
        let m = CompletionMessage.make(finished: .work50, vessel: .can)
        XCTAssertEqual(m.title, "Poured")
        XCTAssertEqual(m.body, "Your 50 minute pour is ready. Take a 10 minute break.")
        XCTAssertEqual(m.actionTitle, "Start 10 min break")
    }

    func testFinishedBreaksUseVesselNoun() {
        for mode in [SessionMode.break5, .break10] {
            XCTAssertEqual(CompletionMessage.make(finished: mode, vessel: .pint).title, "Glass is empty")
            XCTAssertEqual(CompletionMessage.make(finished: mode, vessel: .pub).title, "Glass is empty")
            let can = CompletionMessage.make(finished: mode, vessel: .can)
            XCTAssertEqual(can.title, "Can is empty")
            XCTAssertEqual(can.body, "Break is over. Ready for the next pour?")
            XCTAssertEqual(can.actionTitle, "Start next pour")
        }
    }

    func testStatusIdle() {
        XCTAssertEqual(StatusText.make(mode: .work25, phase: .idle, level: 0, vessel: .pint), "Empty glass. Ready to pour.")
        XCTAssertEqual(StatusText.make(mode: .work25, phase: .idle, level: 0, vessel: .can), "Empty can. Ready to pour.")
        XCTAssertEqual(StatusText.make(mode: .break5, phase: .idle, level: 1, vessel: .pub), "Full glass. Ready to drain.")
        XCTAssertEqual(StatusText.make(mode: .break5, phase: .idle, level: 1, vessel: .can), "Full can. Ready to drain.")
    }

    func testStatusRunning() {
        XCTAssertEqual(StatusText.make(mode: .work25, phase: .running, level: 0.416, vessel: .pint), "Pouring, 42% full")
        XCTAssertEqual(StatusText.make(mode: .break5, phase: .running, level: 0.3, vessel: .pint), "Draining, 30% left")
    }

    func testStatusPausedAndDone() {
        XCTAssertEqual(StatusText.make(mode: .work25, phase: .paused, level: 0.5, vessel: .pint), "Paused")
        XCTAssertEqual(StatusText.make(mode: .work50, phase: .done, level: 1, vessel: .pint), "Poured. Foam is settling.")
        XCTAssertEqual(StatusText.make(mode: .break10, phase: .done, level: 0, vessel: .pint), "Glass is empty.")
        XCTAssertEqual(StatusText.make(mode: .break10, phase: .done, level: 0, vessel: .can), "Can is empty.")
    }

    func testStatusClampsPercent() {
        XCTAssertEqual(StatusText.make(mode: .work25, phase: .running, level: 7, vessel: .pint), "Pouring, 100% full")
        XCTAssertEqual(StatusText.make(mode: .break5, phase: .running, level: -3, vessel: .pint), "Draining, 0% left")
    }
}

final class ChimeTests: XCTestCase {
    func testChimeWAVIsValidAndNotSilent() {
        let wav = SystemSoundPlayer.chimeWAV()
        XCTAssertEqual(String(data: wav.prefix(4), encoding: .ascii), "RIFF")
        XCTAssertGreaterThan(wav.count, 44)
        XCTAssertNotNil(NSSoundCompat.sound(from: wav))
        XCTAssertTrue(wav.dropFirst(44).contains { $0 != 0 })
    }
}

import AppKit
private enum NSSoundCompat {
    static func sound(from data: Data) -> NSSound? { NSSound(data: data) }
}
