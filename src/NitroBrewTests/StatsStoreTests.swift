import XCTest
@testable import NitroBrew

@MainActor
final class StatsStoreTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("nb-\(UUID().uuidString).json")
    }
    private let cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }()
    private func rec(_ mode: SessionMode, _ t: TimeInterval, done: Bool = true) -> SessionRecord {
        SessionRecord(id: UUID(), mode: mode, date: Date(timeIntervalSince1970: t), completed: done)
    }

    func testCountsOnlyCompletedWorkInTotals() {
        let s = StatsStore(fileURL: tempURL())
        s.add(rec(.work25, 1_000))
        s.add(rec(.work50, 2_000))
        s.add(rec(.break5, 3_000))
        s.add(rec(.work25, 4_000, done: false))
        XCTAssertEqual(s.totalWorkSessions, 2)
        XCTAssertEqual(s.totalWorkTime, 25 * 60 + 50 * 60, accuracy: 0.001)
    }

    func testTodayCountUsesCalendarDay() {
        let s = StatsStore(fileURL: tempURL())
        let noon = 1_700_000_000.0 // 2023-11-14 22:13 UTC
        s.add(rec(.work25, noon))
        s.add(rec(.break5, noon + 60))
        s.add(rec(.work25, noon - 86_400))
        s.add(rec(.work25, noon + 5, done: false))
        XCTAssertEqual(s.todayCount(calendar: cal, now: Date(timeIntervalSince1970: noon)), 2)
    }

    func testRecentIsLast10NewestFirst() {
        let s = StatsStore(fileURL: tempURL())
        for i in 0..<15 { s.add(rec(.work25, Double(i) * 100)) }
        XCTAssertEqual(s.recent.count, 10)
        XCTAssertEqual(s.recent.first?.date, Date(timeIntervalSince1970: 1_400))
        XCTAssertEqual(s.recent.last?.date, Date(timeIntervalSince1970: 500))
    }

    func testPersistsAndReloads() {
        let url = tempURL()
        let a = StatsStore(fileURL: url)
        a.add(rec(.work25, 123))
        let b = StatsStore(fileURL: url)
        XCTAssertEqual(b.records.count, 1)
        XCTAssertEqual(b.records.first?.mode, .work25)
    }

    func testCorruptFileGivesEmptyStore() throws {
        let url = tempURL()
        try Data("not json".utf8).write(to: url)
        XCTAssertTrue(StatsStore(fileURL: url).records.isEmpty)
    }

    func testMissingFileGivesEmptyStore() {
        XCTAssertTrue(StatsStore(fileURL: tempURL()).records.isEmpty)
    }

    func testExportCSVHasHeaderAndRows() {
        let s = StatsStore(fileURL: tempURL())
        s.add(rec(.work25, 0))
        s.add(rec(.break5, 60, done: false))
        let lines = s.exportCSV().split(separator: "\n").map(String.init)
        XCTAssertEqual(lines.first, "date,mode,completed")
        XCTAssertEqual(lines.count, 3)
        XCTAssertTrue(lines[1].hasSuffix(",work25,true"))
        XCTAssertTrue(lines[2].hasSuffix(",break5,false"))
    }

    func testClear() {
        let url = tempURL()
        let s = StatsStore(fileURL: url)
        s.add(rec(.work25, 1))
        s.clear()
        XCTAssertTrue(s.records.isEmpty)
        XCTAssertTrue(StatsStore(fileURL: url).records.isEmpty)
    }
}
