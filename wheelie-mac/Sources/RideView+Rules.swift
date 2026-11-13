import Cocoa

/// Run rules: per-run state, rival, scoring, tricks, missions bookkeeping and the guided tutorial.
extension RideView {
    func resetRunState() {
        score.reset(); rewarded=false; lastReward=0; lastWheelie=0; lastStoppie=0; lastLandingSerial=bike.landingSerial; lastStage=0
        passedObstacles.removeAll(); splitDeltas.removeAll(); splitText=""; splitAge=99
        report=RunReport(); reported=false; runNotes.removeAll(); riderHandsOff=0; riderSuperman=0; supermanTime=0; lastSupermanTime=0; airborneWas=false
        tutorial=RideTutorial(); tutorialToast=""; tutorialToastAge=99; lapTimes.removeAll(); lapStart=0
        toasts.removeAll(); toastedIDs.removeAll(); toastClock=0; lastBanked=0; lastMultiplier=1
        weather=WeatherState(); lastWeatherTime=0; bike.wetness=0
    }
    /// One rival in a duel, three on the circuit (around the chosen level), each with its own vehicle and seed.
    func startRival() {
        rivalRuns=[]; rivalFinishTimes=[]; playerFinishTime=nil; overtakeTracker.reset(); racePosition=1
        guard challengeKind == .race || challengeKind == .circuit else { return }
        let levels = challengeKind == .circuit ? rivalLevel.field() : [rivalLevel]
        let others=BikeKind.allCases.filter { $0 != bike.kind }
        for (i,level) in levels.enumerated() {
            // Same vehicle as the player unless asked otherwise; then a different one per rival, changing each run.
            let kind = rivalSameVehicle ? bike.kind : others[(stats.totals.runs*7+bike.route+i*3)%others.count]
            rivalRuns.append(RideRival(level:level,kind:kind,route:bike.route,hazards:obstaclesOn,seed:UInt64(stats.totals.runs+1+i*977)*2_654_435_761,laps:bike.laps))
        }
        rivalFinishTimes=Array(repeating:nil,count:rivalRuns.count)
    }
    /// Weather at the player's place in the course; the city keeps its steady rain even when dynamic weather is off.
    func updateWeather() {
        let lapX=BikePhysics.circuit || bike.endless ? bike.x.truncatingRemainder(dividingBy:1200) : bike.x
        if weatherOn { weather=RideWeather.state(route:bike.route,x:lapX,time:elapsed,seed:weatherSeed) }
        else { weather=WeatherState(); if bike.route == 4 { weather.rain=1 } }
        bike.wetness=weather.wetness
        if weather.storm { for _ in 0..<RideWeather.thunderCount(from:lastWeatherTime,to:elapsed,seed:weatherSeed) { audio.play(.thunder) } }
        lastWeatherTime=elapsed
    }
    func updateRival(_ dt:Double) {
        for (i,r) in rivalRuns.enumerated() {
            r.bike.wetness=weatherOn ? RideWeather.state(route:bike.route,x:r.bike.x,time:elapsed,seed:weatherSeed).wetness : (bike.route == 4 ? 1 : 0)
            r.update(dt)
            if r.finished && rivalFinishTimes[i] == nil { rivalFinishTimes[i]=elapsed }
        }
        guard !rivalRuns.isEmpty else { return }
        racePosition=RideRace.position(player:playerEntry,rivals:rivalEntries)
        for event in overtakeTracker.update(player:bike.distance,rivals:rivalEntries) {
            if event.playerPassed {
                score.add(.overtake,points:RideScore.overtake,label:"Adelantamiento")
                toasts.append(Toast(text:"Adelantas al rival \(event.rival+1) · vas \(racePosition)º",age:0)); audio.play(.combo,intensity:0.6)
            } else { toasts.append(Toast(text:"El rival \(event.rival+1) te adelanta · vas \(racePosition)º",age:0)) }
            if toasts.count>3 { toasts.removeFirst(toasts.count-3) }
        }
    }
    /// The run as it stands now, for previewing rewards before it ends.
    var liveReport:RunReport {
        var r=report
        r.distance=bike.distance; r.score=score.total; r.bestCombo=max(r.bestCombo,score.bestChain); r.endless=bike.endless
        r.finished=bike.finished; r.crashed=bike.crashed
        return r
    }
    /// Pop a toast the moment an achievement or mission is within reach. Coins are paid when the run ends.
    func updateToasts(_ dt:Double) {
        for i in toasts.indices { toasts[i].age+=dt }
        toasts.removeAll { $0.age>4 }
        toastClock+=dt
        guard toastClock>=0.4,mode == .riding else { return }
        toastClock=0
        let live=liveReport
        for a in stats.preview(live) where !toastedIDs.contains("a."+a.id) {
            toastedIDs.insert("a."+a.id); toasts.append(Toast(text:"Logro: \(a.title)"+(a.reward>0 ? " (+\(a.reward))" : ""),age:0)); audio.play(.chime)
        }
        for m in missions.preview(live) where !toastedIDs.contains("m."+m.title) {
            toastedIDs.insert("m."+m.title); toasts.append(Toast(text:"Misión cumplida: \(m.title) (+\(m.reward))",age:0)); audio.play(.chime)
        }
        if toasts.count>3 { toasts.removeFirst(toasts.count-3) }
    }
    func updateScoring(_ dt:Double) {
        defer { updateToasts(dt) }
        guard !bike.crashed else { return }
        let wheelie=bike.wheelieDistance,stoppie=bike.stoppieDistance
        if wheelie>lastWheelie { score.accrue(.wheelie,points:RideScore.wheelie(metres:wheelie-lastWheelie)) }
        if stoppie>lastStoppie { score.accrue(.stoppie,points:RideScore.stoppie(metres:stoppie-lastStoppie)) }
        if wheelie>lastWheelie { report.wheelieMetres+=wheelie-lastWheelie }
        if stoppie>lastStoppie { report.stoppieMetres+=stoppie-lastStoppie }
        lastWheelie=wheelie; lastStoppie=stoppie
        if noHandsHeld && bike.speed>6 && (bike.rearContact || bike.frontContact) {
            report.noHandsSeconds+=dt; score.accrue(.noHands,points:RideScore.noHands(seconds:dt))
        }
        // Superman: hold V in the air; the time is banked at the landing.
        if !bike.frontContact && !bike.rearContact { if supermanHeld { supermanTime+=dt; lastSupermanTime=supermanTime } } else { supermanTime=0 }
        if bike.landingSerial != lastLandingSerial {
            lastLandingSerial=bike.landingSerial
            let flips=bike.lastFlips
            let spins=bike.lastSpins
            if spins>0 { report.spins+=spins; score.add(.spin,points:RideScore.spins(spins),label:spins == 1 ? "Giro 360°" : "\(spins) giros 360°") }
            if lastSupermanTime>=0.4 { report.supermans+=1; score.add(.superman,points:RideScore.superman(seconds:lastSupermanTime),label:"Superman") }
            lastSupermanTime=0
            if flips>0 { audio.play(.flip) }
            else if spins>0 { audio.play(.whoosh) }
            else if bike.lastAirTime>=0.35 { audio.play(.landing) }
            if flips>0 { report.flips+=flips; score.add(.flip,points:RideScore.flips(flips),label:flips == 1 ? "Voltereta" : "\(flips) volteretas") }
            let jump=RideScore.jump(airTime:bike.lastAirTime,height:bike.lastAirHeight)
            if jump>0 { report.jumps+=1; report.airTime+=bike.lastAirTime; score.add(.jump,points:jump,label:String(format:"Salto %.1f s",bike.lastAirTime)) }
        }
        if obstaclesOn { for world in obstacleList where !passedObstacles.contains(world) && !knockedCones.contains(world) && Double(world)<bike.x-1 {
            passedObstacles.insert(world); report.dodges+=1; score.add(.cone,points:RideScore.coneDodge,label:"Obstáculo esquivado")
        } }
        let airborne = !bike.frontContact && !bike.rearContact
        score.tick(dt:dt,busy:wheelie>0.2 || stoppie>0.2 || (airborne && bike.airTime>0.2) || (noHandsHeld && bike.speed>6))
        tutorialToastAge+=dt
        if challengeKind == .tutorial {
            var o=TutorialObservation(); o.speed=bike.speed; o.wheelieDistance=bike.wheelieDistance; o.rearContact=bike.rearContact; o.frontContact=bike.frontContact
            o.brakeHeld=held(.brake); o.crashed=bike.crashed; o.landingSerial=bike.landingSerial; o.lastAirTime=bike.lastAirTime; o.lastFlips=bike.lastFlips; o.dt=dt
            if tutorial.update(o) {
                tutorialToast=tutorial.finished ? "¡Tutorial completado!" : "Paso \(tutorial.stepNumber-1) conseguido"; tutorialToastAge=0; audio.play(tutorial.finished ? .chime : .coin)
                if tutorial.finished && !stats.totals.tutorialDone { progress.earn(40); lastReward+=40; runNotes.append("Tutorial completado (+40)"); for a in stats.markTutorialDone() where a.reward>0 { progress.earn(a.reward) } }
            }
        }
        if BikePhysics.circuit {
            // Laps: record each lap time and compare it with the ghost at the same point.
            let lap=min(bike.laps,Int(bike.x/BikePhysics.circuitLength))
            if lap>lastStage {
                lastStage=lap
                let time=elapsed-lapStart; lapStart=elapsed; lapTimes.append(time)
                let delta=challenges.timeDelta(elapsed:elapsed,atDistance:Double(lap)*BikePhysics.circuitLength)
                splitDeltas.append(delta)
                splitText=String(format:"Vuelta %d · %d:%04.1f",lap,Int(time)/60,time.truncatingRemainder(dividingBy:60))+(delta.map { String(format:" · %+.1f s vs fantasma",$0) } ?? "")
                splitAge=0
            }
        } else {
        let stage=BikePhysics.difficultyStage(at:bike.x)
        if stage>lastStage {
            lastStage=stage
            let delta=challenges.timeDelta(elapsed:elapsed,atDistance:Double(stage*300))
            splitDeltas.append(delta)
            splitText=delta.map { String(format:"Tramo %d · %+.1f s vs fantasma",stage,$0) } ?? "Tramo \(stage) completado"
            splitAge=0
        }
        }
        splitAge+=dt
        // Banking a chain pays out with a coin sound; each rise of the multiplier ticks higher.
        if score.banked>lastBanked { audio.play(.coin) }
        lastBanked=score.banked
        if score.multiplier>lastMultiplier+0.01 { audio.play(.combo,intensity:min(1,(score.multiplier-1)/2)) }
        lastMultiplier=score.multiplier
    }
}
