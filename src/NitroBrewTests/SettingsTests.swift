import XCTest
@testable import NitroBrew

@MainActor
final class SettingsTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let name = "nitrobrew.tests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    func testDefaults() {
        let s = AppSettings(defaults: freshDefaults())
        XCTAssertEqual(s.vessel, .pint)
        XCTAssertFalse(s.autoStartBreaks)
        XCTAssertFalse(s.autoStartWork)
        XCTAssertEqual(s.alertSound, .softChime)
        XCTAssertTrue(s.showTimeInMenuBar)
    }

    func testSettingsPersistAcrossInstances() {
        let d = freshDefaults()
        let a = AppSettings(defaults: d)
        a.vessel = .can
        a.autoStartBreaks = true
        a.autoStartWork = true
        a.alertSound = .hero
        a.showTimeInMenuBar = false
        let b = AppSettings(defaults: d)
        XCTAssertEqual(b.vessel, .can)
        XCTAssertTrue(b.autoStartBreaks)
        XCTAssertTrue(b.autoStartWork)
        XCTAssertEqual(b.alertSound, .hero)
        XCTAssertFalse(b.showTimeInMenuBar)
    }

    func testUnknownStoredValuesFallBackToDefaults() {
        let d = freshDefaults()
        d.set("teacup", forKey: "vessel")
        d.set("nonsense", forKey: "alertSound")
        let s = AppSettings(defaults: d)
        XCTAssertEqual(s.vessel, .pint)
        XCTAssertEqual(s.alertSound, .softChime)
    }

    func testSystemSoundNames() {
        XCTAssertNil(AlertSound.softChime.systemSoundName)
        XCTAssertNil(AlertSound.none.systemSoundName)
        XCTAssertEqual(AlertSound.glass.systemSoundName, "Glass")
        XCTAssertEqual(AlertSound.submarine.systemSoundName, "Submarine")
    }
}
