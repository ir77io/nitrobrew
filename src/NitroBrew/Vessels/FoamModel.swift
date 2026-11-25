import Foundation

/// Foam head thickness in viewBox units of the 290-high vessel space.
/// Grows with fill level (full head by 45%), then eases toward its target every frame so it never jumps.
struct FoamModel {
    private(set) var thickness: Double = 0

    static func target(level: Double, mode: SessionMode, phase: SessionPhase, secondsSinceDone: TimeInterval?) -> Double {
        let l = min(1, max(0, level.isFinite ? level : 0))
        let x = min(1, l / 0.45)
        let k = x * x * (3 - 2 * x)
        if mode.isWork {
            if phase == .done {
                let settled = (secondsSinceDone ?? 0) >= 2.5
                return (settled ? 13 : 22) * k
            }
            return 20 * k
        }
        return (10 + 8 * l) * k
    }

    mutating func update(level: Double, mode: SessionMode, phase: SessionPhase, secondsSinceDone: TimeInterval?, dt: TimeInterval) {
        let goal = Self.target(level: level, mode: mode, phase: phase, secondsSinceDone: secondsSinceDone)
        let step = max(0, dt.isFinite ? dt : 0)
        let factor = 1 - pow(1 - 0.04, step * 60)
        thickness += (goal - thickness) * factor
    }
}
