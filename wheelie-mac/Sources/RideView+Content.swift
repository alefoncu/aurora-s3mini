import Cocoa

/// Hidden stars, workshop puzzles, the pilot's diary and local leaderboards, wired into the ride.
extension RideView {
    var secretsFound:Set<String> {
        get { Set(prefs.stringArray(forKey:"secrets.found") ?? []) }
        set { prefs.set(Array(newValue).sorted(),forKey:"secrets.found") }
    }
    var solvedPuzzles:Set<String> {
        get { Set(prefs.stringArray(forKey:"puzzles.solved") ?? []) }
        set { prefs.set(Array(newValue).sorted(),forKey:"puzzles.solved") }
    }
    /// Pick up a star when the bike passes it in the air.
    func checkSecrets() {
        guard challengeKind != .tutorial else { return }
        let airborne = !bike.frontContact && !bike.rearContact
        var found=secretsFound
        for s in RideSecrets.forRoute(bike.route) where !found.contains(s.id) && RideSecrets.isCollected(s,bikeX:bike.x,bikeHeight:bike.height,airborne:airborne) {
            found.insert(s.id); secretsFound=found
            awardCoins(15); feedback.play(.secret); audio.play(.chime)
            let line="Secreto \(found.count)/\(RideSecrets.all().count) (+15): "+s.note
            toasts.append(Toast(text:line,age:0)); announce(line)
        }
    }
    /// Stars that are still hidden are drawn as a soft glowing star above the road.
    func drawSecrets(ppm:Double,camY:Double) {
        guard challengeKind != .tutorial,mode == .riding || mode == .crashing else { return }
        let found=secretsFound
        for s in RideSecrets.forRoute(bike.route) where !found.contains(s.id) {
            if s.x<camX-12 || s.x>camX+sceneWidth/ppm+12 { continue }
            let x=art.focusX+(s.x-camX)*ppm,y=art.ground(s.x,at:camX,cameraY:camY,route:bike.route)-1.15*ppm
            let pulse=access.reduceMotion ? 1.0 : 1+0.12*sin(animationTime*3+s.x)
            let r=11*pulse
            art.circle(x,y,r*2.2,NSColor.systemYellow.withAlphaComponent(0.12))
            var pts=[NSPoint]()
            for i in 0..<10 { let a = -Double.pi/2+Double(i)*Double.pi/5, rr = i%2==0 ? r : r*0.45; pts.append(NSPoint(x:x+cos(a)*rr,y:y+sin(a)*rr)) }
            art.path(pts,NSColor.systemYellow,stroke:NSColor.white.withAlphaComponent(0.8),width:1.2)
        }
    }
    /// After a finished run: workshop puzzles solved, leaderboard rank and new diary pages.
    func settleContent(natural:Bool) {
        if natural && bike.finished || natural && challenges.completed {
            for p in RidePuzzle.all where !solvedPuzzles.contains(p.id) && bike.kind == p.vehicle && bike.route == p.route && challengeKind == p.challenge
                && abs(bike.suspensionStiffness-p.stiffness)<0.06 && abs(bike.suspensionDamping-p.damping)<0.06 && challenges.completed {
                var s=solvedPuzzles; s.insert(p.id); solvedPuzzles=s; awardCoins(p.reward); runNotes.append("Reto de taller: \(p.title) (+\(p.reward))")
            }
        }
        if natural && score.total>0 {
            let entry=RideBoardEntry(score:score.total,distance:Int(bike.distance),time:elapsed,vehicle:bike.kind.title,date:Date())
            if let rank=RideLeaderboard.submit(prefs,route:bike.route,entry) { runNotes.append("Marcador de \(BikePhysics.routeNames[bike.route]): puesto \(rank)º") }
        }
        let after=RideJournal.unlocked(totals:stats.totals,secrets:secretsFound.count)
        let seen=Set(prefs.stringArray(forKey:"journal.seen") ?? [])
        let fresh=after.filter { !seen.contains($0.id) }
        if !fresh.isEmpty {
            for e in fresh { runNotes.append("Diario: nueva página «\(e.title)»") }
            prefs.set(Array(seen.union(fresh.map(\.id))),forKey:"journal.seen")
        }
        RideSnapshot.write(game:self)
    }
    /// Set the garage up for a workshop puzzle and ride it.
    func startPuzzle(_ p:RidePuzzle) {
        if mode != .garage { garage() }
        guard progress.isUnlocked(.vehicle(p.vehicle)),progress.isUnlocked(.route(p.route)) else {
            audio.play(.denied); NSSound.beep()
            let missing = progress.isUnlocked(.vehicle(p.vehicle)) ? "la ruta \(BikePhysics.routeNames[p.route])" : "la moto \(p.vehicle.title)"
            let alert=NSAlert(); alert.messageText="Reto bloqueado"; alert.informativeText="Desbloquea \(missing) en el taller para probar «\(p.title)»."
            if let window { alert.beginSheetModal(for:window) { _ in } }
            return
        }
        bike.kind=p.vehicle; bike.route=p.route; challengeKind=p.challenge
        prefs.set(BikeKind.allCases.firstIndex(of:p.vehicle) ?? 0,forKey:"vehicle"); prefs.set(p.route,forKey:"route"); prefs.set(p.challenge.rawValue,forKey:"challenge")
        let key="suspension.\(p.vehicle.rawValue)"
        prefs.set(p.stiffness,forKey:key+".stiffness"); prefs.set(p.damping,forKey:key+".damping")
        loadHandlingPreferences(); loadRecords(); syncState(); start()
    }
}

/// A small JSON file with today's goals and records. Shortcuts, scripts or a future widget can read it.
enum RideSnapshot {
    static var url:URL? { FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask).first?.appendingPathComponent("Wheelie Ride/today.json") }
    static func payload(game:RideView)->[String:Any] {
        [
            "version":1,
            "missions":game.missions.daily.map { ["title":$0.title,"reward":$0.reward] },
            "weekly":["title":game.missions.weekly.title,"reward":game.missions.weekly.reward],
            "runs":game.stats.totals.runs,"distance":Int(game.stats.totals.distance),"bestScore":game.stats.totals.bestScore,
            "secrets":game.secretsFound.count,"puzzles":game.solvedPuzzles.count,
        ]
    }
    static func write(game:RideView) {
        guard let url,!CommandLine.arguments.contains(where:{ $0.hasPrefix("--") }) else { return }
        try? FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
        if let data=try? JSONSerialization.data(withJSONObject:payload(game:game),options:[.prettyPrinted,.sortedKeys]) { try? data.write(to:url,options:.atomic) }
    }
}
