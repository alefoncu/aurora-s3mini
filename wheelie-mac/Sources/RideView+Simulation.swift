import Cocoa

/// The frame loop: input to physics, obstacle collisions, rider animation, camera and dust.
extension RideView {
    func tick() {
        let now=ProcessInfo.processInfo.systemUptime,dt=min(0.05,max(0,now-previous)); previous=now
        if mode == .riding || mode == .crashing { animationTime += dt }
        if mode == .riding {
            let previousFront=bike.frontWheelPosition,previousRear=bike.rearWheelPosition,previousSpeed=bike.speed,previousVertical=bike.verticalVelocity
            bike.update(dt,throttle:held(.throttle),brake:held(.brake),leanBack:held(.leanBack),leanForward:held(.leanForward),jump:held(.jump),frontBrake:held(.frontBrake),rearBrake:held(.rearBrake),trick:held(.stunt),spin:spinHeld,noHands:noHandsHeld)
            elapsed += dt
            updateWeather()
            updateRival(dt)
            updateScoring(dt)
            challenges.update(frame:ghostSnapshot(),distance:bike.distance,wheelie:bike.wheelieDistance,
                stoppie:bike.stoppieDistance,airborne:!bike.frontContact && !bike.rearContact,
                height:bike.height,crashed:bike.crashed)
            updateCamera(dt)
            // A small inertial response complements deliberate weight transfer;
            // IK keeps grips/pegs fixed while the torso absorbs acceleration.
            let longitudinalAcceleration=dt>0 ? (bike.speed-previousSpeed)/dt : 0
            riderLean=max(-1,min(1,bike.riderShift-longitudinalAcceleration*0.025))
            let acceleration=dt>0 ? (bike.verticalVelocity-previousVertical)/dt : 0
            let airNow = !bike.frontContact && !bike.rearContact
            let wantHandsOff=noHandsHeld && bike.speed>6 && !airNow,wantSuperman=airNow && supermanHeld && !bike.crashed
            riderHandsOff+=((wantHandsOff ? 1 : 0)-riderHandsOff)*min(1,dt*9); riderSuperman+=((wantSuperman ? 1 : 0)-riderSuperman)*min(1,dt*9)
            let targetLift=(bike.kind == .trials ? 0.4 : bike.kind == .motocross ? 0.18 : bike.kind == .bmx ? 0.14 : 0.04)+(held(.jump) ? 0.22 : 0)
            riderLiftVelocity += ((targetLift-riderLift)*55-riderLiftVelocity*12-max(-20,min(20,acceleration))*0.10)*dt
            riderLift=max(0,min(1,riderLift+riderLiftVelocity*dt))
            if bike.kind == .bmx { pedalPhase=bike.pedalPhase }
            if obstaclesOn && !bike.finished && !bike.crashed {
                for world in BikePhysics.window(obstacleList,from:bike.x-6,to:bike.x+6) where !knockedCones.contains(world) {
                    if abs(Double(world)-bike.x)>4 { continue }
                    if bike.lane != 0 && BikePhysics.fork(containing:Double(world)) != nil { continue }   // under the elevated road
                    let ground=BikePhysics.ground(Double(world),route:bike.route),kind=BikePhysics.obstacleKind(at:world)
                    let weight=kind == .barrel ? 1.2 : kind == .log ? 0.8 : 1.0
                    if sweptWheelHit(previousFront,bike.frontWheelPosition,obstacle:RideVector(Double(world),ground),radius:bike.kind.rig.wheelRadius,shape:kind) {
                        bike.strikeObstacle(front:true,severity:min(1.5,(0.25+bike.speed/18)*weight)); knockedCones.insert(world); audio.impact(); emitDust(count:5)
                    } else if sweptWheelHit(previousRear,bike.rearWheelPosition,obstacle:RideVector(Double(world),ground),radius:bike.kind.rig.wheelRadius,shape:kind) {
                        bike.strikeObstacle(front:false,severity:min(1.5,(0.2+bike.speed/20)*weight)); knockedCones.insert(world); audio.impact(); emitDust(count:5)
                    }
                }
            }
            if bike.landingImpact>0.7 { emitDust(count:min(15,Int(bike.landingImpact*3))); audio.impact() }
            dustClock += dt
            if dustClock>0.06 && bike.speed>2 && bike.rearContact { emitDust(count:abs(bike.rearSlip)>0.2 ? 4 : bike.route==0 ? 1 : 2); dustClock=0 }
            if !bike.crashed {
                let follow=1-exp(-dt/0.22)
                riderVelocity += (RideVector(bike.speed,bike.verticalVelocity)-riderVelocity)*follow
            }
            if bike.crashed {
                let pose=RiderRig.solve(vehicle:bike.kind.rig,lean:riderLean,lift:riderLift,pedalPhase:pedalPhase,cycling:bike.kind == .bmx)
                // The rider leaves with what they were carrying (never less than the bike's own speed), and only a part of the bike's spin.
                let velocity=RideVector(max(0,min(38,max(riderVelocity.x,previousSpeed*0.7))),max(-6,min(4,riderVelocity.y)))
                let spin=max(-7,min(7,bike.angularVelocity*0.8))
                ragdoll=RiderRagdoll(pose:pose,origin:bike.chassisPosition,pitch:bike.pitch,velocity:velocity,angularVelocity:spin,route:bike.route)
                if art.passenger && bike.kind.supportsPassenger {
                    let companion=RiderRig.solve(vehicle:bike.kind.rig,lean:riderLean*0.3,lift:riderLift,passenger:true)
                    passengerRagdoll=RiderRagdoll(pose:companion,origin:bike.chassisPosition,pitch:bike.pitch,velocity:velocity,angularVelocity:spin,route:bike.route)
                }
                score.crash(); mode = .crashing; crashTime=0; clearInput(); audio.impact(); emitDust(count:16); saveRun(); syncState()
            } else if bike.finished { score.finishRun(); playerFinishTime=elapsed; racePosition=RideRace.position(player:playerEntry,rivals:rivalEntries); challenges.raceWon = !rivalRuns.isEmpty && racePosition<=(challengeKind == .circuit ? 2 : 1); mode = .result; clearInput(); saveRun(); syncState() }
        } else if mode == .crashing {
            bike.update(dt,throttle:false,brake:false,leanBack:false,leanForward:false)
            let wheel=bike.kind.rig.wheelRadius*0.95
            var solid:[(centre:RideVector,radius:Double)]=[(bike.rearWheelPosition,wheel),(bike.frontWheelPosition,wheel),(bike.chassisPosition,0.28)]
            // Terrain obstacles near the tumbling rider are solid too (cones, barrels and logs as circles resting on the ground).
            if obstaclesOn,let hip=ragdoll?.pose.hip {
                for world in BikePhysics.window(obstacleList,from:hip.x-5,to:hip.x+5) where !knockedCones.contains(world) {
                    if bike.lane != 0 && BikePhysics.fork(containing:Double(world)) != nil { continue }
                    let radius:Double
                    switch BikePhysics.obstacleKind(at:world) { case .cone: radius=0.2; case .barrel: radius=0.32; case .log: radius=0.17 }
                    solid.append((RideVector(Double(world),BikePhysics.ground(Double(world),route:bike.route)+radius*0.9),radius))
                }
            }
            ragdoll?.lane=bike.lane; passengerRagdoll?.lane=bike.lane
            ragdoll?.colliders=solid; passengerRagdoll?.colliders=solid
            ragdoll?.update(dt); passengerRagdoll?.update(dt)
            // The camera follows the rider once they are well away from the bike.
            if let hip=ragdoll?.pose.hip {
                // Frame both: aim at the midpoint between the bike and the rider once they are apart.
                let away=hip.x-bike.x,target=abs(away)>3 ? away*0.55 : 0
                crashCamShift += (max(-20,min(30,target))-crashCamShift)*min(1,dt*6)
            }
            updateCamera(dt)
            crashTime += dt
            if crashTime>1.8 { mode = .result; syncState() }
        }
        if mode == .riding || mode == .crashing {
            for i in dust.indices { dust[i].x += dust[i].vx*dt; dust[i].y += dust[i].vy*dt; dust[i].vy -= 2*dt; dust[i].life -= dt }
            dust.removeAll { $0.life<=0 }
        }
        audio.setAmbient(route:bike.route,speed:bike.speed,rain:weather.rain)
        audio.update(speed:bike.speed,throttle:held(.throttle),vehicle:bike.kind.audioProfile,active:mode == .riding,rpm:bike.transmission.rpm,load:bike.throttlePosition,shifting:bike.transmission.shiftRemaining>0,slip:max(abs(bike.frontSlip),abs(bike.rearSlip)),timbre:bike.kind.engineVoice)
        updateTouchBar()
        if mode == .riding || mode == .crashing { needsDisplay=true }
    }
    func updateCamera(_ dt:Double) {
        // Keep roughly 0.65 s of road ahead at high speed for every vehicle.
        let zoom=min(1,max(0.15,13/max(13,bike.speed)))
        art.metresToPixels += (RideScene.metresToPixels*zoom-art.metresToPixels)*(1-exp(-dt*2.5))
        let target=(BikePhysics.ground(bike.x,route:bike.route,lane:bike.lane)+max(0,bike.height-0.35)*0.35)*art.metresToPixels
        cameraY += (target-cameraY)*min(1,dt*5)
    }
    private func sweptWheelHit(_ a:RideVector,_ b:RideVector,obstacle:RideVector,radius:Double,shape:BikePhysics.ObstacleKind = .cone)->Bool {
        let outline:[RideVector]
        switch shape {
        case .cone: outline=[RideVector(-0.14,0.02),RideVector(0,0.315),RideVector(0.14,0.02)]
        case .barrel: outline=[RideVector(-0.2,0.02),RideVector(-0.2,0.55),RideVector(0.2,0.55),RideVector(0.2,0.02)]
        case .log: outline=[RideVector(-0.48,0.02),RideVector(-0.4,0.27),RideVector(0.4,0.27),RideVector(0.48,0.02)]
        }
        let triangle=outline.map { obstacle+$0 }
        func distance(_ p:RideVector,_ a:RideVector,_ b:RideVector)->Double {
            let d=b-a,l=d.x*d.x+d.y*d.y
            let t=l>0 ? max(0,min(1,((p-a).x*d.x+(p-a).y*d.y)/l)) : 0
            let delta=p-(a+d*t); return hypot(delta.x,delta.y)
        }
        let n=max(1,Int(ceil(hypot(b.x-a.x,b.y-a.y)/max(0.04,radius*0.45))))
        for i in 0...n {
            let p=a+(b-a)*Double(i)/Double(n)
            for j in 0..<triangle.count where distance(p,triangle[j],triangle[(j+1)%triangle.count])<radius { return true }
        }
        return false
    }
    func emitDust(count:Int) {
        for _ in 0..<count where dust.count<90 {
            let life=Double.random(in:0.35...0.9),rear=bike.rearWheelPosition
            dust.append(Dust(x:rear.x-0.08,y:max(0,rear.y-bike.kind.rig.wheelRadius-BikePhysics.ground(rear.x,route:bike.route)),vx:Double.random(in:-1.0 ... -0.15),vy:Double.random(in:0.1...0.6),life:life,maxLife:life))
        }
    }
}
