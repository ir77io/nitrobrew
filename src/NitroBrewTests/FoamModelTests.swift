import XCTest
@testable import NitroBrew

final class FoamModelTests: XCTestCase {
    func testZeroAtEmpty() {
        for mode in SessionMode.allCases {
            for phase in [SessionPhase.idle, .running, .paused, .done] {
                XCTAssertEqual(FoamModel.target(level: 0, mode: mode, phase: phase, secondsSinceDone: 1), 0, accuracy: 1e-9)
            }
        }
    }

    func testFullHeadByFortyFivePercent() {
        XCTAssertEqual(FoamModel.target(level: 0.45, mode: .work25, phase: .running, secondsSinceDone: nil), 20, accuracy: 1e-9)
        XCTAssertEqual(FoamModel.target(level: 1.0, mode: .work25, phase: .running, secondsSinceDone: nil), 20, accuracy: 1e-9)
    }

    func testNeverJumps() {
        var foam = FoamModel()
        let steps = 90_000
        var previous = foam.thickness
        var maxDelta = 0.0
        for i in 0...steps {
            let level = Double(i) / Double(steps)
            foam.update(level: level, mode: .work25, phase: .running, secondsSinceDone: nil, dt: 1.0 / 60)
            maxDelta = max(maxDelta, abs(foam.thickness - previous))
            previous = foam.thickness
        }
        XCTAssertLessThan(maxDelta, 0.5)
    }

    func testEasesRatherThanSnapsWhenTargetJumps() {
        var foam = FoamModel()
        foam.update(level: 1, mode: .work25, phase: .running, secondsSinceDone: nil, dt: 1.0 / 60)
        XCTAssertGreaterThan(foam.thickness, 0)
        XCTAssertLessThan(foam.thickness, 2)
    }

    func testSettlesAfterDone() {
        XCTAssertEqual(FoamModel.target(level: 1, mode: .work25, phase: .done, secondsSinceDone: 1), 22, accuracy: 1e-9)
        XCTAssertEqual(FoamModel.target(level: 1, mode: .work25, phase: .done, secondsSinceDone: 3), 13, accuracy: 1e-9)
    }

    func testBreakThinsAsLevelDrops() {
        let full = FoamModel.target(level: 1, mode: .break5, phase: .running, secondsSinceDone: nil)
        let half = FoamModel.target(level: 0.5, mode: .break5, phase: .running, secondsSinceDone: nil)
        let low = FoamModel.target(level: 0.2, mode: .break5, phase: .running, secondsSinceDone: nil)
        XCTAssertGreaterThan(full, half)
        XCTAssertGreaterThan(half, low)
        XCTAssertGreaterThan(low, 0)
    }

    func testClampsAndNoNaN() {
        for level in [-1.0, 0, 1, 5] {
            for dt in [0.0, 10] {
                var foam = FoamModel()
                foam.update(level: level, mode: .work25, phase: .running, secondsSinceDone: nil, dt: dt)
                XCTAssertTrue(foam.thickness.isFinite)
                XCTAssertTrue((0...30).contains(foam.thickness))
            }
        }
    }
}
