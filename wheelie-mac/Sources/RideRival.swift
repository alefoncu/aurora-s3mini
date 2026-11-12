import Foundation

enum RivalLevel: Int, CaseIterable {
    case easy, normal, expert
    var title: String { ["Rival fácil", "Rival normal", "Rival experto"][rawValue] }
    func baseSpeed(paved: Bool) -> Double {
        switch self { case .easy: return paved ? 13.5 : 10.5; case .normal: return paved ? 16 : 12; case .expert: return paved ? 17.5 : 13 }
    }
    /// Average seconds between mistakes.
    var mistakeInterval: Double { [14, 40, 110][rawValue] }
    var doesTricks: Bool { self == .expert }
}

/// A rival with the player's physics. It rides like the cautious test pilot, makes the odd
/// human mistake (a lifted throttle or a bad weight shift) and, at expert level, flips off ramps.
final class RideRival {
    let bike = BikePhysics()
    let level: RivalLevel
    private var rng: UInt64
    private var mistakeIn: Double
    private var lapse = 0.0, lapseKind = 0
    private var flipRelease = false, flipPlanned = false, rampSeen = false, wantsFlip = false
    static var flipChance = 0.3
    private(set) var crashedByMistake = false

    init(level: RivalLevel, kind: BikeKind, route: Int, hazards: Bool, seed: UInt64) {
        self.level = level
        rng = seed &* 6364136223846793005 &+ 1
        mistakeIn = 0
        bike.kind = kind; bike.route = route; bike.hazards = hazards; bike.reset()
        mistakeIn = nextInterval()
    }
    var finished: Bool { bike.finished }
    var crashed: Bool { bike.crashed }
    private func random() -> Double { rng = rng &* 6364136223846793005 &+ 1442695040888963407; return Double(rng >> 11) / Double(1 << 53) }
    private func nextInterval() -> Double { level.mistakeInterval * (0.5 + random()) }

    func update(_ dt: Double) {
        guard dt.isFinite, dt > 0, !bike.finished else { return }
        let stage = Double(BikePhysics.difficultyStage(at: bike.x))
        let paved = bike.route == 0 || bike.route == 4
        let target = min(bike.kind.topSpeed * 0.85, level.baseSpeed(paved: paved) - stage * 1.2)
        var throttle = bike.speed < target
        var brake = bike.speed > target + 0.6
        var back = bike.angle < -0.25, forward = bike.angle > 0.25
        mistakeIn -= dt
        if lapse > 0 {
            lapse -= dt
            switch lapseKind { case 0: throttle = false; case 1: back = true; forward = false; default: forward = true; back = false }
            if lapse <= 0 { mistakeIn = nextInterval() }
        } else if mistakeIn <= 0 && !bike.crashed {
            lapse = 0.4 + random() * 0.5; lapseKind = Int(random() * 3) % 3
        }
        var jump = false, trick = false
        let air = !bike.rearContact && !bike.frontContact
        // Rough dirt and dune ramps land too unpredictably: the rival only flips on smooth routes.
        if level.doesTricks && lapse <= 0 && [0, 3, 4].contains(bike.route) {
            // Jump off a rising ramp and flip: hold T until the half-turn, then release to land.
            let onRamp = !air && bike.speed > 7 && BikePhysics.slope(bike.x, route: bike.route) > 0.15 && bike.x > 250
            if onRamp && !rampSeen { rampSeen = true; wantsFlip = random() < Self.flipChance }
            if !onRamp && !air { rampSeen = false }
            if onRamp && wantsFlip { wantsFlip = false; jump = true; trick = true; flipRelease = false; flipPlanned = true }
            if air && flipPlanned && !flipRelease {
                if abs(bike.airRotation) < 3.4 { trick = true; forward = true; back = false; brake = false } else { flipRelease = true }
            }
        }
        if air && !trick { brake = false }
        bike.update(dt, throttle: throttle, brake: brake && !air, leanBack: back, leanForward: forward, jump: jump, trick: trick)
        if !air && !jump { flipRelease = false; if bike.airTime == 0 { flipPlanned = false } }
    }
}
