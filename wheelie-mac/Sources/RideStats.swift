import Foundation

/// What a finished (or abandoned) run produced. Missions and achievements both read it.
struct RunReport {
    var distance = 0.0, wheelieMetres = 0.0, stoppieMetres = 0.0, airTime = 0.0
    var score = 0, bestCombo = 0
    var flips = 0, spins = 0, jumps = 0, dodges = 0, supermans = 0
    var noHandsSeconds = 0.0
    var finished = false, crashed = false, endless = false, raceWon = false
}

/// Keep persisted and incoming counters nonnegative, finite, and safe to add/display.
private func progressValue(_ value: Double) -> Double {
    value.isFinite ? min(max(0, value), Double(Int.max).nextDown) : 0
}
private func progressSum(_ a: Int, _ b: Int) -> Int {
    let (sum, overflow) = max(0, a).addingReportingOverflow(max(0, b))
    return overflow ? Int.max : sum
}

/// Lifetime totals, stored as JSON in the app's preferences.
struct RideTotals: Codable, Equatable {
    var runs = 0, crashes = 0, finishes = 0, raceWins = 0, flips = 0, spins = 0, jumps = 0, dodges = 0, supermans = 0
    var distance = 0.0, wheelieMetres = 0.0, stoppieMetres = 0.0, airTime = 0.0, noHandsSeconds = 0.0
    var bestCombo = 0, bestScore = 0
    var bestEndless = 0.0
    var tutorialDone = false
    var coinsEarned = 0

    fileprivate var sanitized: RideTotals {
        var result = self
        for key in [\RideTotals.runs, \.crashes, \.finishes, \.raceWins, \.flips, \.spins, \.jumps, \.dodges, \.supermans, \.bestCombo, \.bestScore, \.coinsEarned] {
            result[keyPath: key] = max(0, result[keyPath: key])
        }
        for key in [\RideTotals.distance, \.wheelieMetres, \.stoppieMetres, \.airTime, \.noHandsSeconds, \.bestEndless] {
            result[keyPath: key] = progressValue(result[keyPath: key])
        }
        return result
    }
}

struct RideAchievement {
    let id: String, title: String, detail: String, reward: Int
    let isEarned: (RideTotals) -> Bool
    static let all: [RideAchievement] = [
        RideAchievement(id: "first-finish", title: "Primera meta", detail: "Completa una ruta.", reward: 20) { $0.finishes >= 1 },
        RideAchievement(id: "ten-runs", title: "De rodaje", detail: "Sal a rodar 10 veces.", reward: 20) { $0.runs >= 10 },
        RideAchievement(id: "ten-km", title: "10 km", detail: "Recorre 10.000 m en total.", reward: 40) { $0.distance >= 10_000 },
        RideAchievement(id: "wheelie-500", title: "Caballito de fondo", detail: "500 m de caballito acumulados.", reward: 30) { $0.wheelieMetres >= 500 },
        RideAchievement(id: "stoppie-100", title: "Invertido de fondo", detail: "100 m de invertido acumulados.", reward: 30) { $0.stoppieMetres >= 100 },
        RideAchievement(id: "first-flip", title: "Primera voltereta", detail: "Aterriza una voltereta.", reward: 25) { $0.flips >= 1 },
        RideAchievement(id: "flips-25", title: "Acróbata", detail: "25 volteretas aterrizadas.", reward: 60) { $0.flips >= 25 },
        RideAchievement(id: "first-spin", title: "Giro completo", detail: "Aterriza un giro de 360°.", reward: 25) { $0.spins >= 1 },
        RideAchievement(id: "combo-1000", title: "Combo de mil", detail: "Una cadena de 1.000 puntos.", reward: 30) { $0.bestCombo >= 1_000 },
        RideAchievement(id: "combo-5000", title: "Combo de cinco mil", detail: "Una cadena de 5.000 puntos.", reward: 80) { $0.bestCombo >= 5_000 },
        RideAchievement(id: "no-hands-30", title: "Sin manos", detail: "30 s con las manos fuera del manillar.", reward: 30) { $0.noHandsSeconds >= 30 },
        RideAchievement(id: "race-5", title: "Campeón", detail: "Gana 5 carreras contra el rival.", reward: 50) { $0.raceWins >= 5 },
        RideAchievement(id: "endless-3000", title: "Maratón", detail: "3.000 m seguidos en modo infinito.", reward: 60) { $0.bestEndless >= 3_000 },
        RideAchievement(id: "tutorial", title: "Graduado", detail: "Completa el tutorial guiado.", reward: 0) { $0.tutorialDone },
    ]
}

final class RideStats {
    private let prefs: UserDefaults
    private(set) var totals: RideTotals
    private(set) var earned: Set<String>
    init(preferences: UserDefaults) {
        prefs = preferences
        if let data = preferences.data(forKey: "stats.totals"), let decoded = try? JSONDecoder().decode(RideTotals.self, from: data) { totals = decoded.sanitized } else { totals = RideTotals() }
        earned = Set(preferences.stringArray(forKey: "stats.achievements") ?? [])
    }
    private func save() {
        if let data = try? JSONEncoder().encode(totals) { prefs.set(data, forKey: "stats.totals") }
        prefs.set(Array(earned).sorted(), forKey: "stats.achievements")
    }
    /// Add one run and return the achievements it unlocked (each is returned only once, ever).
    @discardableResult func record(_ r: RunReport) -> [RideAchievement] {
        totals = Self.applying(r, to: totals)
        return unlockNew()
    }
    /// The totals after adding a run. Pure, so the game can preview achievements mid-run.
    static func applying(_ r: RunReport, to base: RideTotals) -> RideTotals {
        func clean(_ v: Double) -> Double { progressValue(v) }
        var totals = base.sanitized
        totals.runs = progressSum(totals.runs, 1)
        if r.crashed { totals.crashes = progressSum(totals.crashes, 1) }
        if r.finished { totals.finishes = progressSum(totals.finishes, 1) }
        if r.raceWon { totals.raceWins = progressSum(totals.raceWins, 1) }
        totals.flips = progressSum(totals.flips, max(0, r.flips)); totals.spins = progressSum(totals.spins, max(0, r.spins)); totals.jumps = progressSum(totals.jumps, max(0, r.jumps))
        totals.dodges = progressSum(totals.dodges, max(0, r.dodges)); totals.supermans = progressSum(totals.supermans, max(0, r.supermans))
        totals.distance += clean(r.distance); totals.wheelieMetres += clean(r.wheelieMetres)
        totals.stoppieMetres += clean(r.stoppieMetres); totals.airTime += clean(r.airTime); totals.noHandsSeconds += clean(r.noHandsSeconds)
        totals.bestCombo = max(totals.bestCombo, r.bestCombo); totals.bestScore = max(totals.bestScore, r.score)
        if r.endless { totals.bestEndless = max(totals.bestEndless, clean(r.distance)) }
        return totals.sanitized
    }
    /// Achievements the run would unlock if it ended now. Changes nothing.
    func preview(_ r: RunReport) -> [RideAchievement] {
        let projected = Self.applying(r, to: totals)
        return RideAchievement.all.filter { !earned.contains($0.id) && $0.isEarned(projected) }
    }
    func markTutorialDone() -> [RideAchievement] { totals.tutorialDone = true; return unlockNew() }
    func addCoinsEarned(_ coins: Int) { totals.coinsEarned = progressSum(totals.coinsEarned, max(0, coins)); save() }
    private func unlockNew() -> [RideAchievement] {
        let fresh = RideAchievement.all.filter { !earned.contains($0.id) && $0.isEarned(totals) }
        fresh.forEach { earned.insert($0.id) }
        save()
        return fresh
    }
    var summary: [String] {
        let t = totals
        return [
            "Rutas: \(t.runs) · completadas \(t.finishes) · caídas \(t.crashes)",
            "Distancia total: \(Int(t.distance)) m · mejor infinito \(Int(t.bestEndless)) m",
            "Caballito \(Int(t.wheelieMetres)) m · invertido \(Int(t.stoppieMetres)) m · aire \(Int(t.airTime)) s",
            "Volteretas \(t.flips) · giros 360° \(t.spins) · saltos \(t.jumps) · obstáculos esquivados \(t.dodges)",
            "Mejor cadena \(t.bestCombo) · mejor puntuación \(t.bestScore) · carreras ganadas \(t.raceWins)",
            "Monedas ganadas: \(t.coinsEarned)",
        ]
    }
}
