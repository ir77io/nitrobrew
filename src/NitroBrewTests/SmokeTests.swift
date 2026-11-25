import XCTest
@testable import NitroBrew

final class SmokeTests: XCTestCase {
    func testAppModuleLoads() {
        XCTAssertEqual(Bundle(for: AppDelegate.self).bundleIdentifier, "com.ir77io.nitrobrewtimer")
    }
}
