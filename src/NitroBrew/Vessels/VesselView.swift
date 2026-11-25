import SwiftUI

/// Large animated vessel: dark brew rising or draining, a gradually thickening foam head, drifting bubbles and the start-of-session cascade.
struct VesselView: View {
    let vessel: Vessel
    @ObservedObject var engine: SessionEngine
    @State private var animator = VesselAnimator()

    private static let crop = CGRect(x: 4, y: 1.5, width: 16, height: 21)

    var body: some View {
        TimelineView(.animation) { timeline in
            let frame = VesselFrame(
                date: timeline.date,
                level: engine.fillLevel,
                mode: engine.mode,
                phase: engine.phase,
                secondsSinceDone: engine.completedAt.map { timeline.date.timeIntervalSince($0) },
                cascade: CascadeModel.strength(now: timeline.date, start: engine.cascadeStart))
            Canvas { ctx, size in
                animator.advance(frame, vessel: vessel, geometry: VesselGeometry.geometry(for: vessel))
                Self.draw(&ctx, size: size, vessel: vessel, frame: frame, animator: animator)
            }
        }
        .aspectRatio(Self.crop.width / Self.crop.height, contentMode: .fit)
        .accessibilityLabel(Text("\(vessel.displayName), \(Int((engine.fillLevel * 100).rounded())) percent full"))
    }

    static func draw(_ ctx: inout GraphicsContext, size: CGSize, vessel: Vessel, frame: VesselFrame, animator: VesselAnimator) {
        let g = VesselGeometry.geometry(for: vessel)
        let s = min(size.width / crop.width, size.height / crop.height)
        ctx.translateBy(x: (size.width - crop.width * s) / 2, y: (size.height - crop.height * s) / 2)
        ctx.scaleBy(x: s, y: s)
        ctx.translateBy(x: -crop.minX, y: -crop.minY)

        let level = min(1, max(0, frame.level))
        let top = Double(g.liquidTop) - level * Double(g.liquidHeight)
        let box = g.inner.boundingBoxOfPath

        var glass = ctx
        glass.clip(to: Path(g.inner))
        glass.fill(Path(box), with: .color(.white.opacity(0.03)))

        if level > 0 {
            var liquid = glass
            let liquidRect = CGRect(x: 0, y: top, width: 24, height: Double(g.liquidHeight) * level + 2)
            liquid.clip(to: Path(liquidRect))
            liquid.fill(Path(liquidRect), with: .linearGradient(
                Gradient(colors: [Theme.roastEdge, Theme.roast, Theme.roastEdge]),
                startPoint: CGPoint(x: box.minX, y: 0), endPoint: CGPoint(x: box.maxX, y: 0)))
            if frame.phase != .idle {
                for p in animator.particles {
                    let a = p.falls ? frame.cascade * 0.55 : 0.28
                    let r = p.falls ? p.r * (0.6 + frame.cascade) : p.r
                    liquid.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)),
                                with: .color((p.falls ? Theme.amber : Theme.cream).opacity(a)))
                }
            }
        }

        let fh = animator.foam.thickness * Double(g.liquidHeight) / 250
        if fh > 0.02, level > 0 {
            var foamCtx = glass
            var wave = Path()
            let w = frame.date.timeIntervalSinceReferenceDate * 1.4
            let x0 = Double(box.minX) - 1, x1 = Double(box.maxX) + 1
            wave.move(to: CGPoint(x: x0, y: top - fh))
            var x = x0
            while x <= x1 {
                wave.addLine(to: CGPoint(x: x, y: top - fh + sin(x * 1.1 + w) * 0.11))
                x += 0.5
            }
            wave.addLine(to: CGPoint(x: x1, y: top + 0.2))
            wave.addLine(to: CGPoint(x: x0, y: top + 0.2))
            wave.closeSubpath()
            foamCtx.opacity = min(1, fh / 0.3)
            foamCtx.fill(wave, with: .linearGradient(
                Gradient(colors: [Theme.foamTop, Theme.foamBottom]),
                startPoint: CGPoint(x: 0, y: top - fh), endPoint: CGPoint(x: 0, y: top)))
        }

        var sheen = glass
        sheen.fill(Path(box), with: .linearGradient(
            Gradient(colors: [.white.opacity(0.14), .clear, .clear, .white.opacity(0.06)]),
            startPoint: CGPoint(x: box.minX, y: 0), endPoint: CGPoint(x: box.maxX, y: 0)))

        ctx.stroke(Path(g.outline), with: .color(Theme.cream.opacity(0.55)),
                   style: StrokeStyle(lineWidth: 2.5 / s, lineCap: .round, lineJoin: .round))
        if let wdg = g.widget {
            let r = 1.1
            ctx.stroke(Path(ellipseIn: CGRect(x: wdg.x - r, y: wdg.y - r, width: 2 * r, height: 2 * r)),
                       with: .color(Theme.cream.opacity(0.55)), lineWidth: 1.5 / s)
        }
    }
}
