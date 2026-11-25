import AppKit
import XCTest
@testable import NitroBrew

final class VesselTests: XCTestCase {
    private func bitmap(_ vessel: Vessel, _ level: Double) -> Data {
        MenuBarIconRenderer.image(vessel: vessel, level: level).tiffRepresentation ?? Data()
    }

    func testIconIsTemplateAndSized() {
        for v in Vessel.allCases {
            let image = MenuBarIconRenderer.image(vessel: v, level: 0.5)
            XCTAssertTrue(image.isTemplate, "\(v)")
            XCTAssertEqual(image.size.width, 18, accuracy: 0.001)
            XCTAssertEqual(image.size.height, 18, accuracy: 0.001)
        }
    }

    func testIconChangesWithLevel() {
        for v in Vessel.allCases {
            let empty = bitmap(v, 0), half = bitmap(v, 0.5), full = bitmap(v, 1)
            XCTAssertNotEqual(empty, half, "\(v) 0 vs 0.5")
            XCTAssertNotEqual(half, full, "\(v) 0.5 vs 1")
            XCTAssertNotEqual(empty, full, "\(v) 0 vs 1")
        }
    }

    func testVesselsLookDifferent() {
        let p = bitmap(.pint, 0.5), c = bitmap(.can, 0.5), u = bitmap(.pub, 0.5)
        XCTAssertNotEqual(p, c)
        XCTAssertNotEqual(p, u)
        XCTAssertNotEqual(c, u)
    }

    func testLevelClampedAndSafe() {
        for v in Vessel.allCases {
            XCTAssertEqual(bitmap(v, -1), bitmap(v, 0))
            XCTAssertEqual(bitmap(v, 2), bitmap(v, 1))
            XCTAssertFalse(bitmap(v, .nan).isEmpty)
        }
    }

    func testGeometryStaysInsideTwentyFourSquare() {
        let box = CGRect(x: 0, y: 0, width: 24, height: 24)
        for v in Vessel.allCases {
            let g = VesselGeometry.geometry(for: v)
            XCTAssertTrue(box.contains(g.outline.boundingBoxOfPath), "\(v) outline")
            XCTAssertTrue(g.outline.boundingBoxOfPath.contains(g.inner.boundingBoxOfPath), "\(v) inner inside outline")
            XCTAssertGreaterThan(g.liquidHeight, 10)
        }
    }

    func testSVGPathParsesPintOutline() {
        let path = SVGPath.cgPath("M5.5 3h13l-1.6 17.2q-.1 1-1.1 1H8.2q-1 0-1.1-1z")
        let b = path.boundingBoxOfPath
        XCTAssertEqual(b.minX, 5.5, accuracy: 0.05)
        XCTAssertEqual(b.maxX, 18.5, accuracy: 0.05)
        XCTAssertEqual(b.minY, 3, accuracy: 0.05)
        XCTAssertEqual(b.maxY, 21.2, accuracy: 0.1)
    }

    func testNounsAndNames() {
        XCTAssertEqual(Vessel.pint.noun, "glass")
        XCTAssertEqual(Vessel.pub.noun, "glass")
        XCTAssertEqual(Vessel.can.noun, "can")
        XCTAssertEqual(Vessel.pub.displayName, "Pub glass")
    }

    func testCascadeStrength() {
        let t0 = Date(timeIntervalSince1970: 100)
        XCTAssertEqual(CascadeModel.strength(now: t0, start: t0), 1, accuracy: 1e-9)
        XCTAssertEqual(CascadeModel.strength(now: t0.addingTimeInterval(3), start: t0), 0, accuracy: 1e-9)
        XCTAssertEqual(CascadeModel.strength(now: t0.addingTimeInterval(30), start: t0), 0, accuracy: 1e-9)
        XCTAssertEqual(CascadeModel.strength(now: t0, start: nil), 0)
        var previous = 1.0
        for i in 0...30 {
            let s = CascadeModel.strength(now: t0.addingTimeInterval(Double(i) / 10), start: t0)
            XCTAssertLessThanOrEqual(s, previous + 1e-12)
            previous = s
        }
    }
}
