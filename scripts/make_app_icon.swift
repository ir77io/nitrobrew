#!/usr/bin/env swift
// Generates the NitroBrew app icon: a pint of nitro brew with a cream head on black.
// Usage: swift scripts/make_app_icon.swift <AppIcon.appiconset dir> [flattened-1024.png]
import AppKit

func draw(_ ctx: CGContext) {
    let cs = CGColorSpaceCreateDeviceRGB()
    func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
        CGColor(colorSpace: cs, components: [CGFloat((hex >> 16) & 255) / 255, CGFloat((hex >> 8) & 255) / 255, CGFloat(hex & 255) / 255, a])!
    }
    func gradient(_ hexes: [UInt32]) -> CGGradient {
        CGGradient(colorsSpace: cs, colors: hexes.map { color($0) } as CFArray, locations: nil)!
    }

    // Body: black rounded square with a faint warm lift at the top.
    let body = CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.addPath(body); ctx.clip()
    ctx.drawLinearGradient(gradient([0x1a120c, 0x000000]), start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

    // Pint glass (y up): wide at the rim, narrower at the base.
    func glassPath(inset: CGFloat) -> CGPath {
        let p = CGMutablePath()
        let topY: CGFloat = 770 - inset, botY: CGFloat = 235 + inset
        let topL: CGFloat = 322 + inset, topR: CGFloat = 702 - inset
        let botL: CGFloat = 392 + inset * 0.7, botR: CGFloat = 632 - inset * 0.7
        p.move(to: CGPoint(x: topL, y: topY))
        p.addLine(to: CGPoint(x: topR, y: topY))
        p.addLine(to: CGPoint(x: botR, y: botY + 36))
        p.addQuadCurve(to: CGPoint(x: botR - 34, y: botY), control: CGPoint(x: botR - 2, y: botY))
        p.addLine(to: CGPoint(x: botL + 34, y: botY))
        p.addQuadCurve(to: CGPoint(x: botL, y: botY + 36), control: CGPoint(x: botL + 2, y: botY))
        p.closeSubpath()
        return p
    }
    ctx.addPath(glassPath(inset: 0)); ctx.setFillColor(color(0xffffff, 0.04)); ctx.fillPath()

    ctx.saveGState()
    ctx.addPath(glassPath(inset: 14)); ctx.clip()
    let surface: CGFloat = 640
    // Brew
    ctx.drawLinearGradient(gradient([0x1c0e05, 0x2f1a0a, 0x170a03]), start: CGPoint(x: 330, y: 0), end: CGPoint(x: 700, y: 0), options: [])
    ctx.saveGState()
    ctx.clip(to: CGRect(x: 0, y: 0, width: 1024, height: surface))
    ctx.setFillColor(color(0x23130a)); ctx.fill(CGRect(x: 300, y: 200, width: 440, height: surface - 200))
    ctx.drawLinearGradient(gradient([0x1c0e05, 0x34200f, 0x1c0e05]), start: CGPoint(x: 330, y: 0), end: CGPoint(x: 700, y: 0), options: [])
    // Cascade: amber streaks falling, bubbles rising (deterministic).
    var seed: UInt64 = 7
    func rnd() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat((seed >> 33) % 1000) / 1000 }
    for _ in 0..<26 {
        let x = 350 + rnd() * 330, y = 260 + rnd() * 360, w = 6 + rnd() * 10, h = 40 + rnd() * 120
        ctx.setFillColor(color(0xd99b4a, 0.12 + 0.28 * rnd()))
        ctx.fillEllipse(in: CGRect(x: x, y: y, width: w, height: h))
    }
    for _ in 0..<42 {
        let x = 345 + rnd() * 340, y = 250 + rnd() * 380, r = 3 + rnd() * 9
        ctx.setFillColor(color(0xe8c98f, 0.14 + 0.3 * rnd()))
        ctx.fillEllipse(in: CGRect(x: x, y: y, width: r * 2, height: r * 2))
    }
    ctx.restoreGState()
    // Foam head with a soft scalloped top.
    let foam = CGMutablePath()
    foam.addRect(CGRect(x: 280, y: surface - 8, width: 470, height: 76))
    for i in 0..<9 { let cx = 318 + CGFloat(i) * 46; foam.addEllipse(in: CGRect(x: cx - 30, y: surface + 38 + (i % 2 == 0 ? 6 : 0), width: 60, height: 52)) }
    ctx.addPath(foam); ctx.clip()
    ctx.drawLinearGradient(gradient([0xf6ecd2, 0xd9c293]), start: CGPoint(x: 0, y: surface + 100), end: CGPoint(x: 0, y: surface - 8), options: [])
    ctx.restoreGState()

    // Glass edge and a soft highlight.
    ctx.addPath(glassPath(inset: 0)); ctx.setStrokeColor(color(0xefe2c4, 0.75)); ctx.setLineWidth(15); ctx.setLineJoin(.round); ctx.strokePath()
    ctx.setStrokeColor(color(0xffffff, 0.16)); ctx.setLineWidth(10); ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: 366, y: 720)); ctx.addLine(to: CGPoint(x: 424, y: 320)); ctx.strokePath()
    ctx.restoreGState()
}

func png(px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.interpolationQuality = .high
    ctx.scaleBy(x: CGFloat(px) / 1024, y: CGFloat(px) / 1024)
    draw(ctx)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let args = CommandLine.arguments
guard args.count >= 2 else { print("usage: make_app_icon.swift <AppIcon.appiconset> [flattened.png]"); exit(1) }
let dir = URL(fileURLWithPath: args[1], isDirectory: true)
try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

var images: [[String: String]] = []
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(base)x\(base)" + (scale == 2 ? "@2x" : "") + ".png"
        try png(px: base * scale).write(to: dir.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(base)x\(base)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["version": 1, "author": "xcode"]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys]).write(to: dir.appendingPathComponent("Contents.json"))
if args.count >= 3 { try png(px: 1024).write(to: URL(fileURLWithPath: args[2])) }
print("wrote \(images.count) icons to \(dir.path)")
