import AppKit
import SwiftUI
import XCTest
@testable import NitroBrew

final class ViewSupportTests: XCTestCase {
    func testBackgroundIsBlack() throws {
        let c = try XCTUnwrap(NSColor(Theme.background).usingColorSpace(.sRGB))
        XCTAssertEqual(c.redComponent, 0, accuracy: 0.001)
        XCTAssertEqual(c.greenComponent, 0, accuracy: 0.001)
        XCTAssertEqual(c.blueComponent, 0, accuracy: 0.001)
    }

    func testVersionDisplay() {
        XCTAssertEqual(AppVersion.display(from: ["CFBundleShortVersionString": "1.0.0", "CFBundleVersion": "1"]), "Version 1.0.0 (1)")
        XCTAssertEqual(AppVersion.display(from: ["CFBundleShortVersionString": "2.3.4"]), "Version 2.3.4")
        XCTAssertEqual(AppVersion.display(from: [:]), "Version unknown")
        XCTAssertEqual(AppVersion.display(from: nil), "Version unknown")
    }

    func testCurrentVersionComesFromTheAppBundle() throws {
        let bundle = Bundle(for: AppDelegate.self)
        let short = try XCTUnwrap(bundle.infoDictionary?["CFBundleShortVersionString"] as? String)
        XCTAssertNotEqual(short, "$(MARKETING_VERSION)")
        XCTAssertTrue(AppVersion.current(bundle: bundle).contains(short))
        XCTAssertNotEqual(AppVersion.current(bundle: bundle), "Version unknown")
    }

    func testTimeFormat() {
        XCTAssertEqual(TimeFormat.mmss(1500), "25:00")
        XCTAssertEqual(TimeFormat.mmss(61), "01:01")
        XCTAssertEqual(TimeFormat.mmss(0.2), "00:01")
        XCTAssertEqual(TimeFormat.mmss(0), "00:00")
        XCTAssertEqual(TimeFormat.mmss(-5), "00:00")
        XCTAssertEqual(TimeFormat.mmss(3000), "50:00")
    }

    func testWorkTimeFormat() {
        XCTAssertEqual(TimeFormat.hoursMinutes(0), "0m")
        XCTAssertEqual(TimeFormat.hoursMinutes(25 * 60), "25m")
        XCTAssertEqual(TimeFormat.hoursMinutes(75 * 60), "1h 15m")
    }
}
