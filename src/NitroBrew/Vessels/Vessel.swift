import CoreGraphics
import Foundation

enum Vessel: String, CaseIterable, Codable, Identifiable {
    case pint, can, pub

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pint: String(localized: "Pint glass")
        case .can: String(localized: "Nitro can")
        case .pub: String(localized: "Pub glass")
        }
    }

    /// Word used in status lines and notifications ("glass" or "can").
    var noun: String { self == .can ? "can" : "glass" }
}

/// Vessel outlines in a 24x24 space (the same space the menu bar icon is drawn in).
struct VesselGeometry {
    let outline: CGPath
    let inner: CGPath
    let liquidTop: CGFloat
    let liquidHeight: CGFloat
    let hasFoam: Bool
    let widget: CGPoint?

    /// Liquid fills from the visible floor of the glass (the inner path), so the first percent is already visible.
    /// At 100% it stops below the rim, leaving room for the stroke (0.8) and, for vessels with a foam head, the head (2.4).
    private static func make(outline: String, inner: String, hasFoam: Bool, widget: CGPoint? = nil) -> VesselGeometry {
        let o = SVGPath.cgPath(outline)
        let i = SVGPath.cgPath(inner)
        let floor = i.boundingBoxOfPath.maxY
        let headroom: CGFloat = 0.8 + (hasFoam ? 2.4 : 0)
        return VesselGeometry(outline: o, inner: i, liquidTop: floor,
                              liquidHeight: floor - (o.boundingBoxOfPath.minY + headroom), hasFoam: hasFoam, widget: widget)
    }

    static func geometry(for vessel: Vessel) -> VesselGeometry {
        switch vessel {
        case .pint:
            return make(outline: "M5.5 3h13l-1.6 17.2q-.1 1-1.1 1H8.2q-1 0-1.1-1z",
                        inner: "M6.3 4h11.4l-1.5 16H7.8z", hasFoam: true)
        case .can:
            // Chamfered shoulders top and bottom so it reads as a can, not a phone.
            return make(outline: "M9.4 2.5h5.2L16 4.4v15.2l-1.4 1.9H9.4L8 19.6V4.4z",
                        inner: "M9.9 3.6h4.2l1.1 1.5v14.1l-1.1 1.4H9.9l-1.1-1.4V5.1z", hasFoam: false, widget: CGPoint(x: 12, y: 17.5))
        case .pub:
            return make(outline: "M6 3h12l.4 2.8q.1 1.2-.6 1.8L16.9 20.2q-.1 1-1.1 1H8.2q-1 0-1.1-1L6.2 7.6Q5.5 7 5.6 5.8z",
                        inner: "M6.8 4h10.4l.3 1.8-.4.9L16 20.2H8L6.9 6.7l-.4-.9z", hasFoam: true)
        }
    }
}

/// Minimal SVG path reader: M m L l H h V v Q q Z z (absolute and relative).
enum SVGPath {
    static func cgPath(_ d: String) -> CGPath {
        var reader = Reader(Array(d))
        let path = CGMutablePath()
        var cp = CGPoint.zero, start = CGPoint.zero
        var cmd: Character = "M"
        while let next = reader.nextCommandOrNumberStart() {
            if let c = next.command { cmd = c }
            let rel = cmd.isLowercase
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { rel ? CGPoint(x: cp.x + x, y: cp.y + y) : CGPoint(x: x, y: y) }
            switch Character(cmd.uppercased()) {
            case "M":
                guard let x = reader.number(), let y = reader.number() else { return path }
                cp = p(x, y); start = cp; path.move(to: cp); cmd = rel ? "l" : "L"
            case "L":
                guard let x = reader.number(), let y = reader.number() else { return path }
                cp = p(x, y); path.addLine(to: cp)
            case "H":
                guard let x = reader.number() else { return path }
                cp = CGPoint(x: rel ? cp.x + x : x, y: cp.y); path.addLine(to: cp)
            case "V":
                guard let y = reader.number() else { return path }
                cp = CGPoint(x: cp.x, y: rel ? cp.y + y : y); path.addLine(to: cp)
            case "Q":
                guard let cx = reader.number(), let cy = reader.number(), let x = reader.number(), let y = reader.number() else { return path }
                let ctrl = p(cx, cy), end = p(x, y)
                path.addQuadCurve(to: end, control: ctrl); cp = end
            case "Z":
                path.closeSubpath(); cp = start
            default:
                return path
            }
        }
        return path
    }

    private struct Reader {
        let chars: [Character]
        var i = 0
        init(_ c: [Character]) { chars = c }

        /// Skips separators; returns a new command letter if one is next, or an implicit repeat if a number is next.
        mutating func nextCommandOrNumberStart() -> (command: Character?, Void)? {
            while i < chars.count, chars[i] == " " || chars[i] == "," { i += 1 }
            guard i < chars.count else { return nil }
            if chars[i].isLetter { let c = chars[i]; i += 1; return (c, ()) }
            return (nil, ())
        }

        mutating func number() -> CGFloat? {
            while i < chars.count, chars[i] == " " || chars[i] == "," { i += 1 }
            guard i < chars.count else { return nil }
            var s = ""
            if chars[i] == "-" || chars[i] == "+" { s.append(chars[i]); i += 1 }
            var seenDot = false
            while i < chars.count {
                let c = chars[i]
                if c.isNumber { s.append(c) } else if c == ".", !seenDot { seenDot = true; s.append(c) } else { break }
                i += 1
            }
            return Double(s).map { CGFloat($0) }
        }
    }
}
