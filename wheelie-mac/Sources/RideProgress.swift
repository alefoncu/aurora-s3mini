import Foundation

/// Coins earned while riding unlock vehicles and routes. Everything is stored in
/// the app's own preferences; nothing leaves the Mac.
enum RideUnlock: Hashable {
    case vehicle(BikeKind), route(Int), helmet(HelmetStyle), jacket(JacketStyle), livery(Livery)
    var key: String {
        switch self {
        case .vehicle(let k): return "vehicle." + k.rawValue
        case .route(let r): return "route.\(r)"
        case .helmet(let s): return "helmet.\(s.rawValue)"
        case .jacket(let s): return "jacket.\(s.rawValue)"
        case .livery(let s): return "livery.\(s.rawValue)"
        }
    }
    var cost: Int {
        switch self {
        case .vehicle(let k):
            switch k { case .commuter, .motocross, .bmx: return 0; case .scooter: return 40; case .sport, .scrambler: return 80; case .trials: return 100; case .cruiser: return 120; case .electric: return 150; case .hyperbike: return 220 }
        case .route(let r):
            switch r { case 0, 1: return 0; case 2: return 60; default: return 100 }
        case .helmet(let s): return s.cost
        case .jacket(let s): return s.cost
        case .livery(let s): return s.cost
        }
    }
    var title: String {
        switch self {
        case .vehicle(let k): return k.title
        case .route(let r): return BikePhysics.routeNames[max(0, min(BikePhysics.routeCount - 1, r))]
        case .helmet(let s): return "casco \(s.title.lowercased())"
        case .jacket(let s): return "chaqueta \(s.title.lowercased())"
        case .livery(let s): return "decoración «\(s.title.lowercased())»"
        }
    }
}

final class RideProgress {
    static let startingCoins = 150
    private let prefs: UserDefaults
    private var unlocked: Set<String>
    private(set) var wallet: Int

    init(preferences: UserDefaults) {
        prefs = preferences
        if preferences.object(forKey: "progress.wallet") == nil {
            // Players who already have records keep everything they used before.
            let veteran = preferences.dictionaryRepresentation().keys.contains { $0.hasPrefix("v5.") || $0.hasPrefix("v6.") }
            wallet = Self.startingCoins
            unlocked = []
            if veteran { for k in BikeKind.allCases { unlocked.insert(RideUnlock.vehicle(k).key) }; for r in 0..<BikePhysics.routeCount { unlocked.insert(RideUnlock.route(r).key) } }
            save()
        } else {
            wallet = max(0, preferences.integer(forKey: "progress.wallet"))
            unlocked = Set(preferences.stringArray(forKey: "progress.unlocked") ?? [])
        }
    }
    private func save() { prefs.set(wallet, forKey: "progress.wallet"); prefs.set(Array(unlocked).sorted(), forKey: "progress.unlocked") }
    func isUnlocked(_ item: RideUnlock) -> Bool { item.cost == 0 || unlocked.contains(item.key) }
    func canAfford(_ item: RideUnlock) -> Bool { wallet >= item.cost }
    /// Spend coins to unlock an item; false (and no change) when locked behind more coins.
    @discardableResult func unlock(_ item: RideUnlock) -> Bool {
        if isUnlocked(item) { return true }
        guard canAfford(item) else { return false }
        wallet -= item.cost; unlocked.insert(item.key); save(); return true
    }
    func earn(_ coins: Int) { guard coins > 0 else { return }; wallet = min(wallet + coins, 1_000_000); save() }
    func unlockEverything() {
        for k in BikeKind.allCases { unlocked.insert(RideUnlock.vehicle(k).key) }
        for r in 0..<BikePhysics.routeCount { unlocked.insert(RideUnlock.route(r).key) }
        save()
    }
    /// Coins for a finished run: distance coins plus one per 200 points.
    static func reward(distanceCoins: Int, score: Int, multiplier: Double = 1) -> Int {
        Int((Double(max(0, distanceCoins) + max(0, score) / 200) * max(0, multiplier)).rounded())
    }
}
