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
        // Air tricks: T on take-off adds hang time; holding T in the air rotates the bike, and
        // releasing it after the half-turn commits the flip and levels the bike for landing.
        // Every vehicle must land a clean frontflip and backflip from a standing jump.
        do {
            func flipJump(_ kind:BikeKind,dir:Double,trick:Bool)->BikePhysics {
                let b=BikePhysics();b.kind=kind;b.route=0;b.x = -500;b.speed=8
                for _ in 0..<120 {step(b,gas:false)}
                var released=false
                for i in 0..<500 {
                    let air = !b.rearContact && !b.frontContact
                    var fwd=false,back=false
                    if trick && air { if abs(b.airRotation)<3.4 && !released { back=dir<0; fwd=dir>0 } else { released=true } }
                    b.update(frame,throttle:false,brake:false,leanBack:back,leanForward:fwd,jump:i==0,trick:trick && !released)
                    finite(b)
                    if b.crashed { break }
                }
                return b
            }
            for kind in BikeKind.allCases {
                let plain=flipJump(kind,dir:1,trick:false)
                check(!plain.crashed && plain.lastFlips==0,"A standing jump without T must not flip: \(kind)")
                for dir in [-1.0,1.0] {
                    let b=flipJump(kind,dir:dir,trick:true)
                    check(!b.crashed && b.lastFlips==1 && b.landingSerial>0,"\(kind) must land a \(dir<0 ? "back" : "front")flip (flips=\(b.lastFlips), crashed=\(b.crashed))")
                    check(b.lastAirTime>0.5 && b.lastAirHeight>0.3,"Landing must report air time and height: \(kind)")
                }
            }
        }
        // Spin 360: hold G in the air; the landing counts the full turns.
        do {
            func spinJump(hold:Double)->BikePhysics {
                let b=BikePhysics();b.kind = .bmx;b.route=0;b.x = -500;b.speed=8
                for _ in 0..<120 {step(b,gas:false)}
                var t=0.0
                for i in 0..<500 {
                    let air = !b.rearContact && !b.frontContact
                    if air { t+=frame }
                    b.update(frame,throttle:false,brake:false,leanBack:false,leanForward:false,jump:i==0,trick:true,spin:air && t<hold)
                    finite(b);if b.crashed { break }
                }
                return b
            }
            let full=spinJump(hold:0.55),none=spinJump(hold:0)
            check(!full.crashed && full.lastSpins==1,"A held spin must land a 360 (spins=\(full.lastSpins), crashed=\(full.crashed))")
            check(!none.crashed && none.lastSpins==0,"No spin input, no spin")
        }
        // No-hands: weight shifts and the front brake are ignored, so a wheelie is not corrected.
        do {
            let hands=BikePhysics(),free=BikePhysics()
            hands.kind = .commuter;free.kind = .commuter
            for b in [hands,free] { b.x = -500;b.speed=10 }
            for _ in 0..<120 {
                hands.update(frame,throttle:false,brake:false,leanBack:true,leanForward:false,noHands:true)
                free.update(frame,throttle:false,brake:false,leanBack:true,leanForward:false)
            }
            check(abs(hands.angle)<0.05 && free.angle>0.05 || hands.angle<free.angle,"Hands off the bars must disable the weight shift")
        }
        // Wear: sliding wears tyres and bumps heat the dampers; a reset restores both.
        do {
            let b=BikePhysics();b.kind = .sport;b.route=3;b.x = -500;b.speed=22
            for _ in 0..<400 {step(b,gas:false,brake:true)}
            check(b.tyreWear>0.01,"Braking slip on snow must wear the tyres (\(b.tyreWear))")
            let worn=b.tyreWear
            check(worn<=1,"Wear is bounded")
            let rough=BikePhysics();rough.kind = .motocross;rough.route=1
            for _ in 0..<12000 where !rough.finished && !rough.crashed { step(rough,back:rough.angle < -0.25,forward:rough.angle>0.25,brake:rough.speed>8) }
            check(rough.suspensionHeat>0.01 && rough.suspensionHeat<=1,"A rough route must heat the dampers (\(rough.suspensionHeat))")
            rough.reset();b.reset()
            check(rough.suspensionHeat==0 && b.tyreWear==0,"Reset clears wear and heat")
        }
        // Endless: no finish line, the same bike keeps riding past 1,200 m.
        do {
            let b=BikePhysics();b.kind = .sport;b.endless=true
            b.x=1190
            for _ in 0..<1200 {step(b,gas:true,back:b.angle < -0.25,forward:b.angle>0.25);if b.crashed {break}}
            check(!b.finished && (b.crashed || b.x>1210),"Endless mode must not finish at 1,200 m")
            check(BikePhysics.endlessObstaclePositions.count>BikePhysics.obstaclePositions.count && BikePhysics.endlessObstaclePositions.last!>5000,"Endless obstacle field")
        }
        // Difficulty modes: assisted levels flips for landing and forgives tilt, realistic never levels
        // a flip for you; tyre wear scales 0.5x / 1x / 2x; coin multipliers rise with difficulty.
        do {
            var landed:[BikePhysics.Assist:Int]=[:],survived:[BikePhysics.Assist:Int]=[:],crashTime:[BikePhysics.Assist:Double]=[:],wear:[BikePhysics.Assist:Double]=[:]
            for assist in BikePhysics.Assist.allCases {
                for kind in BikeKind.allCases {
                    let flip=BikePhysics();flip.assist=assist;flip.kind=kind;flip.route=0;flip.x = -500;flip.speed=8
                    for _ in 0..<120 {step(flip,gas:false)}
                    var released=false
                    for i in 0..<500 {
                        let air = !flip.rearContact && !flip.frontContact
                        var back=false
                        if air { if abs(flip.airRotation)<3.4 && !released { back=true } else { released=true } }
                        flip.update(frame,throttle:false,brake:false,leanBack:back,leanForward:false,jump:i==0,trick:!released)
                        if flip.crashed { break }
                    }
                    if !flip.crashed && flip.lastFlips==1 { landed[assist,default:0]+=1 }
                    let hop=BikePhysics();hop.assist=assist;hop.kind=kind;hop.route=0;hop.x = -500;hop.speed=8
                    for _ in 0..<120 {step(hop,gas:false)}
                    for i in 0..<500 {
                        let air = !hop.rearContact && !hop.frontContact
                        hop.update(frame,throttle:false,brake:false,leanBack:air,leanForward:false,jump:i==0)
                        if hop.crashed { break }
                    }
                    if !hop.crashed { survived[assist,default:0]+=1 }
                    let wheelie=BikePhysics();wheelie.assist=assist;wheelie.kind=kind;var t=0.0
                    for _ in 0..<2400 where !wheelie.crashed { step(wheelie,back:true);t+=frame }
                    crashTime[assist,default:0]+=t/8
                }
                let b=BikePhysics();b.assist=assist;b.kind = .sport;b.route=3;b.x = -500;b.speed=22
                for _ in 0..<400 {step(b,gas:false,brake:true)}
                wear[assist]=b.tyreWear
            }
            check((landed[.realistic] ?? 0)<=1 && (landed[.normal] ?? 0)>=7 && (landed[.assisted] ?? 0)==8,"Flip landings by mode: \(landed)")
            check((survived[.assisted] ?? 0)==8 && (survived[.assisted] ?? 0)>=(survived[.normal] ?? 0),"Assisted survives a leaning hop everywhere: \(survived)")
            check(crashTime[.assisted]!>crashTime[.normal]! && crashTime[.normal]!>crashTime[.realistic]!,"Tilt tolerance grows with assistance: \(crashTime)")
            check(wear[.assisted]!<wear[.normal]! && wear[.normal]!<wear[.realistic]!,"Tyre wear grows with difficulty: \(wear)")
            check(BikePhysics.Assist.allCases.map(\.coinMultiplier)==[0.75,1,1.25] && BikePhysics.Assist.allCases.allSatisfy { !$0.detail.isEmpty },"Mode descriptions and multipliers")
        }
        // Wet patches cut grip; ABS never needs a longer stop than locked brakes.
        do {
            check(BikePhysics.puddleFactor(BikePhysics.puddlePositions[0] == 0 ? 1 : Double(BikePhysics.puddlePositions[0]))<0.7,"Puddle centre must cut grip")
            check(BikePhysics.puddleFactor(-50)==1 && BikePhysics.puddleFactor(.nan)==1,"Dry ground and invalid x must be unaffected")
            func stop(abs absOn:Bool,hazards:Bool)->Double {
                let b=BikePhysics();b.kind = .sport;b.route=2;b.absEnabled=absOn;b.hazards=hazards
                b.x=Double(BikePhysics.puddlePositions[1])-3;b.speed=24
                for _ in 0..<6 {step(b,gas:false)}
                let start=b.x;var n=0
                while b.speed>0.2 && n<4000 {step(b,gas:false,brake:true);n+=1}
                return b.x-start
            }
            check(stop(abs:false,hazards:true)>stop(abs:false,hazards:false),"Puddles must lengthen the braking distance")
            func flatStop(abs absOn:Bool)->Double {
                let b=BikePhysics();b.kind = .sport;b.route=3;b.absEnabled=absOn
                b.x = -500;b.speed=24
                for _ in 0..<6 {step(b,gas:false)}
                let start=b.x;var n=0
                while b.speed>0.2 && n<6000 {step(b,gas:false,brake:true);n+=1}
                return b.x-start
            }
            check(flatStop(abs:true)<flatStop(abs:false)-1,"ABS must shorten braking on snow")
        }
        // Obstacle mix is deterministic and gets richer with the sectors.
        do {
            let kinds=BikePhysics.obstaclePositions.map { BikePhysics.obstacleKind(at:$0) }
            check(Set(kinds.prefix(while:{BikePhysics.difficultyStage(at:0)==0 && $0 == .cone})).count==1,"First obstacles are cones")
            check(kinds.contains(.barrel) && kinds.contains(.log),"Later sectors must include barrels and logs")
            for p in BikePhysics.obstaclePositions where BikePhysics.difficultyStage(at:Double(p))==0 { check(BikePhysics.obstacleKind(at:p)==BikePhysics.ObstacleKind.cone,"Sector 1 has only cones") }
        }
        // Closed circuit: seamless terrain, steady difficulty, a finish after the last lap.
        do {
            BikePhysics.circuit=true
            defer { BikePhysics.circuit=false }
            let length=BikePhysics.circuitLength
            for route in 0..<BikePhysics.routeCount {
                for i in 0...2400 {
                    let x=Double(i)*0.5,y=BikePhysics.ground(x,route:route),sl=BikePhysics.slope(x,route:route)
                    check(y.isFinite && abs(sl)<0.75,"Circuit slopes stay readable: route \(route) x=\(x) slope=\(sl)")
                    check(abs(BikePhysics.ground(x+length,route:route)-y)<1e-9,"Terrain repeats every lap: route \(route) x=\(x)")
                }
                check(abs(BikePhysics.ground(length-0.001,route:route)-BikePhysics.ground(length+0.001,route:route))<0.001,"Ground is continuous across the seam: route \(route)")
                check(abs(BikePhysics.slope(length-0.01,route:route)-BikePhysics.slope(length+0.01,route:route))<0.01,"Slope is continuous across the seam: route \(route)")
                check(abs(BikePhysics.ground(0,route:route)-BikePhysics.ground(1200,route:route))<1e-9,"Start and finish share a height")
            }
            check(BikePhysics.difficultyStage(at:1)==2 && BikePhysics.difficultyStage(at:3000)==2,"Steady circuit difficulty")
            let list=BikePhysics.circuitObstaclePositions(laps:3)
            check(list.count==78 && list == list.sorted() && Set(list).count==list.count && list.first!>=140 && list.last!<3600,"Circuit obstacles: \(list.count)")
            for kind in BikeKind.allCases { for route in 0..<BikePhysics.routeCount {
                let b=BikePhysics();b.kind=kind;b.route=route;b.laps=2;b.reset()
                check(b.finishDistance==2400,"Finish distance is laps x length")
                var laps=0.0
                for _ in 0..<80_000 where !b.finished && !b.crashed {
                    let target=min(kind.topSpeed*0.85,((route == 0 || route == 4) ? 16.0 : 12.0)-2*1.2)
                    step(b,gas:b.speed<target,back:b.angle < -0.25,forward:b.angle>0.25,brake:b.speed>target+0.6);finite(b)
                    laps=max(laps,b.x)
                }
                check(b.finished && !b.crashed && abs(b.distance-2400)<0.0001,"Two circuit laps must finish: \(kind) route \(route) x=\(b.x)")
            } }
        }
        check(BikePhysics().finishDistance==BikePhysics.finish && !BikePhysics.circuit,"The circuit switch is off by default")
        let obstacles=BikePhysics.obstaclePositions
        check(Set(obstacles).count==obstacles.count && obstacles==obstacles.sorted(),"One sorted collision/render obstacle schedule")
        let sectorCounts=(0..<4).map { stage in obstacles.filter { BikePhysics.difficultyStage(at:Double($0))==stage }.count }
        check(zip(sectorCounts,sectorCounts.dropFirst()).allSatisfy { $0 < $1 },"Obstacle density must rise each sector")
        for route in 0..<BikePhysics.routeCount {
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
            for route in 0..<BikePhysics.routeCount {
                b.route=route;b.reset();var minCompression=Double.infinity,maxCompression=0.0
                for _ in 0..<60000 where !b.finished && !b.crashed {
                    // A readable cautious rider: slow progressively on rougher
                    // sectors and correct pitch, without privileged terrain lookahead.
                    let stage=Double(BikePhysics.difficultyStage(at:b.x))
                    let target=min(kind.topSpeed*0.85,(route == 0 ? 16.0 : 12.0)-stage*1.2)
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
