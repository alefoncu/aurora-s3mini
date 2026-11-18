import Cocoa

@main
struct DaylightTests {
    static func check(_ c: Bool, _ m: String) { if !c { FileHandle.standardError.write(Data("FAIL: \(m)\n".utf8)); exit(1) } }
    static func main() {
        check(RideDaylight.wash(progress: 0.5, night: false).opacity == 0, "noon is clear")
        check(RideDaylight.wash(progress: 0, night: false).opacity > 0.15, "dawn is warm")
        check(RideDaylight.wash(progress: 1, night: false).opacity > 0.2, "dusk is amber")
        check(RideDaylight.wash(progress: 0, night: true).opacity == 0 && RideDaylight.wash(progress: 1, night: true).opacity == 0, "night keeps its own look")
        check(RideDaylight.wash(progress: .nan, night: false).opacity == 0 && RideDaylight.wash(progress: 9, night: false).opacity <= 0.25, "invalid and out-of-range input stays bounded")
        var last = -1.0
        for i in 0...20 { let o = RideDaylight.wash(progress: 0.6 + Double(i) * 0.02, night: false).opacity; check(o >= last, "dusk only deepens"); last = o }
        let s = [RunSample(distance: 0, speed: 10, trick: 0), RunSample(distance: 50, speed: 30, trick: 1), RunSample(distance: 100, speed: 20, trick: 3), RunSample(distance: 150, speed: 25, trick: 2)]
        let text = RideRunChart.summary(s)
        check(text.contains("108 km/h") && text.contains("150 m") && text.contains("25 %"), "chart summary reads \(text)")
        check(RideRunChart.summary([]) == "Sin datos", "empty chart")
        print("Daylight and chart tests passed.")
    }
}
