import Foundation

/// Trick scoring with chained multipliers. Points of the current chain stay
/// "pending" while the rider keeps tricking; once the chain ends cleanly they
/// are banked, but a crash while a chain is open loses them.
struct RideScore {
    enum Trick: Int, CaseIterable { case wheelie, stoppie, jump, flip, cone, noHands, spin, superman, overtake }
    struct Popup { let text: String; let points: Int; var age: Double }

    static let chainWindow = 2.5
    private(set) var banked = 0
    private(set) var pending = 0.0
    private(set) var kinds = Set<Trick>()
    private(set) var events = 0
    private(set) var chainTimer = 0.0
    private(set) var bestChain = 0
    private(set) var lostToCrash = 0
    private(set) var popups: [Popup] = []

    /// 1x for a single trick, +0.5 for every additional kind, +0.1 per extra event (max +1).
    var multiplier: Double { 1 + 0.5 * Double(max(0, kinds.count - 1)) + min(1, 0.1 * Double(max(0, events - kinds.count))) }
    var chainPoints: Int { Int(pending * multiplier) }
    var total: Int { banked + chainPoints }
    var chainActive: Bool { pending > 0 && chainTimer > 0 }

    mutating func reset() { self = RideScore() }

    /// Register points for one trick. Non-finite or non-positive values are ignored.
    mutating func add(_ trick: Trick, points: Double, label: String) {
        guard points.isFinite, points > 0 else { return }
        pending += points; events += 1; kinds.insert(trick); chainTimer = Self.chainWindow
        bestChain = max(bestChain, chainPoints)
        popups.append(Popup(text: label, points: Int(points * multiplier), age: 0))
        if popups.count > 3 { popups.removeFirst() }
    }
    /// Continuous scoring (metres of wheelie, ...): keeps the chain alive and joins its kinds
    /// without counting as a separate event or showing a popup every frame.
    mutating func accrue(_ trick: Trick, points: Double) {
        guard points.isFinite, points > 0 else { return }
        pending += points; kinds.insert(trick); chainTimer = Self.chainWindow
        bestChain = max(bestChain, chainPoints)
    }
    /// `busy` is true while a wheelie, invertido or flight is still in progress.
    mutating func tick(dt: Double, busy: Bool) {
        guard dt.isFinite, dt > 0 else { return }
        for i in popups.indices { popups[i].age += dt }
        popups.removeAll { $0.age > 2.2 }
        guard pending > 0 else { return }
        if busy { chainTimer = Self.chainWindow; return }
        chainTimer -= dt
        if chainTimer <= 0 { bank() }
    }
    mutating func bank() {
        banked += chainPoints
        pending = 0; kinds.removeAll(); events = 0; chainTimer = 0
    }
    /// A crash with an open chain loses the pending points: the risk of tricks.
    mutating func crash() {
        lostToCrash += chainPoints
        pending = 0; kinds.removeAll(); events = 0; chainTimer = 0
    }
    mutating func finishRun() { bank() }

    // Point values shared by the game and the tests.
    static func wheelie(metres: Double) -> Double { max(0, metres) * 12 }
    static func stoppie(metres: Double) -> Double { max(0, metres) * 30 }
    static func jump(airTime: Double, height: Double) -> Double { airTime >= 0.35 ? airTime * 80 + max(0, height) * 120 : 0 }
    static func flips(_ count: Int) -> Double { Double(max(0, count)) * 400 }
    static let coneDodge = 30.0
    static let overtake = 80.0
    static func noHands(seconds: Double) -> Double { max(0, seconds) * 40 }
    static func spins(_ count: Int) -> Double { Double(max(0, count)) * 350 }
    static func superman(seconds: Double) -> Double { seconds >= 0.4 ? 200 + 80 * seconds : 0 }
}
