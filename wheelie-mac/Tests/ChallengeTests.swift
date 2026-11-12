import Foundation

@main struct ChallengeTests {
    static func frame(_ t: Double, x: Double? = nil, pitch: Double = 0) -> RideGhostFrame {
        let x = x ?? t * 2
        return RideGhostFrame(time: t, x: x, y: 0.6, pitch: pitch,
            rearWheelX: x, rearWheelY: 0.3, frontWheelX: x + 1.4, frontWheelY: 0.3,
            wheelRotation: t * 4, speed: 2)
    }
    static func update(_ s: RideChallengeSession, _ t: Double, wheelie: Double = 0,
                       stoppie: Double = 0, airborne: Bool = false, height: Double = 0, crashed: Bool = false) {
        s.update(frame: frame(t), distance: t * 2, wheelie: wheelie, stoppie: stoppie,
            airborne: airborne, height: height, crashed: crashed)
    }
    static func run(_ s: RideChallengeSession, duration: Double, context: String = "sport.0.stock.cones0", finished: Bool = true) {
        s.start(contextKey: context, initialFrame: frame(0))
        for i in 1...Int(duration * 20) { update(s, Double(i) / 20) }
        s.finish(routeCompleted: finished, elapsed: duration)
    }
    static func main() {
        let domain = "com.scratch.wheelie.challenges.test." + UUID().uuidString
        let prefs = UserDefaults(suiteName: domain)!
        defer { prefs.removePersistentDomain(forName: domain) }
        let s = RideChallengeSession(preferences: prefs)
        s.selected = .wheelie
        s.start(contextKey: "street.0", initialFrame: frame(0))
        update(s, 1, wheelie: 14.9)
        precondition(!s.completed && s.progress < 1)
        update(s, 2, wheelie: 15)
        precondition(s.completed && !s.previouslyCompleted)
        s.abandon()
        s.load(contextKey: "street.0")
        precondition(!s.previouslyCompleted, "Restarting a run must not award a challenge")
        s.start(contextKey: "street.0", initialFrame: frame(0))
        update(s, 1, wheelie: 15)
        s.finish(routeCompleted: false, elapsed: 1)
        let reloaded = RideChallengeSession(preferences: prefs)
        reloaded.selected = .wheelie; reloaded.load(contextKey: "street.0")
        precondition(reloaded.previouslyCompleted && reloaded.ghost == nil, "Natural crash can save an earned stunt but never a ghost")
        reloaded.load(contextKey: "street.1")
        precondition(!reloaded.previouslyCompleted, "Goals must stay scoped to the course/settings")

        s.selected = .stoppie; s.start(contextKey: "street.0", initialFrame: frame(0))
        update(s, 1, stoppie: 2.99); precondition(!s.completed)
        update(s, 2, stoppie: 3); precondition(s.completed)
        s.selected = .jump
        s.start(contextKey: "street.0", initialFrame: frame(0))
        update(s, 1, airborne: true, height: 0.26)
        precondition(!s.completed, "Jump must include a safe landing")
        update(s, 2, crashed: true)
        precondition(!s.completed)
        s.start(contextKey: "street.0", initialFrame: frame(0))
        update(s, 1, airborne: true, height: 0.26)
        update(s, 2)
        precondition(s.completed && s.progress == 1)
        s.finish(routeCompleted: false, elapsed: 2)
        s.load(contextKey: "street.0")
        precondition(s.previouslyCompleted)

        s.selected = .timeTrial
        run(s, duration: 240)
        precondition(s.completed && s.ghost?.duration == 240)
        run(s, duration: 241)
        precondition(!s.completed && s.ghost?.duration == 240, "Slow finishes must retain the faster ghost")
        run(s, duration: 12, finished: false)
        precondition(s.ghost?.duration == 240)
        run(s, duration: 100)
        precondition(s.savedNewGhost && s.ghost?.duration == 100)
        let before = s.ghost
        s.start(contextKey: "sport.0.stock.cones0", initialFrame: frame(0))
        update(s, 0.05)
        precondition(s.ghost?.duration == before?.duration, "Recording must not replace the previous ghost mid-run")
        let ghost = s.ghostFrame(at: 3.125)!
        precondition(abs(ghost.x - 6.25) < 1e-8 && abs(ghost.wheelRotation - 12.5) < 1e-8,
            "Ghost must interpolate by time, including wheel rotation")
        precondition(s.ghostFrame(at: -1) == nil && s.ghostFrame(at: .nan) == nil && s.ghostFrame(at: 101) == nil)
        let disk = RideChallengeSession(preferences: prefs)
        disk.load(contextKey: "sport.0.stock.cones0")
        precondition(disk.ghost?.duration == 100 && disk.ghost!.frames.count <= 1_002)
        disk.load(contextKey: "sport.0.stock.cones1")
        precondition(disk.ghost == nil, "Cones and setup configurations must isolate ghosts")

        run(s, duration: 601, context: "long")
        precondition(s.ghost == nil, "A run beyond the recording cap must not save a truncated ghost")
        prefs.set(Data("invalid json".utf8), forKey: "v6.ghost.corrupt")
        disk.load(contextKey: "corrupt"); precondition(disk.ghost == nil)
        let duplicate = RideGhostRun(version: 1, contextKey: "duplicate", duration: 1, frames: [frame(0), frame(0), frame(1)])
        prefs.set(try! JSONEncoder().encode(duplicate), forKey: "v6.ghost.duplicate")
        disk.load(contextKey: "duplicate"); precondition(disk.ghost == nil)
        let oversized = Data(repeating: 0, count: RideGhostRun.maximumDataBytes + 1)
        prefs.set(oversized, forKey: "v6.ghost.oversized")
        disk.load(contextKey: "oversized"); precondition(disk.ghost == nil)
        s.selected = .wheelie; s.start(contextKey: "invalid", initialFrame: frame(0))
        update(s, .nan, wheelie: 100)
        precondition(!s.completed && s.progress == 0)
        update(s, 1, wheelie: 15)
        s.finish(routeCompleted: true, elapsed: .nan)
        precondition(!s.previouslyCompleted && s.ghost == nil)
        // Ghost time at a world position and live delta for per-sector comparison.
        let timed = RideGhostRun(version: 1, contextKey: "t", duration: 10, frames: (0...10).map { frame(Double($0)) })
        precondition(timed.time(atDistance: 10) == 5 && abs(timed.time(atDistance: 5)! - 2.5) < 1e-9)
        precondition(timed.time(atDistance: -1) == nil && timed.time(atDistance: 1_000) == nil && timed.time(atDistance: .nan) == nil)
        let cmp = RideChallengeSession(preferences: UserDefaults(suiteName: "wheelie.ghosttime." + UUID().uuidString)!)
        precondition(cmp.timeDelta(elapsed: 5, atDistance: 10) == nil, "No ghost, no delta")
        print("ChallengeTests passed: goals and safe landing, abandonment, scoped persistence, faster completed ghosts, timed interpolation, recording cap and corrupt-data rejection.")
    }
}
