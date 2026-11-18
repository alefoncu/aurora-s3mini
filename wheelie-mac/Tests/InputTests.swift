import Foundation

@main
struct InputTests {
    static func check(_ c: Bool, _ m: String) { if !c { FileHandle.standardError.write(Data("FAIL: \(m)\n".utf8)); exit(1) } }
    static func main() {
        var map = RideKeyMap()
        check(map.codes(.throttle) == [13, 126] && !map.isCustom, "defaults")
        check(!map.assign(.jump, key: 36), "reserved key refused")
        check(map.assign(.jump, key: 0), "assign A to jump")
        check(map.codes(.jump) == [0] && map.codes(.leanBack) == [123], "A removed from leanBack")
        let prefs = UserDefaults(suiteName: "wr.test.\(UUID().uuidString)")!
        map.save(prefs); check(RideKeyMap.load(prefs) == map, "round trip")
        map.reset(); map.save(prefs); check(RideKeyMap.load(prefs) == RideKeyMap(), "reset")
        check(RideKeyMap.name(for: 49) == "Espacio" && RideKeyMap().label(.throttle) == "W / ↑", "labels")
        var pad = RidePadState(); pad.rightTrigger = 0.8; pad.leftX = -0.6; pad.x = true
        let set = RidePadMap.actions(pad)
        check(set == [.throttle, .leanBack, .jump], "pad mapping \(set)")
        pad = RidePadState(); pad.leftX = 0.2
        check(RidePadMap.actions(pad).isEmpty, "deadzone")
        pad.leftTrigger = 0.5; check(RidePadMap.actions(pad) == [.brake, .frontBrake], "brake")
        print("Input tests passed.")
    }
}
