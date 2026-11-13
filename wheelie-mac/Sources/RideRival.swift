import Foundation

enum RivalLevel: Int, CaseIterable {
    case easy, normal, expert
    /// The field for a multi-rival race: three rivals around the chosen level.
    func field() -> [RivalLevel] {
        switch self { case .easy: return [.easy, .easy, .normal]; case .normal: return [.easy, .normal, .expert]; case .expert: return [.normal, .expert, .expert] }
    }
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
    static var releaseRotation = 3.4
    static var landingMargin = 0.45
    /// Routes where the expert flips. All of them: on rough dirt the flight is shorter, so a flip
    /// is abandoned (the bike levels itself) whenever there is not enough air left to finish it.
    var flipRoutes=[0,1,2,3,4]
    private var flipCooldown=0.0
    private(set) var crashedByMistake = false

    init(level: RivalLevel, kind: BikeKind, route: Int, hazards: Bool, seed: UInt64, laps: Int = 3) {
        self.level = level
        rng = seed &* 6364136223846793005 &+ 1
        mistakeIn = 0
        bike.kind = kind; bike.route = route; bike.hazards = hazards; bike.laps = laps
        bike.assist = .normal
        bike.reset()
        mistakeIn = nextInterval()
    }
    var finished: Bool { bike.finished }
    var crashed: Bool { bike.crashed }
    /// Seconds until the rear wheel meets the ground, from its height and vertical speed, iterating
    /// twice on where it will land (the terrain moves with the bike's forward speed).
    func remainingAirTime() -> Double {
        let g = 9.81, vy = bike.verticalVelocity, rig = bike.kind.rig
        var t = 0.3
        for _ in 0..<3 {
            let floorY = BikePhysics.ground(bike.rearWheelPosition.x + bike.speed * t, route: bike.route, lane: bike.lane) + rig.wheelRadius
            let h = max(0, bike.rearWheelPosition.y - floorY)
            t = max(0, (vy + (vy * vy + 2 * g * h).squareRoot()) / g)
        }
        return t
    }
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
        mistakeIn -= dt; flipCooldown = max(0, flipCooldown - dt)
        if lapse > 0 {
            lapse -= dt
            switch lapseKind { case 0: throttle = false; case 1: back = true; forward = false; default: forward = true; back = false }
            if lapse <= 0 { mistakeIn = nextInterval() }
        } else if mistakeIn <= 0 && !bike.crashed {
            lapse = 0.4 + random() * 0.5; lapseKind = Int(random() * 3) % 3
        }
        var jump = false, trick = false
        let air = !bike.rearContact && !bike.frontContact
        if level.doesTricks && lapse <= 0 && flipRoutes.contains(bike.route) {
            // Jump off a rising ramp and flip: hold T until the half-turn, then release to land.
            // A genuine ramp rises at least half a metre within five metres; bumps on rough dirt do not count.
            let rise = BikePhysics.ground(bike.x + 5, route: bike.route, lane: bike.lane) - BikePhysics.ground(bike.x, route: bike.route, lane: bike.lane)
            let onRamp = !air && flipCooldown <= 0 && bike.speed > 7 && BikePhysics.slope(bike.x, route: bike.route, lane: bike.lane) > 0.15 && rise > 0.3 && bike.x > 250
            if onRamp && !rampSeen { rampSeen = true; wantsFlip = random() < Self.flipChance }
            if !onRamp && !air { rampSeen = false }
            if onRamp && wantsFlip { wantsFlip = false; flipCooldown = 6; jump = true; trick = true; flipRelease = false; flipPlanned = true }
            if air && flipPlanned && !flipRelease {
                // Too little air left to finish the turn? Let go now: the bike levels itself for landing.
                let rotation = abs(bike.airRotation)
                let needed = rotation < Self.releaseRotation ? (Self.releaseRotation - rotation) / 6 + Self.landingMargin : 0
                if rotation < Self.releaseRotation && remainingAirTime() > needed { trick = true; forward = true; back = false; brake = false } else { flipRelease = true }
            }
        }
        if air && !trick { brake = false }
        bike.update(dt, throttle: throttle, brake: brake && !air, leanBack: back, leanForward: forward, jump: jump, trick: trick)
        if !air && !jump { flipRelease = false; if bike.airTime == 0 { flipPlanned = false } }
    }
}
