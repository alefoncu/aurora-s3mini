import Foundation

enum MissionMetric: String, CaseIterable, Codable {
    case distance, wheelie, stoppie, flips, spins, jumps, dodges, finishes, noHands   // accumulate over runs
    case score, combo                                                                  // best of a single run
    var accumulates: Bool { self != .score && self != .combo }
    func value(of r: RunReport) -> Double {
        switch self {
        case .distance: return r.distance
        case .wheelie: return r.wheelieMetres
        case .stoppie: return r.stoppieMetres
        case .flips: return Double(r.flips)
        case .spins: return Double(r.spins)
        case .jumps: return Double(r.jumps)
        case .dodges: return Double(r.dodges)
        case .finishes: return r.finished ? 1 : 0
        case .noHands: return r.noHandsSeconds
        case .score: return Double(r.score)
        case .combo: return Double(r.bestCombo)
        }
    }
}

struct Mission: Equatable {
    let metric: MissionMetric
    let target: Int
    let reward: Int
    var title: String {
        switch metric {
        case .distance: return "Recorre \(target) m"
        case .wheelie: return "Haz \(target) m de caballito"
        case .stoppie: return "Haz \(target) m de invertido"
        case .flips: return "Aterriza \(target) volteretas"
        case .spins: return "Aterriza \(target) giros de 360°"
        case .jumps: return "Encadena \(target) saltos"
        case .dodges: return "Esquiva \(target) obstáculos"
        case .finishes: return "Completa \(target) \(target == 1 ? "ruta" : "rutas")"
        case .noHands: return "Rueda \(target) s sin manos"
        case .score: return "Logra \(target) puntos en una partida"
        case .combo: return "Haz una cadena de \(target) puntos"
        }
    }
}

/// Three daily missions and one weekly mission, generated deterministically from the date so
/// every launch on the same day shows the same goals. Progress and claims persist.
final class RideMissions {
    struct State: Codable {
        var dayKey = "", weekKey = ""
        var dayProgress: [Double] = [], dayDone: [Bool] = []
        var weekProgress = 0.0, weekDone = false
    }
    private static let dailyPool: [(MissionMetric, [Int], Int)] = [
        (.distance, [1_500, 2_500, 4_000], 20), (.wheelie, [40, 80, 150], 20), (.stoppie, [10, 20, 40], 25),
        (.flips, [1, 2, 4], 30), (.spins, [1, 2], 25), (.jumps, [5, 10, 20], 15), (.dodges, [10, 20, 35], 20),
        (.finishes, [1, 2], 30), (.noHands, [5, 10, 20], 20), (.score, [800, 1_500, 3_000], 30), (.combo, [500, 1_000, 2_000], 30),
    ]
    private let prefs: UserDefaults
    private let calendar: Calendar
    private let now: () -> Date
    private(set) var state = State()
    private(set) var daily: [Mission] = []
    private(set) var weekly = Mission(metric: .distance, target: 1, reward: 0)

    init(preferences: UserDefaults, calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        prefs = preferences; self.calendar = calendar; self.now = now
        if let data = preferences.data(forKey: "missions.state"), let decoded = try? JSONDecoder().decode(State.self, from: data) { state = decoded }
        refresh()
    }
    private struct Seeded {
        var state: UInt64
        mutating func next(_ bound: Int) -> Int { state = state &* 6364136223846793005 &+ 1442695040888963407; return Int((state >> 33) % UInt64(max(1, bound))) }
    }
    private func keys() -> (day: String, week: String, daySeed: UInt64, weekSeed: UInt64) {
        let d = calendar.dateComponents([.year, .month, .day, .yearForWeekOfYear, .weekOfYear], from: now())
        let day = String(format: "%04d-%02d-%02d", d.year ?? 0, d.month ?? 0, d.day ?? 0)
        let week = String(format: "%04d-W%02d", d.yearForWeekOfYear ?? 0, d.weekOfYear ?? 0)
        return (day, week, UInt64((d.year ?? 0) * 10_000 + (d.month ?? 0) * 100 + (d.day ?? 0)), UInt64((d.yearForWeekOfYear ?? 0) * 100 + (d.weekOfYear ?? 0)))
    }
    /// Regenerate goals when the day or week has changed since the last call.
    func refresh() {
        let k = keys()
        var g = Seeded(state: k.daySeed &* 2_654_435_761)
        var pool = Array(Self.dailyPool.indices), picked: [Mission] = []
        for _ in 0..<3 {
            let i = pool.remove(at: g.next(pool.count)), entry = Self.dailyPool[i]
            picked.append(Mission(metric: entry.0, target: entry.1[g.next(entry.1.count)], reward: entry.2))
        }
        daily = picked
        var w = Seeded(state: k.weekSeed &* 40_503 &+ 7)
        let e = Self.dailyPool[w.next(Self.dailyPool.count)]
        weekly = Mission(metric: e.0, target: e.1.last! * (e.0.accumulates ? 4 : 2), reward: e.2 * 5)
        if state.dayKey != k.day { state.dayKey = k.day; state.dayProgress = Array(repeating: 0, count: 3); state.dayDone = Array(repeating: false, count: 3) }
        if state.weekKey != k.week { state.weekKey = k.week; state.weekProgress = 0; state.weekDone = false }
        save()
    }
    private func save() { if let data = try? JSONEncoder().encode(state) { prefs.set(data, forKey: "missions.state") } }
    func progress(daily i: Int) -> Double { state.dayProgress.indices.contains(i) ? state.dayProgress[i] : 0 }
    var weeklyProgress: Double { state.weekProgress }
    /// Apply a run; returns the missions completed by it together with their coin rewards (each once).
    @discardableResult func record(_ report: RunReport) -> [Mission] {
        refresh()
        var completed: [Mission] = []
        func advance(_ current: inout Double, _ m: Mission) {
            let v = max(0, m.metric.value(of: report)); guard v.isFinite else { return }
            current = m.metric.accumulates ? current + v : max(current, v)
        }
        for (i, m) in daily.enumerated() where !state.dayDone[i] {
            advance(&state.dayProgress[i], m)
            if state.dayProgress[i] >= Double(m.target) { state.dayDone[i] = true; completed.append(m) }
        }
        if !state.weekDone {
            advance(&state.weekProgress, weekly)
            if state.weekProgress >= Double(weekly.target) { state.weekDone = true; completed.append(weekly) }
        }
        save()
        return completed
    }
    /// Missions the run would complete if it ended now. Changes nothing.
    func preview(_ report: RunReport) -> [Mission] {
        func projected(_ current: Double, _ m: Mission) -> Double {
            let v = max(0, m.metric.value(of: report)); guard v.isFinite else { return current }
            return m.metric.accumulates ? current + v : max(current, v)
        }
        var result: [Mission] = []
        for (i, m) in daily.enumerated() where !state.dayDone[i] && projected(state.dayProgress[i], m) >= Double(m.target) { result.append(m) }
        if !state.weekDone && projected(state.weekProgress, weekly) >= Double(weekly.target) { result.append(weekly) }
        return result
    }
    func isDone(daily i: Int) -> Bool { state.dayDone.indices.contains(i) && state.dayDone[i] }
    var weeklyDone: Bool { state.weekDone }
}
