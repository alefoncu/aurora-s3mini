import Foundation

@main struct WeatherTests {
    static func check(_ ok: @autoclosure () -> Bool, _ message: String) { if !ok() { print("WeatherTests FAILED: \(message)"); exit(1) } }
    static func main() {
        for route in 0..<5 {
            check(RideWeather.state(route: route, x: 0, time: 0, seed: 1).fog == 0 && RideWeather.state(route: route, x: 1_199, time: 5, seed: 1).fog == 0, "Every route starts and ends clear: \(route)")
            var previous = RideWeather.state(route: route, x: 0, time: 0, seed: 7), peak = 0.0
            for i in 1...2_400 {
                let x = Double(i) * 0.5, s = RideWeather.state(route: route, x: x, time: 0, seed: 7)
                check((0...1).contains(s.fog) && (0...1).contains(s.rain), "Intensities stay in range")
                check(abs(s.fog - previous.fog) < 0.03 && abs(s.rain - previous.rain) < 0.03, "Weather changes smoothly (route \(route), x=\(x))")
                peak = max(peak, s.fog); previous = s
            }
            check(peak > 0.3, "Every route gets a weather event: \(route) peak \(peak)")
        }
        check(RideWeather.state(route: 1, x: 780, time: 0, seed: 3).storm && RideWeather.state(route: 4, x: 850, time: 0, seed: 3).storm, "Storms hit the Sierra and the city")
        check(!RideWeather.state(route: 0, x: 550, time: 0, seed: 3).storm && RideWeather.state(route: 0, x: 550, time: 0, seed: 3).fog > 0.6, "The valley gets fog, not a storm")
        check(RideWeather.state(route: 4, x: 10, time: 0, seed: 3).rain >= 0.55, "The city is always rainy")
        check(RideWeather.state(route: 0, x: 550, time: 0, seed: 3).label == "Niebla densa" && RideWeather.state(route: 1, x: 780, time: 0, seed: 3).label == "Tormenta" && RideWeather.state(route: 0, x: 10, time: 0, seed: 3).label == nil, "Labels")
        check(RideWeather.state(route: 0, x: .nan, time: .nan, seed: 1) == WeatherState(), "Invalid input is clear weather")
        // Lightning: only during storms, bounded, deterministic per seed, different between seeds, and it flashes then fades.
        check(RideWeather.state(route: 1, x: 100, time: 30, seed: 1).flash == 0, "No lightning outside a storm")
        var flashes = 0, maxFlash = 0.0
        for i in 0..<6_000 { let f = RideWeather.lightning(time: Double(i) * 0.01, seed: 11); maxFlash = max(maxFlash, f); check((0...1).contains(f), "Flash range"); if f > 0.8 && (i == 0 || RideWeather.lightning(time: Double(i - 1) * 0.01, seed: 11) <= 0.8) { flashes += 1 } }
        check(flashes >= 6 && flashes <= 14 && maxFlash > 0.95, "About one strike every 6-10 s over a minute: \(flashes)")
        check(RideWeather.lightning(time: 12.3, seed: 5) == RideWeather.lightning(time: 12.3, seed: 5), "Deterministic")
        check((0..<20).contains { RideWeather.lightning(time: Double($0) * 0.5, seed: 5) != RideWeather.lightning(time: Double($0) * 0.5, seed: 9) }, "Seeds differ")
        check(RideWeather.lightning(time: -3, seed: 1) == 0 && RideWeather.lightning(time: .infinity, seed: 1) == 0, "Invalid times")
        let thunder = RideWeather.thunderCount(from: 0, to: 60, seed: 11)
        check(thunder >= 8 && thunder <= 11 && RideWeather.thunderCount(from: 30, to: 20, seed: 1) == 0 && RideWeather.thunderCount(from: 0, to: 30, seed: 11) + RideWeather.thunderCount(from: 30, to: 60, seed: 11) == thunder, "Thunder follows lightning and never double counts: \(thunder)")
        print("WeatherTests passed: smooth fog/rain/storm banks on every route, lightning cadence and flicker, thunder timing, determinism and invalid input.")
    }
}
