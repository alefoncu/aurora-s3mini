import Foundation

@main struct ScoreTests {
    static func check(_ ok: @autoclosure () -> Bool, _ message: String) { if !ok() { print("ScoreTests FAILED: \(message)"); exit(1) } }
    static func main() {
        var s = RideScore()
        check(s.total == 0 && s.multiplier == 1, "Fresh score")
        s.add(.wheelie, points: RideScore.wheelie(metres: 10), label: "Caballito")
        check(s.chainPoints == 120 && s.multiplier == 1 && s.chainActive, "Single trick keeps x1")
        s.add(.jump, points: RideScore.jump(airTime: 0.6, height: 0.5), label: "Salto")
        check(s.multiplier == 1.5, "A second kind adds 0.5")
        s.add(.flip, points: RideScore.flips(1), label: "Flip")
        check(s.multiplier == 2, "Three kinds give x2")
        let chain = s.chainPoints
        check(chain == Int((120 + 48 + 60 + 400) * 2.0), "Chain value: \(chain)")
        // Staying busy holds the chain; going idle banks it after the window.
        s.tick(dt: 1, busy: true); s.tick(dt: 1, busy: true); s.tick(dt: 1, busy: true)
        check(s.banked == 0 && s.chainActive, "Busy keeps the chain open")
        for _ in 0..<30 { s.tick(dt: 0.1, busy: false) }
        check(s.banked == chain && s.pending == 0 && s.multiplier == 1, "Idle chain banks its points")
        let banked = s.total
        // Crashing with an open chain loses only the pending points.
        s.add(.stoppie, points: RideScore.stoppie(metres: 3), label: "Invertido")
        s.crash()
        check(s.total == banked && s.lostToCrash == 90, "Crash loses pending points only (lost \(s.lostToCrash))")
        // Short hops and invalid values give nothing.
        check(RideScore.jump(airTime: 0.2, height: 1) == 0 && RideScore.flips(-3) == 0 && RideScore.wheelie(metres: -4) == 0, "No credit for tiny hops")
        var t = RideScore(); t.add(.cone, points: .nan, label: "x"); t.add(.cone, points: -5, label: "x"); t.add(.cone, points: .infinity, label: "x")
        t.tick(dt: .nan, busy: false); t.tick(dt: -1, busy: false)
        check(t.total == 0 && t.popups.isEmpty, "Invalid points are ignored")
        t.add(.cone, points: RideScore.coneDodge, label: "Cono esquivado"); t.finishRun()
        check(t.total == 30 && !t.chainActive, "finishRun banks")
        for i in 0..<5 { t.add(.cone, points: 10, label: "c\(i)") }
        check(t.popups.count == 3, "Only the latest popups are kept")
        for _ in 0..<30 { t.tick(dt: 0.1, busy: true) }
        check(t.popups.isEmpty, "Popups fade")

        // Progression: coins unlock items, veterans keep everything.
        let suite = "wheelie.progress." + UUID().uuidString
        let prefs = UserDefaults(suiteName: suite)!
        let p = RideProgress(preferences: prefs)
        check(p.wallet == RideProgress.startingCoins, "Starting coins")
        check(p.isUnlocked(.vehicle(.commuter)) && p.isUnlocked(.route(1)) && !p.isUnlocked(.vehicle(.hyperbike)) && !p.isUnlocked(.route(3)), "Initial unlocks")
        check(!p.unlock(.vehicle(.hyperbike)) && p.wallet == 150, "Cannot buy without coins")
        check(RideProgress.reward(distanceCoins: 20, score: 1_000) == 25 && RideProgress.reward(distanceCoins: 20, score: 1_000, multiplier: 0.75) == 19 && RideProgress.reward(distanceCoins: 20, score: 1_000, multiplier: 1.25) == 31 && RideProgress.reward(distanceCoins: 20, score: 1_000, multiplier: -1) == 0, "Difficulty coin multipliers")
        check(p.unlock(.vehicle(.sport)) && p.wallet == 70 && p.isUnlocked(.vehicle(.sport)), "Buying spends coins")
        check(p.unlock(.vehicle(.sport)) && p.wallet == 70, "Buying twice is free")
        p.earn(RideProgress.reward(distanceCoins: 10, score: 1_000)); p.earn(-50); p.earn(0)
        check(p.wallet == 85, "Rewards: \(p.wallet)")
        let again = RideProgress(preferences: prefs)
        check(again.wallet == 85 && again.isUnlocked(.vehicle(.sport)), "Progress persists")
        // Cosmetic styles: free defaults, priced extras, bought once with coins and remembered.
        check(RideUnlock.helmet(.standard).cost == 0 && RideUnlock.jacket(.standard).cost == 0 && RideUnlock.livery(.none).cost == 0, "Defaults are free")
        check(HelmetStyle.allCases.dropFirst().allSatisfy { $0.cost > 0 } && JacketStyle.allCases.dropFirst().allSatisfy { $0.cost > 0 } && Livery.allCases.dropFirst().allSatisfy { $0.cost > 0 }, "Extras cost coins")
        let keys = HelmetStyle.allCases.map { RideUnlock.helmet($0).key } + JacketStyle.allCases.map { RideUnlock.jacket($0).key } + Livery.allCases.map { RideUnlock.livery($0).key } + BikeKind.allCases.map { RideUnlock.vehicle($0).key }
        check(Set(keys).count == keys.count, "Every unlock has its own key")
        check(RideUnlock.helmet(.flames).title.contains("llamas") && RideUnlock.livery(.number).title.contains("dorsal"), "Readable unlock titles")
        let before = p.wallet
        check(p.isUnlocked(.helmet(.standard)) && !p.isUnlocked(.helmet(.flames)), "Extras start locked")
        check(p.unlock(.helmet(.flames)) && p.wallet == before - HelmetStyle.flames.cost && p.isUnlocked(.helmet(.flames)), "Buying a helmet style spends its price")
        check(RideProgress(preferences: prefs).isUnlocked(.helmet(.flames)) && !RideProgress(preferences: prefs).isUnlocked(.helmet(.gold)), "Styles persist and stay separate")
        check(!p.unlock(.livery(.checker)) || p.wallet >= 0, "Wallet never goes negative")
        let vetSuite = "wheelie.veteran." + UUID().uuidString
        let vet = UserDefaults(suiteName: vetSuite)!; vet.set(120.0, forKey: "v5.hyperbike.2.distance")
        let old = RideProgress(preferences: vet)
        check(old.isUnlocked(.vehicle(.hyperbike)) && old.isUnlocked(.route(4)), "Existing players keep everything")
        prefs.removePersistentDomain(forName: suite); vet.removePersistentDomain(forName: vetSuite)
        print("ScoreTests passed: chains and multipliers, crash risk, banking, popups, invalid input, coins, unlocks and veteran migration.")
    }
}
