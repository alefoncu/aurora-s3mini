import Foundation

@main struct PhysicsTests {
    static let frame=1.0/120
    static func step(_ b:BikePhysics,dt:Double=frame,gas:Bool=true,back:Bool=false,forward:Bool=false,brake:Bool=false,jump:Bool=false) {
        b.update(dt,throttle:gas,brake:brake,leanBack:back,leanForward:forward,jump:jump)
    }
    static func check(_ value:@autoclosure()->Bool,_ message:String) { if !value() { print("PhysicsTests FAILED: \(message)"); exit(1) } }
    static func contactError(_ b:BikePhysics)->Double {
        let r=b.kind.rig.wheelRadius
        return max(BikePhysics.ground(b.rearWheelPosition.x,route:b.route)+r-b.rearWheelPosition.y,
                   BikePhysics.ground(b.frontWheelPosition.x,route:b.route)+r-b.frontWheelPosition.y)
    }
    static func finite(_ b:BikePhysics) {
        for v in [b.x,b.speed,b.pitch,b.angularVelocity,b.chassisPosition.y,b.frontWheelPosition.x,b.frontWheelPosition.y,b.rearWheelPosition.x,b.rearWheelPosition.y] {
            check(v.isFinite && abs(v)<10000,"Simulation diverged")
        }
        check(contactError(b)<0.004,"A wheel penetrated the terrain")
        check(b.frontCompression>=0 && b.frontCompression<=b.kind.rig.frontTravel+0.0001,"Front travel exceeded")
        check(b.rearCompression>=0 && b.rearCompression<=b.kind.rig.rearTravel+0.0001,"Rear travel exceeded")
    }
    static func main() {
        check(BikePhysics.difficultyStage(at:0)==0 && BikePhysics.difficultyStage(at:299.99)==0 && BikePhysics.difficultyStage(at:300)==1 && BikePhysics.difficultyStage(at:600)==2 && BikePhysics.difficultyStage(at:900)==3,"Course sector boundaries")
        check(BikePhysics.difficultyStage(at:Double.greatestFiniteMagnitude)==3,"Extreme finite distance must clamp before integer conversion")
        check(BikePhysics.difficultyStage(at:Double.nan)==0 && BikePhysics.difficultyStage(at:-5)==0,"Invalid/negative sector positions")
        // Full throttle alone, from rest, must never flip any vehicle over.
        for kind in BikeKind.allCases {
            let b=BikePhysics();b.kind=kind
            for _ in 0..<1800 {step(b);finite(b)}
            check(!b.crashed,"Throttle alone must not loop the bike over: \(kind)")
        }
        // Rolling backwards: on the steepest uphill of route 1 an unpowered,
        // unbraked bike rolls back; any brake holds it and throttle recovers it.
        do {
            var ux=0.0,us=0.0
            for i in 0..<11000 { let x=Double(i)*0.1,s=BikePhysics.slope(x,route:1); if s>us {us=s;ux=x} }
            let b=BikePhysics();b.kind = .motocross;b.route=1;b.x=ux
            for _ in 0..<120 {step(b,gas:false);finite(b)}
            check(b.x<ux-0.5 && b.speed==0 && !b.crashed,"Unbraked bike must roll back on a steep uphill, x=\(b.x) from \(ux)")
            for _ in 0..<240 {step(b,gas:false,brake:true);finite(b)}
            let held=b.x
            for _ in 0..<240 {step(b,gas:false,brake:true)}
            check(abs(b.x-held)<0.01,"Brake must hold a bike on a slope")
            // The Enduro (5.2 m/s²) cannot out-pull a 35° slope; the Sport (6.3) can.
            b.kind = .sport;b.x=ux
            for _ in 0..<600 {step(b,back:b.angle < -0.25,forward:b.angle>0.25);finite(b)}
            check(b.x>ux+1 && !b.crashed,"Throttle must climb out of a steep uphill, x=\(b.x) from \(ux)")
        }
        let obstacles=BikePhysics.obstaclePositions
        check(Set(obstacles).count==obstacles.count && obstacles==obstacles.sorted(),"One sorted collision/render obstacle schedule")
        let sectorCounts=(0..<4).map { stage in obstacles.filter { BikePhysics.difficultyStage(at:Double($0))==stage }.count }
        check(zip(sectorCounts,sectorCounts.dropFirst()).allSatisfy { $0 < $1 },"Obstacle density must rise each sector")
        for route in 0...2 {
            func terrainEffort(_ start:Double)->Double {
                var sum=0.0
                for i in 0..<1000 {let x=start+Double(i)*0.2;sum+=pow(BikePhysics.slope(x,route:route),2)}
                return sqrt(sum/1000)
            }
            let early=terrainEffort(60),late=terrainEffort(940)
            check(late>early*1.35,"Late terrain must demand more control with cones off: route \(route), \(early) -> \(late)")
            for i in 0...6000 {
                let x=Double(i)*0.2,y=BikePhysics.ground(x,route:route),slope=BikePhysics.slope(x,route:route)
                check(y.isFinite && slope.isFinite && abs(slope)<0.75,"Progressive terrain needs bounded readable slopes")
                check(abs(BikePhysics.ground(x+0.0001,route:route)-y)<0.0001,"Ground must remain continuous at ramps/sectors")
            }
        }
        var suspensionRanges:[BikeKind:Double]=[:]
        for kind in BikeKind.allCases {
            let b=BikePhysics();b.kind=kind
            for _ in 0..<1200 {step(b,gas:false)}
            finite(b)
            check(b.frontContact && b.rearContact && abs(b.verticalVelocity)<0.001,"Stationary bike must settle onto both tyres")
            check(b.frontCompression>kind.rig.frontTravel*0.2 && b.frontCompression<kind.rig.frontTravel*0.45,"Front static sag must support weight")
            check(b.rearCompression>kind.rig.rearTravel*0.2 && b.rearCompression<kind.rig.rearTravel*0.45,"Rear static sag must support weight")
            let y=b.chassisPosition.y
            for _ in 0..<240 {step(b,gas:false)}
            check(abs(b.chassisPosition.y-y)<0.0001,"No decorative suspension oscillation at rest")
            for route in 0...2 {
                b.route=route;b.reset();var minCompression=Double.infinity,maxCompression=0.0
                for _ in 0..<60000 where !b.finished && !b.crashed {
                    // A readable cautious rider: slow progressively on rougher
                    // sectors and correct pitch, without privileged terrain lookahead.
                    let stage=Double(BikePhysics.difficultyStage(at:b.x))
                    let target=min(kind.topSpeed*0.85,(route == 0 ? 16.0 : 11.0)-stage*1.2)
                    step(b,gas:b.speed<target,back:b.angle < -0.25,forward:b.angle>0.25,brake:b.speed>target+0.6); finite(b)
                    if route==1 { minCompression=min(minCompression,b.frontCompression);maxCompression=max(maxCompression,b.frontCompression) }
                }
                check(b.finished && !b.crashed,"Controlled progressive route failed: \(kind), \(route), x=\(b.x), angle=\(b.angle)")
                check(abs(b.distance-BikePhysics.finish)<0.0001 && b.coins==15 && b.speed==0,"Finish must be coherent")
                if route==1 { suspensionRanges[kind]=maxCompression-minCompression;check(maxCompression-minCompression>0.01,"Terrain must excite physical suspension") }
            }
            b.route=0;b.reset()
            for _ in 0..<240 {step(b)}
            var attempts=0
            while b.angle<0.60 && !b.crashed && attempts<800 {step(b,back:true);attempts+=1}
            check(!b.crashed && b.angle>=0.60 && b.bestWheelie>0.5,"Each vehicle must be able to lift the actual front tyre")
            check(b.rearContact && !b.frontContact,"A wheelie must be based on real contacts")
            for _ in 0..<300 {step(b,forward:true)}
            check(!b.crashed && abs(b.angle)<0.4,"Forward correction must recover a developing wheelie: \(kind)")
            for _ in 0..<1800 where b.speed>0.2 {step(b,gas:false,brake:true)}
            check(b.speed<1,"Braking must slow the vehicle: \(kind), \(b.speed)")
            b.reset();var maxHeight=0.0,maxImpact=0.0,maxCompression=0.0
            for _ in 0..<600 {step(b,gas:false,jump:true);finite(b);maxHeight=max(maxHeight,b.height);maxImpact=max(maxImpact,b.landingImpact);maxCompression=max(maxCompression,b.frontCompression)}
            check(maxHeight>0.2 && maxHeight<1.2,"A held jump should give one bounded hop")
            check(maxImpact>1 && maxCompression>kind.rig.frontTravel*0.5,"Landing must load the springs and report contact impact")
            check(b.frontContact && b.rearContact && b.height<0.001,"Jump must land without repeated automatic hops")
            step(b,gas:false,jump:false);step(b,gas:false,jump:true)
            check(b.verticalVelocity>1,"A new jump edge should apply a physical impulse")
            b.reset()
            for _ in 0..<1200 where !b.crashed {step(b,back:true)}
            check(b.crashed,"Holding the lift uncorrected must over-rotate")
            let crashDistance=b.distance
            for _ in 0..<240 {step(b);finite(b)}
            check(b.distance==crashDistance,"A settling wreck must not score distance")
            b.reset();let old=b.frontWheelPosition
            let beforePitch=b.pitch
            b.strikeObstacle(front:true,severity:1)
            var response=0.0
            for _ in 0..<30 {step(b,gas:false);response=max(response,abs(b.frontWheelPosition.y-old.y)+abs(b.pitch-beforePitch))}
            check(response>0.0001,"An obstacle must affect the physical wheel/body")
        }
        // Deliberate front braking plus forward body transfer produces a real
        // rear-wheel lift; releasing the brake and shifting back lands it again.
        for kind in BikeKind.allCases {
            let nose=BikePhysics();nose.kind=kind;nose.x = -500;nose.speed=kind == .bmx ? 8 : 12
            var frames=0
            while nose.angle > (kind == .bmx ? -0.30 : -0.40) && !nose.crashed && frames<240 {
                step(nose,gas:false,forward:true,brake:true);finite(nose);frames+=1
            }
            check(nose.isStoppie && nose.frontContact && !nose.rearContact && nose.bestStoppie>0.5,"Every vehicle must perform a contact-based invertido: \(kind)")
            check(nose.rearWheelPosition.y>BikePhysics.ground(nose.rearWheelPosition.x)+kind.rig.wheelRadius+0.1,"Invertido must physically lift rear wheel")
            for _ in 0..<480 {step(nose,gas:false,back:nose.angle < -0.1,forward:nose.angle>0.15);finite(nose)}
            check(!nose.crashed && nose.frontContact && nose.rearContact && abs(nose.angle)<0.1 && nose.stoppieDistance==0,"Release brake/shift back must recover an invertido: \(kind)")
            nose.reset()
            for _ in 0..<360 {step(nose,gas:false,forward:true,brake:true)}
            check(!nose.isStoppie && nose.bestStoppie==0,"Stationary controls cannot score an invertido")
            nose.reset();step(nose,gas:false,jump:true);nose.speed=6
            for _ in 0..<12 {step(nose,gas:false,forward:true,brake:true)}
            check(!nose.frontContact && !nose.rearContact && !nose.isStoppie && nose.bestStoppie==0,"Airborne rotation cannot score a stoppie")
            nose.reset();nose.x = -500;nose.speed=kind == .bmx ? 8 : 16
            for _ in 0..<480 where !nose.crashed {step(nose,gas:false,forward:true,brake:true);finite(nose)}
            check(nose.crashed,"Excessive uncorrected invertido must fall rather than freeze at a balance angle")
            let recorded=nose.bestStoppie
            for _ in 0..<120 {step(nose,gas:false,forward:true,brake:true)}
            check(nose.bestStoppie==recorded && !nose.isStoppie,"Wreck must not add stoppie score")
            nose.reset();check(nose.stoppieDistance==0 && nose.bestStoppie==0,"New run resets invertido metrics")
        }
        // Actuator response must take time; tyre forces must respect each axle's
        // finite grip rather than applying a speed subtraction on button press.
        for kind in BikeKind.allCases {
            let b=BikePhysics();b.kind=kind
            step(b)
            check(b.throttlePosition>0 && b.throttlePosition<0.1,"Throttle must ramp rather than step: \(kind)")
            let initialDrive=b.rearDriveForce
            for _ in 0..<72 {step(b)}
            check(b.throttlePosition>0.9 && b.rearDriveForce>initialDrive*3,"Sustained throttle must develop drive: \(kind)")
            check(b.rearDriveForce<=b.rearNormalLoad*b.frictionCoefficient+1e-6,"Drive cannot exceed rear tyre grip")
            b.reset();b.speed=10
            step(b,gas:false,brake:true)
            check(b.brakePressure>0 && b.brakePressure<0.1 && b.speed>9.97,"Brake pressure must build progressively")
            for _ in 0..<36 {step(b,gas:false,brake:true)}
            check(b.brakePressure>0.9 && b.frontBrakeForce>b.rearBrakeForce,"Linked brake must develop a front bias")
            check(b.frontBrakeForce<=b.frontNormalLoad*b.frictionCoefficient+1e-6 && b.rearBrakeForce<=b.rearNormalLoad*b.frictionCoefficient+1e-6,"Each brake is bounded by its own tyre grip")
            b.reset()
            for _ in 0..<240 {step(b)}
            var lifting=0
            while b.angle<0.6 && !b.crashed && lifting<800 {step(b,back:true);lifting+=1}
            check(!b.frontContact && !b.crashed,"Combined-input test must begin in a wheelie")
            let wheelieSpeed=b.speed
            var rearBrakedInWheelie=false
            for _ in 0..<60 {
                step(b,brake:true)
                if !b.frontContact && b.brakePressure>0.5 && b.rearBrakeForce>0 {rearBrakedInWheelie=true}
            }
            check(rearBrakedInWheelie && b.speed<wheelieSpeed,"Held gas must not defeat rear braking in a wheelie")
            let air=BikePhysics(),coast=BikePhysics();air.kind=kind;coast.kind=kind
            step(air,gas:false,jump:true);step(coast,gas:false,jump:true)
            air.speed=6;coast.speed=6
            for _ in 0..<12 {step(air,gas:false,brake:true);step(coast,gas:false)}
            check(!air.frontContact && !air.rearContact,"Brake test must remain airborne")
            check(air.frontBrakeForce==0 && air.rearBrakeForce==0 && abs(air.speed-coast.speed)<1e-9,"Unsupported wheels cannot slow airborne chassis")
        }
        let cyclist=BikePhysics();cyclist.kind = .bmx
        for _ in 0..<120 {step(cyclist)}
        check(cyclist.pedalCadence>2 && cyclist.pedalPhase < -1,"BMX force and artwork need one forward pedalling phase")
        let poweredCadence=cyclist.pedalCadence
        for _ in 0..<120 {step(cyclist,gas:false)}
        check(cyclist.pedalCadence<poweredCadence*0.1,"Freewheeling must let the pedals settle")
        let bmxSpeed=BikePhysics();bmxSpeed.kind = .bmx;bmxSpeed.x = -9500
        for _ in 0..<120 {step(bmxSpeed)}
        check(bmxSpeed.speed*3.6>3 && bmxSpeed.speed*3.6<7,"BMX must build speed by pedalling rather than accelerate like a motorcycle")
        for _ in 0..<7080 {step(bmxSpeed);finite(bmxSpeed)}
        check(!bmxSpeed.crashed && abs(bmxSpeed.speed*3.6-35)<0.5,"BMX actual flat sprint speed must be about35km/h")
        let expectedCadence=bmxSpeed.speed/(bmxSpeed.kind.rig.wheelRadius*2.8)
        check(bmxSpeed.pedalCadence>11 && bmxSpeed.pedalCadence<15 && abs(bmxSpeed.pedalCadence-expectedCadence)<0.1,"BMX cadence must match fixed gearing at sprint speed")
        print("BMX measured flat sprint: \(bmxSpeed.speed*3.6) km/h")
        func stoppingDistance(route:Int)->Double {
            let b=BikePhysics();b.kind = .sport;b.route=route;b.speed=14
            for _ in 0..<1200 where b.speed>0.2 {step(b,gas:false,brake:true)}
            check(b.speed<0.21 && !b.crashed,"Surface brake test must stop safely")
            return b.x
        }
        let roadStop=stoppingDistance(route:0),sandStop=stoppingDistance(route:2)
        check(sandStop>roadStop*1.2,"Loose sand must need a materially longer stopping distance")
        print("Surface stopping distances at 14 m/s: road \(roadStop) m; sand \(sandStop) m")
        check(suspensionRanges[.motocross]!>suspensionRanges[.bmx]!*3,"Enduro and rigid BMX must not share suspension response")
        let slow=BikePhysics(),fast=BikePhysics();slow.route=1;fast.route=1
        for i in 0..<180 {step(slow,dt:1/30,jump:i%60<4)}
        for i in 0..<720 {step(fast,jump:i%240<16)}
        check(abs(slow.x-fast.x)<0.0001 && abs(slow.pitch-fast.pitch)<0.0001 && abs(slow.frontWheelPosition.y-fast.frontWheelPosition.y)<0.0001,"30/120 fps must produce matching dynamics")
        // Flat proving ground: measure actual force-integrated road speeds,
        // independently of the short progressive course or speedometer labels.
        var measured:[BikeKind:Double]=[:]
        for kind in BikeKind.allCases where kind != .bmx {
            let machine=BikePhysics();machine.kind=kind;machine.x = -9500
            for _ in 0..<7200 {step(machine,forward:machine.angle>0.12);finite(machine)}
            let kmh=machine.speed*3.6,target=kind.topSpeed*3.6
            check(!machine.crashed && abs(kmh-target)<1,"Actual road speed must match target: \(kind), \(kmh) vs \(target)")
            measured[kind]=kmh
            let brakeStart=machine.x
            for _ in 0..<2400 where machine.speed>0.2 {step(machine,gas:false,forward:machine.angle>0.2,brake:true);finite(machine)}
            check(!machine.crashed && machine.speed<0.21 && machine.x-brakeStart<500,"Every motorcycle must stop from its actual maximum: \(kind)")
        }
        check(measured[.hyperbike]!>290 && measured[.sport]!>235,"Requested superbike speeds must be achieved")
        print("Measured flat-road motorcycle speeds (km/h): \(measured)")
        let invalid=BikePhysics(),reference=invalid.chassisPosition
        for dt in [Double.nan,Double.infinity,-Double.infinity,0,-1] {step(invalid,dt:dt,jump:true)}
        check(invalid.chassisPosition==reference && invalid.speed==0,"Invalid time must not mutate dynamics")
        let capped=BikePhysics(),quarter=BikePhysics();step(capped,dt:50);step(quarter,dt:0.25)
        check(capped.chassisPosition==quarter.chassisPosition && capped.pitch==quarter.pitch,"A stall must cap simulated time")
        print("PhysicsTests passed: real two-wheel contacts, static sag, independent spring travel, \(BikeKind.allCases.count*3) progressive routes with cautious control, four rising sectors and continuous terrain, controlled wheelies/invertidos and recovery, BMX35km/h sprint, braking, landing impulse/compression, wreck settling, obstacle impulses, progressive controls, load/surface-limited traction and braking, airborne brakes, FPS and invalid deltas.")
        print("Front suspension ranges (m): \(suspensionRanges)")
    }
}
