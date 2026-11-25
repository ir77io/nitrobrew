import AppKit

enum MenuBarIconRenderer {
    /// Template image of the vessel filled to `level` (clamped to 0...1).
    static func image(vessel: Vessel, level: Double, pointSize: CGFloat = 18) -> NSImage {
        let l = level.isFinite ? min(1, max(0, level)) : 0
        let g = VesselGeometry.geometry(for: vessel)
        let image = NSImage(size: NSSize(width: pointSize, height: pointSize), flipped: true) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let s = pointSize / 24
            ctx.scaleBy(x: s, y: s)
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.setStrokeColor(NSColor.black.cgColor)
            let top = g.liquidTop - CGFloat(l) * g.liquidHeight

            if l > 0 {
                ctx.saveGState()
                ctx.addPath(g.outline)
                ctx.clip()
                ctx.fill(CGRect(x: 0, y: top, width: 24, height: CGFloat(l) * g.liquidHeight + 2))
                ctx.restoreGState()
            }

            ctx.setLineWidth(1.6)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.addPath(g.outline)
            ctx.strokePath()

            if g.hasFoam, l > 0.04 {
                ctx.saveGState()
                ctx.addPath(g.outline)
                ctx.clip()
                ctx.setFillColor(NSColor.black.withAlphaComponent(0.55).cgColor)
                for (x, dy, r) in [(8.8, -0.1, 1.2), (12.0, -0.7, 1.5), (15.2, -0.1, 1.2)] as [(CGFloat, CGFloat, CGFloat)] {
                    ctx.fillEllipse(in: CGRect(x: x - r, y: top + dy - r, width: 2 * r, height: 2 * r))
                }
                ctx.restoreGState()
            }
            if let w = g.widget {
                let r: CGFloat = 1.1
                let rect = CGRect(x: w.x - r, y: w.y - r, width: 2 * r, height: 2 * r)
                ctx.setBlendMode(.clear)
                ctx.fillEllipse(in: rect)
                ctx.setBlendMode(.normal)
                ctx.setLineWidth(1)
                ctx.strokeEllipse(in: rect)
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
