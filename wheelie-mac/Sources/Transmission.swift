import Foundation

/// Arcade gearbox. Wheel rates are radians/second; speeds are metres/second.
/// Engine speed follows the driven wheel above clutch engagement, so a wheel
/// spinning in the air also raises RPM. This type owns no simulation clock.
struct RideTransmission {
    var automatic = true
    private(set) var gear = 1
    private(set) var rpm = 1_250.0
    private(set) var shiftRemaining = 0.0
    private(set) var gearCount = 5
    private(set) var isCVT = false
    private var limiter = 1.0
    private var gearBoost = 1.0
    private var shiftCooldown = 0.0

    static func idleRPM(kind: BikeKind) -> Double {
        switch kind { case .bmx: return 0; case .sport,.hyperbike: return 1_500; case .motocross,.trials: return 1_650; default: return 1_250 }
    }
    static func redlineRPM(kind: BikeKind) -> Double {
        switch kind { case .bmx: return 0; case .sport: return 13_500; case .hyperbike: return 14_200; case .motocross: return 10_500; case .trials: return 9_000; case .scooter: return 8_500; default: return 9_500 }
    }
    private static func count(_ kind: BikeKind) -> Int {
        switch kind { case .bmx,.scooter: return 0; case .sport,.hyperbike,.motocross: return 6; default: return 5 }
    }
    mutating func reset(kind: BikeKind) {
        gearCount = Self.count(kind); isCVT = kind == .scooter
        gear = gearCount == 0 ? 0 : 1; rpm = Self.idleRPM(kind: kind)
        shiftRemaining = 0; shiftCooldown = 0; limiter = 1; gearBoost = gearCount > 0 ? 1.12 : 1
    }
    mutating func shift(up: Bool, kind: BikeKind) {
        guard Self.count(kind) > 0, shiftRemaining <= 0 else { return }
        let next = max(1,min(Self.count(kind),gear + (up ? 1 : -1)))
        guard next != gear else { return }
        gear = next; shiftRemaining = 0.16; shiftCooldown = 0.42
        gearBoost = 1 + 0.12 * Double(gearCount-gear)/Double(max(1,gearCount-1))
    }
    var driveMultiplier: Double {
        // Keeping top gear at unity preserves the vehicle's calibrated speed.
        shiftRemaining > 0 ? 0.08 : limiter * gearBoost
    }
    mutating func update(dt: Double, kind: BikeKind, speed: Double, throttle: Double, drivenWheelRate: Double) {
        guard dt.isFinite, dt > 0 else { return }
        let dt = min(dt,0.25)
        if gearCount != Self.count(kind) || isCVT != (kind == .scooter) { reset(kind: kind) }
        shiftRemaining = max(0,shiftRemaining-dt); shiftCooldown = max(0,shiftCooldown-dt)
        guard kind != .bmx else { rpm = 0; limiter = 1; return }
        let gas = throttle.isFinite ? max(0,min(1,throttle)) : 0
        let speed = speed.isFinite ? max(0,speed) : 0
        let wheelSpeed = drivenWheelRate.isFinite ? abs(drivenWheelRate)*kind.rig.wheelRadius : speed
        let effectiveSpeed = max(speed,wheelSpeed)
        let idle = Self.idleRPM(kind: kind), redline = Self.redlineRPM(kind: kind)
        if isCVT {
            let clutch = min(1,effectiveSpeed/3)
            let target = idle + (redline*0.80-idle)*max(gas,clutch*0.55)
            rpm += (target-rpm)*(1-exp(-dt/0.12)); limiter = 1; gearBoost = 1
            return
        }
        func wheelRPM(_ gear: Int) -> Double {
            let fraction = 0.27 + 0.79*Double(gear-1)/Double(max(1,gearCount-1))
            return effectiveSpeed/(kind.topSpeed*fraction)*redline
        }
        if automatic && shiftRemaining == 0 && shiftCooldown == 0 {
            let coupled = wheelRPM(gear)
            if coupled > redline*0.88 && gear < gearCount { shift(up:true,kind:kind) }
            else if coupled < redline*0.36 && gear > 1 { shift(up:false,kind:kind) }
        }
        let coupled = wheelRPM(gear)
        let clutchRPM = idle + gas*(redline*0.34-idle)*max(0,1-effectiveSpeed/5)
        let target = max(idle,min(redline*1.08,max(coupled,clutchRPM)))
        rpm += (target-rpm)*(1-exp(-dt/(shiftRemaining>0 ? 0.055:0.09)))
        limiter = max(0,min(1,(redline*1.035-coupled)/(redline*0.045)))
        gearBoost = 1 + 0.12*Double(gearCount-gear)/Double(max(1,gearCount-1))
    }
}
