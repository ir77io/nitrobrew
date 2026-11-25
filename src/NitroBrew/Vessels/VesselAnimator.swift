import CoreGraphics
import Foundation

/// Everything the animation needs for one frame, captured on the main actor.
struct VesselFrame {
    var date: Date
    var level: Double
    var mode: SessionMode
    var phase: SessionPhase
    var secondsSinceDone: TimeInterval?
    var cascade: Double
}

/// Reference-type state for the animated vessel: foam easing and drifting bubbles. Space is the 24x24 geometry space.
final class VesselAnimator {
    struct Particle {
        var x: Double, y: Double, r: Double, v: Double, phase: Double
        var falls: Bool
    }

    private(set) var foam = FoamModel()
    private(set) var particles: [Particle] = []
    private var vessel: Vessel?
    private var lastDate: Date?

    func advance(_ f: VesselFrame, vessel v: Vessel, geometry g: VesselGeometry) {
        if vessel != v { configure(v, g) }
        let dt = min(0.1, max(0, lastDate.map { f.date.timeIntervalSince($0) } ?? 0))
        lastDate = f.date
        foam.update(level: f.level, mode: f.mode, phase: f.phase, secondsSinceDone: f.secondsSinceDone, dt: dt)

        let box = g.inner.boundingBoxOfPath
        let surface = Double(g.liquidTop) - f.level * Double(g.liquidHeight)
        let bottom = Double(g.liquidTop)
        let moving = f.phase == .running
        for i in particles.indices {
            var p = particles[i]
            if moving {
                if p.falls {
                    p.y += (f.cascade > 0.02 ? 8 + p.v * 14 : p.v * 2) * dt
                    p.x += sin(f.date.timeIntervalSinceReferenceDate * 2.5 + p.phase) * 0.4 * dt
                } else {
                    p.y -= p.v * 3.2 * dt
                    p.x += sin(f.date.timeIntervalSinceReferenceDate * 1.1 + p.phase) * 0.3 * dt
                }
            }
            if p.y > bottom { p.y = surface }
            if p.y < surface {
                p.y = bottom - Double.random(in: 0...1.2)
                p.x = Double.random(in: Double(box.minX) + 1.5...Double(box.maxX) - 1.5)
            }
            particles[i] = p
        }
    }

    private func configure(_ v: Vessel, _ g: VesselGeometry) {
        vessel = v
        let box = g.inner.boundingBoxOfPath
        particles = (0..<46).map { i in
            Particle(x: Double.random(in: Double(box.minX) + 1.5...Double(box.maxX) - 1.5),
                     y: Double.random(in: Double(box.minY)...Double(g.liquidTop)),
                     r: 0.06 + Double.random(in: 0...0.17), v: 0.15 + Double.random(in: 0...0.35),
                     phase: Double.random(in: 0...6), falls: i % 3 == 0)
        }
    }
}
