import Foundation
@main struct TransmissionTests {
    static func main() {
        for kind in BikeKind.allCases {
            var t=RideTransmission();t.reset(kind:kind)
            precondition(t.shiftRemaining==0 && t.rpm==RideTransmission.idleRPM(kind:kind))
            if kind == .bmx || kind == .scooter || kind == .electric {
                t.shift(up:true,kind:kind);precondition(t.gear==0)
                t.update(dt:1/60,kind:kind,speed:5,throttle:1,drivenWheelRate:0)
                precondition(t.driveMultiplier==1 && (kind != .bmx || t.rpm==0))
                continue
            }
            let first=t.gear
            t.shift(up:true,kind:kind)
            precondition(t.gear==first+1 && t.shiftRemaining>0 && t.driveMultiplier<0.1)
            t.shift(up:true,kind:kind);precondition(t.gear==first+1,"Cannot skip gears during clutch cut")
            t.automatic=false
            for _ in 0..<60 { t.update(dt:1/60,kind:kind,speed:1,throttle:0,drivenWheelRate:0) }
            t.shift(up:false,kind:kind)
            for _ in 0..<60 { t.update(dt:1/60,kind:kind,speed:kind.topSpeed,throttle:1,drivenWheelRate:0) }
            precondition(t.gear==1 && t.driveMultiplier==0,"First gear must hit its limiter at excessive road speed")
            t.automatic=true
            for _ in 0..<600 {t.update(dt:1/60,kind:kind,speed:kind.topSpeed,throttle:1,drivenWheelRate:kind.topSpeed/kind.rig.wheelRadius)}
            precondition(t.gear==t.gearCount && t.driveMultiplier==1,"Top gear must preserve calibrated maximum speed")
            let roadRPM=t.rpm
            for _ in 0..<60 {t.update(dt:1/60,kind:kind,speed:kind.topSpeed*0.25,throttle:1,drivenWheelRate:kind.topSpeed/kind.rig.wheelRadius)}
            precondition(t.rpm>roadRPM*0.95,"Spinning driven wheel must keep engine coupled")
            for _ in 0..<600 {t.update(dt:1/60,kind:kind,speed:0,throttle:0,drivenWheelRate:0)}
            precondition(t.gear==1 && abs(t.rpm-RideTransmission.idleRPM(kind:kind))<1)
            let previous=t.rpm
            t.update(dt:.nan,kind:kind,speed:0,throttle:0,drivenWheelRate:0)
            precondition(t.rpm==previous)
        }
        print("TransmissionTests passed: manual/automatic gears, clutch cut, limiter, top speed, wheel spin, idle, BMX and CVT.")
    }
}
