import Foundation

/// Weather that changes along the route: fog banks, storms and blizzards, with lightning during storms.
/// Pure and deterministic (route, distance, time and a per-run seed), so tests can pin it down.
struct WeatherState: Equatable {
    var fog = 0.0          // 0 clear ... 1 thick
    var rain = 0.0         // 0 dry ... 1 downpour (rain on most routes, snowfall is the snow route's own)
    var storm = false      // heavy rain with lightning and thunder
    var flash = 0.0        // lightning brightness right now, 0...1
    var wetness: Double { rain }                       // how much grip the road has lost
    var label: String? {
        if storm { return "Tormenta" }
        if fog > 0.45 { return "Niebla densa" }
        if fog > 0.15 { return "Niebla" }
        if rain > 0.3 { return "Lluvia" }
        return nil
    }
}

enum RideWeather {
    /// A weather bank: intensities rise over `ramp` metres from `start`, hold, and fall back at `end`.
    private struct Bank { let start: Double, end: Double, ramp: Double, fog: Double, rain: Double, storm: Bool }
    private static func banks(route: Int) -> [Bank] {
        switch route {
        case 0:  return [Bank(start: 380, end: 700, ramp: 90, fog: 0.75, rain: 0, storm: false)]
        case 1:  return [Bank(start: 560, end: 980, ramp: 100, fog: 0.35, rain: 1.0, storm: true)]
        case 2:  return [Bank(start: 450, end: 800, ramp: 90, fog: 0.6, rain: 0, storm: false)]
        case 3:  return [Bank(start: 500, end: 880, ramp: 100, fog: 0.85, rain: 0, storm: false)]
        default: return [Bank(start: 650, end: 1_050, ramp: 100, fog: 0.4, rain: 1.0, storm: true)]
        }
    }
    private static func envelope(_ x: Double, _ b: Bank) -> Double {
        guard x.isFinite, x > b.start, x < b.end else { return 0 }
        let up = min(1, (x - b.start) / b.ramp), down = min(1, (b.end - x) / b.ramp), t = min(up, down)
        return t * t * (3 - 2 * t)
    }
    /// Weather at world position `x` (for circuits, pass the position within the lap).
    static func state(route: Int, x: Double, time: Double, seed: UInt64) -> WeatherState {
        var s = WeatherState()
        for b in banks(route: route) {
            let e = envelope(x, b)
            s.fog = max(s.fog, b.fog * e); s.rain = max(s.rain, b.rain * e)
            if b.storm && e > 0.5 { s.storm = true }
        }
        // The city is rainy to begin with.
        if route == 4 { s.rain = max(s.rain, 0.55) }
        if s.storm { s.flash = lightning(time: time, seed: seed) }
        return s
    }
    /// Lightning strikes every 6-10 s with a quick double flicker; brightness 0...1 at `time`.
    static func lightning(time: Double, seed: UInt64) -> Double {
        guard time.isFinite, time >= 0 else { return 0 }
        var level = 0.0
        for k in max(0, Int(time / 6) - 2)...(Int(time / 6) + 1) {
            let t0 = strikeTime(k, seed: seed), dt = time - t0
            guard dt >= 0, dt < 1.2 else { continue }
            level = max(level, exp(-dt * 9) + 0.6 * exp(-(dt - 0.18) * 14) * (dt > 0.18 ? 1 : 0))
        }
        return min(1, level)
    }
    static func strikeTime(_ k: Int, seed: UInt64) -> Double {
        var z = UInt64(truncatingIfNeeded: k) &* 0x9E3779B97F4A7C15 &+ seed &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9; z = (z ^ (z >> 27)) &* 0x94D049BB133111EB; z ^= z >> 31
        return Double(k) * 6 + Double(z % 3_000) / 1_000     // somewhere in a 3 s window of each 6 s slot
    }
    /// Thunder arrives about 0.9 s after each flash: number of rumbles between two times.
    static func thunderCount(from t0: Double, to t1: Double, seed: UInt64) -> Int {
        guard t0.isFinite, t1.isFinite, t1 > t0 else { return 0 }
        var n = 0
        for k in max(0, Int(t0 / 6) - 2)...(Int(t1 / 6) + 1) {
            let arrival = strikeTime(k, seed: seed) + 0.9
            if arrival > t0 && arrival <= t1 { n += 1 }
        }
        return n
    }
}
