import Foundation

/// What a finished (or abandoned) run produced. Missions and achievements both read it.
struct RunReport {
    var distance = 0.0, wheelieMetres = 0.0, stoppieMetres = 0.0, airTime = 0.0
    var score = 0, bestCombo = 0
    var flips = 0, spins = 0, jumps = 0, dodges = 0, supermans = 0
    var noHandsSeconds = 0.0
    var finished = false, crashed = false, endless = false, raceWon = false
}

/// Lifetime totals, stored as JSON in the app's preferences.
struct RideTotals: Codable, Equatable {
    var runs = 0, crashes = 0, finishes = 0, raceWins = 0, flips = 0, spins = 0, jumps = 0, dodges = 0, supermans = 0
    var distance = 0.0, wheelieMetres = 0.0, stoppieMetres = 0.0, airTime = 0.0, noHandsSeconds = 0.0
    var bestCombo = 0, bestScore = 0
    var bestEndless = 0.0
    var tutorialDone = false
    var coinsEarned = 0
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
        if let data = preferences.data(forKey: "stats.totals"), let decoded = try? JSONDecoder().decode(RideTotals.self, from: data) { totals = decoded } else { totals = RideTotals() }
        earned = Set(preferences.stringArray(forKey: "stats.achievements") ?? [])
    }
    private func save() {
        if let data = try? JSONEncoder().encode(totals) { prefs.set(data, forKey: "stats.totals") }
        prefs.set(Array(earned).sorted(), forKey: "stats.achievements")
    }
    /// Add one run and return the achievements it unlocked (each is returned only once, ever).
    @discardableResult func record(_ r: RunReport) -> [RideAchievement] {
        func clean(_ v: Double) -> Double { v.isFinite ? max(0, v) : 0 }
        totals.runs += 1
        if r.crashed { totals.crashes += 1 }
        if r.finished { totals.finishes += 1 }
        if r.raceWon { totals.raceWins += 1 }
        totals.flips += max(0, r.flips); totals.spins += max(0, r.spins); totals.jumps += max(0, r.jumps)
        totals.dodges += max(0, r.dodges); totals.supermans += max(0, r.supermans)
        totals.distance += clean(r.distance); totals.wheelieMetres += clean(r.wheelieMetres)
        totals.stoppieMetres += clean(r.stoppieMetres); totals.airTime += clean(r.airTime); totals.noHandsSeconds += clean(r.noHandsSeconds)
        totals.bestCombo = max(totals.bestCombo, r.bestCombo); totals.bestScore = max(totals.bestScore, r.score)
        if r.endless { totals.bestEndless = max(totals.bestEndless, clean(r.distance)) }
        return unlockNew()
    }
    func markTutorialDone() -> [RideAchievement] { totals.tutorialDone = true; return unlockNew() }
    func addCoinsEarned(_ coins: Int) { totals.coinsEarned += max(0, coins); save() }
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
