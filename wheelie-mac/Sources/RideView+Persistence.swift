import Cocoa

/// Record contexts, ghost snapshots and once-only settlement of run rewards.
extension RideView {
    var runContext:String {
        "v6.\(bike.kind.rawValue).\(bike.route).\(obstacles ? "cones" : "clear").\(bike.transmission.automatic ? "auto" : "manual").\(Int((bike.suspensionStiffness*100).rounded())).\(Int((bike.suspensionDamping*100).rounded()))\(absOn ? ".abs" : "")\(weatherOn ? ".clima" : "")\(difficulty == .normal ? "" : ".\(difficulty.title.lowercased())")\(challengeKind == .endless ? ".endless" : "")\(activeRouteLength>1200 && challengeKind != .endless ? ".len\(Int(activeRouteLength))" : "")\(challengeKind == .circuit ? ".circuit\(bike.laps)" : "")"
    }
    var recordKey:String { runContext }
    func ghostSnapshot()->RideGhostFrame {
        RideGhostFrame(time:elapsed,x:bike.x,y:bike.chassisPosition.y,pitch:bike.pitch,
            rearWheelX:bike.rearWheelPosition.x,rearWheelY:bike.rearWheelPosition.y,
            frontWheelX:bike.frontWheelPosition.x,frontWheelY:bike.frontWheelPosition.y,
            wheelRotation:bike.rearWheelRotation,speed:bike.speed,lane:bike.lane)
    }
    func preserveRun() {
        if mode != .garage { saveRun(ending:true) }
    }
    func loadRecords() {
        record=prefs.double(forKey:recordKey+".distance"); best=prefs.double(forKey:recordKey+".wheelie")
        bestTime=prefs.double(forKey:recordKey+".time"); bestStoppie=prefs.double(forKey:recordKey+".stoppie"); bestScore=prefs.double(forKey:recordKey+".score")
    }
    /// Credit each award once and count only coins actually credited to the wallet.
    func awardCoins(_ coins:Int) {
        guard coins>0 else { return }
        let before=progress.wallet
        progress.earn(coins)
        let paid=progress.wallet-before
        lastReward+=paid; stats.addCoinsEarned(paid)
    }
    func saveRun(ending:Bool=false) {
        guard let key=runRecordKey else { return }
        let natural=bike.finished || bike.crashed
        if natural { challenges.finish(routeCompleted:bike.finished,elapsed:elapsed) }
        func high(_ suffix:String,_ value:Double) {
            prefs.set(max(prefs.double(forKey:key+suffix),value),forKey:key+suffix)
        }
        high(".distance",bike.distance);high(".wheelie",bike.bestWheelie);high(".stoppie",bike.bestStoppie)
        // An unfinished open chain is still at risk: do not preserve it as a score record on restart.
        let savedScore=natural ? score.total : score.banked
        high(".score",Double(savedScore))
        if !rewarded && natural {
            rewarded=true
            awardCoins(RideProgress.reward(distanceCoins:bike.coins,score:score.total,multiplier:runCoinMultiplier))
        }
        if !reported && (natural || (ending && bike.distance>50)) {
            reported=true
            report.distance=bike.distance; report.score=savedScore; report.bestCombo=max(report.bestCombo,score.bestChain)
            report.finished=bike.finished; report.crashed=bike.crashed; report.endless=bike.endless
            // A podium completes the circuit challenge; only first place is a race victory.
            report.raceWon=bike.finished && !rivalRuns.isEmpty && racePosition == 1
            for a in stats.record(report) { awardCoins(a.reward); runNotes.append("Logro: \(a.title)"+(a.reward>0 ? " (+\(a.reward))" : "")) }
            for m in missions.record(report) { awardCoins(m.reward); runNotes.append("Misión: \(m.title) (+\(m.reward))") }
            if !rivalRuns.isEmpty {
                let prize=bike.finished ? RideRace.prize(position:racePosition,fieldSize:rivalRuns.count+1) : 0
                if prize>0 { awardCoins(prize); runNotes.append("Premio de posición \(racePosition)º (+\(prize))") }
            }
        }
        let time=prefs.double(forKey:key+".time")
        if bike.finished && (time==0 || elapsed<time) { prefs.set(elapsed,forKey:key+".time") }
        if key == recordKey { loadRecords() }
    }
}
