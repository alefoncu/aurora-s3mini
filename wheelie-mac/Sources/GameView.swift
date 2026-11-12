import Cocoa

final class RideView: NSView {
    enum Mode { case garage, riding, paused, crashing, result }
    let bike = BikePhysics(), art = RideRenderer(), audio = EngineAudio()
    let prefs:UserDefaults
    var mode = Mode.garage
    var keys = Set<UInt16>(), touchHeld = Set<RideAction>()
    var timer: Timer?, previous = ProcessInfo.processInfo.systemUptime
    var elapsed = 0.0, animationTime = 0.0, crashTime = 0.0, cameraY = 0.0, riderLean = 0.0
    var riderLift=0.0,riderLiftVelocity=0.0,pedalPhase=0.0
    var ragdoll:RiderRagdoll?, passengerRagdoll:RiderRagdoll?
    var knockedCones=Set<Int>()
    var viewportScale = 1.0, origin = NSPoint.zero
    var sceneHeight=720.0
    var presentationOffset:Double { min(0,sceneHeight-690) }
    var night = false, obstacles = false, sound = true
    var record = 0.0, best = 0.0, bestStoppie = 0.0, bestTime = 0.0
    var challengeKind:RideChallengeKind = .free
    var ghostEnabled=true
    var absOn=false
    var score=RideScore(), bestScore=0.0
    lazy var progress=RideProgress(preferences:prefs)
    var rewarded=false, lastReward=0
    var lastWheelie=0.0, lastStoppie=0.0, lastLandingSerial=0, lastStage=0
    var passedObstacles=Set<Int>()
    var splitDeltas:[Double?]=[], splitText="", splitAge=99.0
    var rivalRun:RideRival?
    var rival:BikePhysics? { rivalRun?.bike }
    var rivalLevel=RivalLevel.normal, rivalSameVehicle=true
    lazy var stats=RideStats(preferences:prefs)
    lazy var missions=RideMissions(preferences:prefs)
    var tutorial=RideTutorial(), tutorialToast="", tutorialToastAge=99.0
    var report=RunReport(), reported=false, runNotes:[String]=[]
    var supermanTime=0.0, lastSupermanTime=0.0, airborneWas=false
    var noHandsHeld:Bool { keys.contains(4) }
    var spinHeld:Bool { keys.contains(5) }
    var supermanHeld:Bool { keys.contains(9) }
    /// Obstacles and puddles are off in the tutorial so each step is about one skill.
    var obstaclesOn:Bool { obstacles && challengeKind != .tutorial }
    var obstacleList:[Int] { bike.endless ? BikePhysics.endlessObstaclePositions : BikePhysics.obstaclePositions }
    lazy var challenges=RideChallengeSession(preferences:prefs)
    struct Dust { var x:Double; var y:Double; var vx:Double; var vy:Double; var life:Double; var maxLife:Double }
    var dust: [Dust] = [], dustClock = 0.0
    var onStateChange: (() -> Void)?
    lazy var bar = TouchBarController(onHold: { [weak self] action, down in
        guard let self else { return }; if down && self.mode == .riding { self.touchHeld.insert(action) } else { self.touchHeld.remove(action) }
    }, onCommand: { [weak self] command in
        switch command { case .pause: self?.pause(); case .restart: self?.start(); case .garage: self?.garage(); case .shiftUp:self?.shift(up:true);case .shiftDown:self?.shift(up:false) }
    })
    var stateOverlay:NSView!, statePanel:NSVisualEffectView!
    var stateTitle:NSTextField!, stateDetail:NSTextField!, continueButton:NSButton!, retryButton:NSButton!
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func makeTouchBar() -> NSTouchBar? { bar.touchBar }
    init(frame:NSRect,preferences:UserDefaults = .standard) {
        prefs=preferences
        super.init(frame:frame)
        bike.kind = BikeKind.allCases[max(0,min(BikeKind.allCases.count-1,prefs.integer(forKey:"vehicle")))]
        bike.route=max(0,min(BikePhysics.routeCount-1,prefs.integer(forKey:"route")))
        night=prefs.bool(forKey:"night"); obstacles=prefs.bool(forKey:"obstacles")
        sound = prefs.object(forKey:"sound") == nil ? true : prefs.bool(forKey:"sound")
        art.helmetOn = prefs.object(forKey:"helmet") == nil ? true : prefs.bool(forKey:"helmet")
        art.passenger=prefs.bool(forKey:"passenger")
        if let c=loadColor("body") { art.body=c }; if let c=loadColor("jacket") { art.jacket=c }; if let c=loadColor("helmetColor") { art.helmet=c }; if let c=loadColor("skin") { art.skin=c }
        challengeKind=RideChallengeKind(rawValue:prefs.string(forKey:"challenge") ?? "free") ?? .free
        ghostEnabled=prefs.object(forKey:"ghost") == nil ? true : prefs.bool(forKey:"ghost")
        absOn=prefs.bool(forKey:"abs")
        rivalLevel=RivalLevel(rawValue:prefs.integer(forKey:"rivalLevel")) ?? .normal
        rivalSameVehicle=prefs.object(forKey:"rivalSame") == nil ? true : prefs.bool(forKey:"rivalSame")
        loadHandlingPreferences()
        audio.enabled=sound; loadRecords(); buildStateOverlay()
        let t=Timer(timeInterval:1/60,repeats:true) { [weak self] _ in self?.tick() }; timer=t; RunLoop.main.add(t,forMode:.common)
        NotificationCenter.default.addObserver(self,selector:#selector(deactivate),name:NSApplication.didResignActiveNotification,object:nil)
        NotificationCenter.default.addObserver(self,selector:#selector(windowResigned(_:)),name:NSWindow.didResignKeyNotification,object:nil)
        setAccessibilityElement(true); setAccessibilityRole(.group); setAccessibilityLabel("Wheelie Ride, taller")
        syncState()
    }
    required init?(coder:NSCoder) { nil }
    func loadColor(_ key:String)->NSColor? {
        guard let v=prefs.array(forKey:key) as? [Double],v.count==3 else { return nil }
        return NSColor(srgbRed:v[0],green:v[1],blue:v[2],alpha:1)
    }
    func saveColor(_ c:NSColor,_ key:String) { guard let c=c.usingColorSpace(.sRGB) else { return }; prefs.set([c.redComponent,c.greenComponent,c.blueComponent],forKey:key); needsDisplay=true }
    func loadHandlingPreferences() {
        bike.transmission.automatic=prefs.object(forKey:"automatic") == nil ? true : prefs.bool(forKey:"automatic")
        let key="suspension.\(bike.kind.rawValue)"
        bike.suspensionStiffness=prefs.object(forKey:key+".stiffness") == nil ? 1 : prefs.double(forKey:key+".stiffness")
        bike.suspensionDamping=prefs.object(forKey:key+".damping") == nil ? 1 : prefs.double(forKey:key+".damping")
        bike.reset()
    }
    var runContext:String {
        "v6.\(bike.kind.rawValue).\(bike.route).\(obstacles ? "cones" : "clear").\(bike.transmission.automatic ? "auto" : "manual").\(Int((bike.suspensionStiffness*100).rounded())).\(Int((bike.suspensionDamping*100).rounded()))\(absOn ? ".abs" : "")\(challengeKind == .endless ? ".endless" : "")"
    }
    var recordKey:String { runContext }
    func ghostSnapshot()->RideGhostFrame {
        RideGhostFrame(time:elapsed,x:bike.x,y:bike.chassisPosition.y,pitch:bike.pitch,
            rearWheelX:bike.rearWheelPosition.x,rearWheelY:bike.rearWheelPosition.y,
            frontWheelX:bike.frontWheelPosition.x,frontWheelY:bike.frontWheelPosition.y,
            wheelRotation:bike.rearWheelRotation,speed:bike.speed)
    }
    func resetRunState() {
        score.reset(); rewarded=false; lastReward=0; lastWheelie=0; lastStoppie=0; lastLandingSerial=bike.landingSerial; lastStage=0
        passedObstacles.removeAll(); splitDeltas.removeAll(); splitText=""; splitAge=99
        report=RunReport(); reported=false; runNotes.removeAll(); supermanTime=0; lastSupermanTime=0; airborneWas=false
        tutorial=RideTutorial(); tutorialToast=""; tutorialToastAge=99
    }
    func startRival() {
        rivalRun=nil
        guard challengeKind == .race else { return }
        var kind=bike.kind
        if !rivalSameVehicle {
            // A different vehicle each run, chosen from a seed that changes with the run count.
            let others=BikeKind.allCases.filter { $0 != bike.kind }
            kind=others[(stats.totals.runs*7+bike.route)%others.count]
        }
        rivalRun=RideRival(level:rivalLevel,kind:kind,route:bike.route,hazards:obstaclesOn,seed:UInt64(stats.totals.runs+1)*2_654_435_761)
    }
    func updateRival(_ dt:Double) { rivalRun?.update(dt) }
    func shift(up:Bool) {
        guard mode == .riding,window?.attachedSheet == nil else { return }
        bike.transmission.shift(up:up,kind:bike.kind);updateTouchBar();needsDisplay=true
    }
    func preserveRun() {
        if mode != .garage { saveRun() }
    }
    func loadRecords() { record=prefs.double(forKey:recordKey+".distance"); best=prefs.double(forKey:recordKey+".wheelie"); bestTime=prefs.double(forKey:recordKey+".time"); bestStoppie=prefs.double(forKey:recordKey+".stoppie"); bestScore=prefs.double(forKey:recordKey+".score") }
    func saveRun() {
        if bike.finished || bike.crashed { challenges.finish(routeCompleted:bike.finished,elapsed:elapsed) }
        record=max(record,bike.distance); best=max(best,bike.bestWheelie); bestStoppie=max(bestStoppie,bike.bestStoppie)
        bestScore=max(bestScore,Double(score.total)); prefs.set(bestScore,forKey:recordKey+".score")
        if !rewarded && (bike.crashed || bike.finished) {
            rewarded=true; lastReward+=RideProgress.reward(distanceCoins:bike.coins,score:score.total); progress.earn(lastReward)
        }
        if !reported && (bike.crashed || bike.finished || bike.distance>50) {
            reported=true
            report.distance=bike.distance; report.score=score.total; report.bestCombo=max(report.bestCombo,score.bestChain)
            report.finished=bike.finished; report.crashed=bike.crashed; report.endless=bike.endless
            report.raceWon=challengeKind == .race && challenges.completed
            for a in stats.record(report) { progress.earn(a.reward); lastReward+=a.reward; runNotes.append("Logro: \(a.title)"+(a.reward>0 ? " (+\(a.reward))" : "")) }
            for m in missions.record(report) { progress.earn(m.reward); lastReward+=m.reward; runNotes.append("Misión: \(m.title) (+\(m.reward))") }
            stats.addCoinsEarned(lastReward)
        }
        prefs.set(bestStoppie,forKey:recordKey+".stoppie"); prefs.set(record,forKey:recordKey+".distance"); prefs.set(best,forKey:recordKey+".wheelie")
        if bike.finished && (bestTime==0 || elapsed<bestTime) { bestTime=elapsed; prefs.set(bestTime,forKey:recordKey+".time") }
    }
    func buildStateOverlay() {
        let dim=RideDimView(frame:bounds); dim.autoresizingMask=[.width,.height]; stateOverlay=dim; addSubview(dim)
        statePanel=NSVisualEffectView(); statePanel.material = .hudWindow; statePanel.blendingMode = .withinWindow; statePanel.state = .active
        statePanel.wantsLayer=true; statePanel.layer?.cornerRadius=18; statePanel.translatesAutoresizingMaskIntoConstraints=false; dim.addSubview(statePanel)
        stateTitle=NSTextField(labelWithString:""); stateTitle.font = .systemFont(ofSize:27,weight:.bold); stateTitle.alignment = .center
        stateDetail=NSTextField(wrappingLabelWithString:""); stateDetail.font = .systemFont(ofSize:13); stateDetail.textColor = .secondaryLabelColor; stateDetail.alignment = .center
        continueButton=NSButton(title:"Continuar",target:self,action:#selector(resumeAction)); continueButton.bezelStyle = .rounded; continueButton.controlSize = .large; continueButton.keyEquivalent="\r"; continueButton.bezelColor = .controlAccentColor
        retryButton=NSButton(title:"Reiniciar ruta",target:self,action:#selector(retryAction)); retryButton.bezelStyle = .rounded; retryButton.controlSize = .large
        let home=NSButton(title:"Volver al taller",target:self,action:#selector(garageAction)); home.bezelStyle = .rounded; home.controlSize = .large
        let stack=NSStackView(views:[stateTitle,stateDetail,continueButton,retryButton,home]); stack.orientation = .vertical; stack.spacing=18; stack.alignment = .centerX; statePanel.addSubview(stack); stack.translatesAutoresizingMaskIntoConstraints=false
        NSLayoutConstraint.activate([statePanel.centerXAnchor.constraint(equalTo:dim.centerXAnchor),statePanel.centerYAnchor.constraint(equalTo:dim.centerYAnchor),statePanel.widthAnchor.constraint(equalToConstant:350),stack.leadingAnchor.constraint(equalTo:statePanel.leadingAnchor,constant:30),stack.trailingAnchor.constraint(equalTo:statePanel.trailingAnchor,constant:-30),stack.topAnchor.constraint(equalTo:statePanel.topAnchor,constant:30),stack.bottomAnchor.constraint(equalTo:statePanel.bottomAnchor,constant:-30),continueButton.widthAnchor.constraint(equalTo:stack.widthAnchor),retryButton.widthAnchor.constraint(equalTo:stack.widthAnchor),home.widthAnchor.constraint(equalTo:stack.widthAnchor),stateDetail.widthAnchor.constraint(equalTo:stack.widthAnchor)])
        dim.isHidden=true
    }
    @objc func resumeAction() { pause(); window?.makeFirstResponder(self) }
    @objc func retryAction() { start() }
    @objc func garageAction() { garage() }
    func updateStateOverlay() {
        stateOverlay.isHidden = mode != .paused && mode != .result
        continueButton.isHidden = mode != .paused
        stateTitle.stringValue = mode == .paused ? "En pausa" : bike.finished ? "Ruta completada" : "Otra vuelta"
        stateDetail.stringValue = mode == .paused ? "Tu ruta sigue aquí." : "\(Int(bike.distance)) m de recorrido\n\(Int(bike.bestWheelie)) m de caballito · \(String(format:"%.1f",bike.bestStoppie)) m de invertido"
        if mode == .result {
            stateDetail.stringValue += "\n\(score.total) puntos (récord \(Int(bestScore))) · +\(lastReward) monedas"
            if score.lostToCrash>0 { stateDetail.stringValue += "\nPerdiste \(score.lostToCrash) puntos de una cadena al caerte" }
            let splits=splitDeltas.enumerated().compactMap { i,d in d.map { String(format:"T%d %+.1f s",i+1,$0) } }
            if !splits.isEmpty { stateDetail.stringValue += "\nTramos vs fantasma: "+splits.joined(separator:" · ") }
            if !runNotes.isEmpty { stateDetail.stringValue += "\n"+runNotes.joined(separator:"\n") }
            if challengeKind == .race { stateDetail.stringValue += challenges.completed ? "\n¡Ganaste a tu rival!" : "\nEl rival ha ganado o te has caído" }
        }
        if mode == .result && challengeKind != .free && challengeKind != .race && challengeKind != .tutorial && challengeKind != .endless { stateDetail.stringValue += "\n"+challenges.progressText }
        retryButton.title = mode == .paused ? "Reiniciar ruta" : "Volver a salir"
        retryButton.keyEquivalent = mode == .result ? "\r" : ""
    }
    func clearInput() { keys.removeAll(); touchHeld.removeAll(); bar.releaseAll() }
    @objc func windowResigned(_ notification:Notification) {
        guard let resigned=notification.object as? NSWindow, resigned === window else { return }
        deactivate()
    }
    var touchBarMode:RideTouchBarMode {
        if window?.attachedSheet != nil { return .blocked }
        switch mode { case .garage:return .garage; case .riding:return .riding; case .paused:return .paused; case .result:return .result; case .crashing:return .blocked }
    }
    func updateTouchBar() { bar.update(mode:touchBarMode,speed:bike.speed,wheelie:bike.wheelieDistance,stoppie:bike.stoppieDistance,gear:bike.transmission.gear,rpm:bike.transmission.rpm,automatic:bike.transmission.automatic) }
    @objc func deactivate() { clearInput(); if mode == .riding { mode = .paused }; audio.update(speed:0,throttle:false,vehicle:0,active:false); syncState() }
    func start() { guard window?.attachedSheet == nil else { return }
        guard progress.isUnlocked(.vehicle(bike.kind)),progress.isUnlocked(.route(bike.route)) else { NSSound.beep(); return }
        NSColorPanel.shared.orderOut(nil); preserveRun(); challenges.abandon(); bike.hazards=obstaclesOn; bike.absEnabled=absOn; bike.endless=challengeKind == .endless; bike.reset(); resetRunState(); startRival(); art.metresToPixels=RideScene.metresToPixels; elapsed=0; crashTime=0; cameraY=0; riderLean=0; riderLift=0; riderLiftVelocity=0; pedalPhase=0; challenges.selected=challengeKind; challenges.start(contextKey:runContext,initialFrame:ghostSnapshot()); ragdoll=nil; passengerRagdoll=nil; knockedCones.removeAll(); dust.removeAll(); clearInput(); mode = .riding; previous=ProcessInfo.processInfo.systemUptime; window?.makeFirstResponder(self); syncState() }
    func garage() { guard window?.attachedSheet == nil else { return }; preserveRun(); challenges.abandon(); clearInput(); mode = .garage; rivalRun=nil; bike.hazards=obstacles; bike.endless=false; bike.absEnabled=absOn; bike.reset(); resetRunState(); art.metresToPixels=RideScene.metresToPixels; cameraY=0; ragdoll=nil; passengerRagdoll=nil; knockedCones.removeAll(); dust.removeAll(); audio.update(speed:0,throttle:false,vehicle:0,active:false); syncState() }
    func pause() {
        guard window?.attachedSheet == nil, mode == .riding || mode == .paused else { return }
        clearInput(); mode = mode == .riding ? .paused : .riding; previous=ProcessInfo.processInfo.systemUptime
        audio.update(speed:bike.speed,throttle:false,vehicle:bike.kind.audioProfile,active:mode == .riding); if mode == .riding { window?.makeFirstResponder(self) }; syncState()
    }
    func syncState() {
        updateTouchBar()
        setAccessibilityLabel(mode == .garage ? "Wheelie Ride, taller. Elige vehículo y ruta." : "Wheelie Ride, \(mode == .paused ? "en pausa" : "partida"). Flechas o WASD para conducir; espacio para saltar; P para pausar; E o freno + peso delante para invertido.")
        updateStateOverlay(); onStateChange?(); needsDisplay=true
    }
    func held(_ action:RideAction)->Bool {
        if (action == .brake || action == .leanForward) && (touchHeld.contains(.stoppie) || keys.contains(14)) { return true }
        let codes:[RideAction:[UInt16]]=[.throttle:[13,126],.brake:[1,125],.leanBack:[0,123],.leanForward:[2,124],.jump:[49],.stunt:[17],.stoppie:[14],.frontBrake:[6],.rearBrake:[7]]
        return touchHeld.contains(action) || (codes[action] ?? []).contains(where:keys.contains)
    }
    override func keyDown(with event:NSEvent) {
        guard !event.modifierFlags.contains(.command),!event.isARepeat else { return }
        switch event.keyCode {
        case 36: if mode == .garage || mode == .result { start() } else if mode == .paused { pause() }
        case 53,35: if mode == .result { garage() } else { pause() }
        case 15: if mode != .garage { start() }
        case 12: shift(up:false)
        case 3: shift(up:true)
        default: if mode == .riding { keys.insert(event.keyCode) }
        }
    }
    override func keyUp(with event:NSEvent) { keys.remove(event.keyCode) }
    func tick() {
        let now=ProcessInfo.processInfo.systemUptime,dt=min(0.05,max(0,now-previous)); previous=now
        if mode == .riding || mode == .crashing { animationTime += dt }
        if mode == .riding {
            let previousFront=bike.frontWheelPosition,previousRear=bike.rearWheelPosition,previousSpeed=bike.speed,previousVertical=bike.verticalVelocity
            bike.update(dt,throttle:held(.throttle),brake:held(.brake),leanBack:held(.leanBack),leanForward:held(.leanForward),jump:held(.jump),frontBrake:held(.frontBrake),rearBrake:held(.rearBrake),trick:held(.stunt),spin:spinHeld,noHands:noHandsHeld)
            elapsed += dt
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
            if airNow && supermanHeld && !bike.crashed { riderLean = -1 }
            let targetLift=(airNow && supermanHeld ? 0.9 : 0)+(bike.kind == .trials ? 0.4 : bike.kind == .motocross ? 0.18 : bike.kind == .bmx ? 0.14 : 0.04)+(held(.jump) ? 0.22 : 0)
            riderLiftVelocity += ((targetLift-riderLift)*55-riderLiftVelocity*12-max(-20,min(20,acceleration))*0.10)*dt
            riderLift=max(0,min(1,riderLift+riderLiftVelocity*dt))
            if bike.kind == .bmx { pedalPhase=bike.pedalPhase }
            if obstaclesOn && !bike.finished && !bike.crashed {
                for world in obstacleList where !knockedCones.contains(world) {
                    if abs(Double(world)-bike.x)>4 { continue }
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
            if bike.crashed {
                let pose=RiderRig.solve(vehicle:bike.kind.rig,lean:riderLean,lift:riderLift,pedalPhase:pedalPhase,cycling:bike.kind == .bmx)
                let velocity=RideVector(previousSpeed,bike.verticalVelocity)
                ragdoll=RiderRagdoll(pose:pose,origin:bike.chassisPosition,pitch:bike.pitch,velocity:velocity,angularVelocity:bike.angularVelocity,route:bike.route)
                if art.passenger && bike.kind.supportsPassenger {
                    let companion=RiderRig.solve(vehicle:bike.kind.rig,lean:riderLean*0.3,lift:riderLift,passenger:true)
                    passengerRagdoll=RiderRagdoll(pose:companion,origin:bike.chassisPosition,pitch:bike.pitch,velocity:velocity,angularVelocity:bike.angularVelocity,route:bike.route)
                }
                score.crash(); mode = .crashing; crashTime=0; clearInput(); audio.impact(); emitDust(count:16); saveRun(); syncState()
            } else if bike.finished { score.finishRun(); challenges.raceWon = rival.map { !$0.finished } ?? false; mode = .result; clearInput(); saveRun(); syncState() }
        } else if mode == .crashing {
            bike.update(dt,throttle:false,brake:false,leanBack:false,leanForward:false)
            ragdoll?.update(dt); passengerRagdoll?.update(dt)
            updateCamera(dt)
            crashTime += dt
            if crashTime>1.8 { mode = .result; syncState() }
        }
        if mode == .riding || mode == .crashing {
            for i in dust.indices { dust[i].x += dust[i].vx*dt; dust[i].y += dust[i].vy*dt; dust[i].vy -= 2*dt; dust[i].life -= dt }
            dust.removeAll { $0.life<=0 }
        }
        audio.setAmbient(route:bike.route,speed:bike.speed)
        audio.update(speed:bike.speed,throttle:held(.throttle),vehicle:bike.kind.audioProfile,active:mode == .riding,rpm:bike.transmission.rpm,load:bike.throttlePosition,shifting:bike.transmission.shiftRemaining>0,slip:max(abs(bike.frontSlip),abs(bike.rearSlip)),timbre:BikeKind.allCases.firstIndex(of:bike.kind))
        updateTouchBar()
        if mode == .riding || mode == .crashing { needsDisplay=true }
    }
    func updateScoring(_ dt:Double) {
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
                tutorialToast=tutorial.finished ? "¡Tutorial completado!" : "Paso \(tutorial.stepNumber-1) conseguido"; tutorialToastAge=0
                if tutorial.finished && !stats.totals.tutorialDone { progress.earn(40); lastReward+=40; runNotes.append("Tutorial completado (+40)"); for a in stats.markTutorialDone() where a.reward>0 { progress.earn(a.reward) } }
            }
        }
        let stage=BikePhysics.difficultyStage(at:bike.x)
        if stage>lastStage {
            lastStage=stage
            let delta=challenges.timeDelta(elapsed:elapsed,atDistance:Double(stage*300))
            splitDeltas.append(delta)
            splitText=delta.map { String(format:"Tramo %d · %+.1f s vs fantasma",stage,$0) } ?? "Tramo \(stage) completado"
            splitAge=0
        }
        splitAge+=dt
    }
    func updateCamera(_ dt:Double) {
        // Keep roughly 0.65 s of road ahead at high speed for every vehicle.
        let zoom=min(1,max(0.15,13/max(13,bike.speed)))
        art.metresToPixels += (RideScene.metresToPixels*zoom-art.metresToPixels)*(1-exp(-dt*2.5))
        let target=(BikePhysics.ground(bike.x,route:bike.route)+max(0,bike.height-0.35)*0.35)*art.metresToPixels
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
    override func mouseDown(with event:NSEvent) { window?.makeFirstResponder(self) }
    override func draw(_ dirtyRect:NSRect) {
        if mode == .garage { drawGarage(); return }
        NSColor(hex:bike.route==0 ? 0x7A725E : 0x8F694B).setFill(); bounds.fill()
        viewportScale=bounds.width/1280; origin = .zero; sceneHeight=bounds.height/viewportScale
        NSGraphicsContext.saveGraphicsState(); let transform=NSAffineTransform(); transform.translateX(by:origin.x,yBy:origin.y); transform.scale(by:viewportScale); transform.concat()
        NSBezierPath(rect:NSRect(x:0,y:0,width:1280,height:sceneHeight)).addClip()
        let isGarage=mode == .garage
        art.background(camera:isGarage ? 220 : bike.x*RideScene.metresToPixels,route:bike.route,night:night,time:animationTime)
        art.scenery(cameraX:isGarage ? 0 : bike.x,cameraY:isGarage ? 0 : cameraY+presentationOffset,route:bike.route,night:night,endless:bike.endless && !isGarage)
        if isGarage { drawGarage() } else { drawRide() }
        NSGraphicsContext.restoreGraphicsState()
    }
    func drawGarage() {
        NSColor.windowBackgroundColor.setFill(); bounds.fill()
        art.gradient(bounds,NSColor.controlBackgroundColor.withAlphaComponent(0.6),NSColor.windowBackgroundColor)
        let w=bounds.width,h=bounds.height,geo=art.geometry(bike.kind)
        art.text(bike.kind.title,32,28,29,.labelColor,.bold)
        art.text(bike.kind.garageDetail,33,67,12,.secondaryLabelColor,.medium)
        art.text(bike.kind == .bmx ? "Cuadro rígido · pedales y neumáticos" : "Recorrido de suspensión  \(Int(bike.kind.rig.frontTravel*1000)) / \(Int(bike.kind.rig.rearTravel*1000)) mm",33,88,11,.tertiaryLabelColor)
        art.text(bike.kind == .bmx ? "Pedaleo en llano  ·  ~35 km/h" : "Velocidad en recta  \(Int((bike.kind.topSpeed*3.6).rounded())) km/h",33,106,11,.secondaryLabelColor)
        let floor=h*0.72, z=max(0.8,min(3.0,min((w-88)/(geo.front+65),(floor-120)/175)))
        art.ellipse(w*0.15,floor-8,w*0.7,25,NSColor.separatorColor.withAlphaComponent(0.09))
        art.shadow(x:w/2,y:floor+1,width:geo.front*z+80,height:18,alpha:0.14)
        let rig=bike.kind.rig,ppm=z*rig.drawingUnitsPerMetre,c=cos(bike.pitch),s=sin(bike.pitch)
        func local(_ wheel:RideVector)->RideVector { let d=wheel-bike.chassisPosition;return RideVector(c*d.x+s*d.y,-s*d.x+c*d.y) }
        let midpoint=(bike.rearWheelPosition.x+bike.frontWheelPosition.x)*0.5
        art.motorcycle(x:w/2+(bike.chassisPosition.x-midpoint)*ppm,y:floor-bike.chassisPosition.y*ppm,scale:z,angle:bike.pitch,kind:bike.kind,rotation:0,time:0,rearWheelLocal:local(bike.rearWheelPosition),frontWheelLocal:local(bike.frontWheelPosition),frontCompression:bike.frontCompression,rearCompression:bike.rearCompression)
        art.text("MEJOR CABALLITO",32,h-100,10,.secondaryLabelColor,.semibold)
        art.text("\(Int(best)) m",32,h-80,25,.labelColor,.medium,mono:true)
        art.text("RÉCORD DE RUTA",w-182,h-100,10,.secondaryLabelColor,.semibold)
        art.text("\(Int(record)) m",w-182,h-80,25,.labelColor,.medium,mono:true)
    }
    func drawRide() {
        let ppm=art.metresToPixels,rig=bike.kind.rig,camY=cameraY+presentationOffset
        if obstaclesOn {
            for p in BikePhysics.puddlePositions { art.puddle(center:Double(p),halfLength:BikePhysics.puddleHalfLength,cameraX:bike.x,cameraY:camY,route:bike.route) }
            for m in obstacleList {
                let knocked=knockedCones.contains(m)
                switch BikePhysics.obstacleKind(at:m) {
                case .cone: art.cone(Double(m),cameraX:bike.x,cameraY:camY,route:bike.route,knocked:knocked)
                case .barrel: art.barrel(Double(m),cameraX:bike.x,cameraY:camY,route:bike.route,knocked:knocked)
                case .log: art.log(Double(m),cameraX:bike.x,cameraY:camY,route:bike.route,knocked:knocked)
                }
            }
        }
        for p in dust {
            let x=370+(p.x-bike.x)*ppm,y=art.ground(p.x,at:bike.x,cameraY:camY,route:bike.route)-p.y*ppm
            let size=2+(1-p.life/p.maxLife)*10
            art.ellipse(x-size,y-size,size*2,size,NSColor(hex:bike.route==0 ? 0xCFD0C7 : bike.route==3 ? 0xFFFFFF : bike.route==4 ? 0xB8C0C8 : 0xD6BD91,alpha:(p.life/p.maxLife)*0.17))
        }
        if let r=rival {
            let c=cos(r.pitch),s=sin(r.pitch),rrig=r.kind.rig
            func localRival(_ point:RideVector)->RideVector { let d=point-r.chassisPosition; return RideVector(c*d.x+s*d.y,-s*d.x+c*d.y) }
            let savedBody=art.body,savedJacket=art.jacket
            art.body=NSColor.systemTeal; art.jacket=NSColor.systemRed
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current?.cgContext.setAlpha(0.8)
            art.motorcycle(x:370+(r.chassisPosition.x-bike.x)*ppm,y:458+camY-r.chassisPosition.y*ppm,scale:ppm/rrig.drawingUnitsPerMetre,angle:r.pitch,kind:r.kind,rotation:-r.rearWheelRotation,time:animationTime,showRider:!r.crashed,rearWheelLocal:localRival(r.rearWheelPosition),frontWheelLocal:localRival(r.frontWheelPosition),frontCompression:r.frontCompression,rearCompression:r.rearCompression,frontRotation:-r.frontWheelRotation,pedalPhase:r.pedalPhase)
            NSGraphicsContext.restoreGraphicsState()
            art.body=savedBody; art.jacket=savedJacket
        }
        if ghostEnabled,let ghost=challenges.ghostFrame(at:elapsed) {
            let c=cos(ghost.pitch),s=sin(ghost.pitch)
            func localGhost(_ x:Double,_ y:Double)->RideVector {
                let dx=x-ghost.x,dy=y-ghost.y
                return RideVector(c*dx+s*dy,-s*dx+c*dy)
            }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current?.cgContext.setAlpha(0.28)
            art.motorcycle(x:370+(ghost.x-bike.x)*ppm,y:458+camY-ghost.y*ppm,
                scale:ppm/rig.drawingUnitsPerMetre,angle:ghost.pitch,kind:bike.kind,
                rotation:-ghost.wheelRotation,time:elapsed,showRider:true,
                rearWheelLocal:localGhost(ghost.rearWheelX,ghost.rearWheelY),
                frontWheelLocal:localGhost(ghost.frontWheelX,ghost.frontWheelY))
            NSGraphicsContext.restoreGraphicsState()
        }
        let ground=art.ground(bike.x,at:bike.x,cameraY:camY,route:bike.route)
        art.shadow(x:370+rig.wheelbase*ppm*0.4,y:ground+4,width:rig.wheelbase*ppm+50,height:10,alpha:max(0.05,0.24-bike.height*0.045))
        let c=cos(bike.pitch),s=sin(bike.pitch)
        func local(_ point:RideVector)->RideVector { let d=point-bike.chassisPosition; return RideVector(c*d.x+s*d.y,-s*d.x+c*d.y) }
        let bodyX=370+(bike.chassisPosition.x-bike.x)*ppm,bodyY=458+camY-bike.chassisPosition.y*ppm
        if night { art.headlight(x:bodyX,y:bodyY,angle:bike.pitch,wheelbasePixels:rig.wheelbase*ppm) }
        // A 360 is shown as the bike turning about its vertical axis (a horizontal squash).
        let yawScale=bike.spinYaw == 0 ? 1.0 : (abs(cos(bike.spinYaw))<0.18 ? 0.18*(cos(bike.spinYaw)<0 ? -1 : 1) : cos(bike.spinYaw))
        NSGraphicsContext.saveGraphicsState()
        if yawScale != 1 { let yaw=NSAffineTransform(); yaw.translateX(by:bodyX,yBy:0); yaw.scaleX(by:yawScale,yBy:1); yaw.translateX(by:-bodyX,yBy:0); yaw.concat() }
        art.motorcycle(x:bodyX,y:bodyY,scale:ppm/rig.drawingUnitsPerMetre,angle:bike.pitch,kind:bike.kind,rotation:-bike.rearWheelRotation,time:animationTime,lean:riderLean,stunt:held(.stunt),showRider:ragdoll == nil,rearWheelLocal:local(bike.rearWheelPosition),frontWheelLocal:local(bike.frontWheelPosition),frontCompression:bike.frontCompression,rearCompression:bike.rearCompression,frontRotation:-bike.frontWheelRotation,pedalPhase:pedalPhase,riderLift:riderLift)
        NSGraphicsContext.restoreGraphicsState()
        if ragdoll != nil {
            NSGraphicsContext.saveGraphicsState(); let t=NSAffineTransform(); t.translateX(by:370-bike.x*ppm,yBy:458+camY); t.concat()
            if let companion=passengerRagdoll { art.drawRider(companion.pose,units:ppm,kind:bike.kind,passenger:true,detached:true) }
            if let ragdoll { art.drawRider(ragdoll.pose,units:ppm,kind:bike.kind,detached:true) }
            NSGraphicsContext.restoreGraphicsState()
        }
        art.weather(route:bike.route,time:animationTime)
        art.gradient(NSRect(x:0,y:0,width:1280,height:165),NSColor.black.withAlphaComponent(0.32),.clear)
        art.gradient(NSRect(x:0,y:sceneHeight-130,width:1280,height:130),.clear,NSColor.black.withAlphaComponent(0.50))
        hud(); drawControls()
    }
    func hud() {
        art.text("\(Int(bike.distance)) m",28,24,23,.white,.semibold,mono:true)
        art.text(bike.endless ? "Vuelta \(Int(bike.x/1200)+1) · infinito" : "de 1.200 m",29,54,11,NSColor.white.withAlphaComponent(0.72))
        art.box(29,75,145,2,NSColor.white.withAlphaComponent(0.22),1)
        art.box(29,75,145*(bike.endless ? bike.x.truncatingRemainder(dividingBy:1200) : bike.x)/1200,2,.white,1)
        art.text(String(format:"%02d:%04.1f",Int(elapsed)/60,elapsed.truncatingRemainder(dividingBy:60)),1188,28,18,.white,.medium,center:true,mono:true)
        if bike.rearContact && !bike.frontContact && bike.wheelieDistance>0.2 {
            art.text("Caballito",640,27,11,NSColor.white.withAlphaComponent(0.75),.medium,center:true)
            art.text("\(Int(bike.wheelieDistance)) m",640,45,25,.white,.semibold,center:true,mono:true)
            art.box(584,83,112,2,NSColor.white.withAlphaComponent(0.25),1)
            art.box(584,83,112*min(1,bike.angle/1.72),2,bike.angle>1.4 ? .systemOrange : .white,1)
        }
        if bike.isStoppie && bike.stoppieDistance>0.2 {
            art.text("Invertido",640,27,11,NSColor.white.withAlphaComponent(0.75),.medium,center:true)
            art.text(String(format:"%.1f m",bike.stoppieDistance),640,45,25,.white,.semibold,center:true,mono:true)
            art.box(584,83,112,2,NSColor.white.withAlphaComponent(0.25),1)
            art.box(584,83,112*min(1,-bike.angle/1.1),2,bike.angle < -0.85 ? .systemOrange : .white,1)
        }
        if challengeKind != .free && challengeKind != .tutorial { art.text(challenges.progressText,28,117,12,.white,.medium) }
        if ghostEnabled,let ghost=challenges.ghostFrame(at:elapsed) {
            if let delta=challenges.timeDelta(elapsed:elapsed,atDistance:bike.x) {
                art.text(String(format:"Fantasma %+.1f s",delta),1185,62,11,delta<=0 ? NSColor.systemGreen : NSColor.systemOrange,.semibold,center:true,mono:true)
            } else { art.text(String(format:"Fantasma %+.0f m",ghost.x-bike.x),1185,62,11,NSColor.white.withAlphaComponent(0.8),center:true,mono:true) }
        }
        if let r=rival {
            let gap=bike.x-r.x
            art.text(r.crashed ? "\(rivalLevel.title) caído" : r.finished ? "Rival ha llegado" : String(format:"Rival %+.0f m",gap),1185,80,11,r.crashed || gap>=0 ? NSColor.systemGreen : NSColor.systemOrange,.semibold,center:true,mono:true)
        }
        art.box(1112,94,152,(score.pending>0 || !score.popups.isEmpty) ? 128 : 52,NSColor.black.withAlphaComponent(0.22),8)
        art.text("PUNTOS",1188,100,10,NSColor.white.withAlphaComponent(0.7),.semibold,center:true)
        art.text("\(score.total)",1188,114,23,.white,.semibold,center:true,mono:true)
        if score.chainActive || score.pending>0 {
            art.text(String(format:"x%.1f · cadena %d",score.multiplier,score.chainPoints),1188,144,11,.systemYellow,.semibold,center:true,mono:true)
            art.box(1130,162,116,2,NSColor.white.withAlphaComponent(0.25),1)
            art.box(1130,162,116*max(0,min(1,score.chainTimer/RideScore.chainWindow)),2,.systemYellow,1)
        }
        for (i,popup) in score.popups.enumerated() {
            art.text("+\(popup.points) \(popup.text)",1188,174+Double(i)*17,11,NSColor.white.withAlphaComponent(max(0.2,1-popup.age/2.2)),.medium,center:true)
        }
        if splitAge<4 { art.text(splitText,640,150,13,.white,.semibold,center:true) }
        if challengeKind == .tutorial {
            art.box(340,128,600,tutorial.finished ? 56 : 72,NSColor.black.withAlphaComponent(0.42),10)
            art.text(tutorial.finished ? tutorial.title : "Tutorial \(tutorial.stepNumber)/\(RideTutorial.stepCount) · \(tutorial.title)",640,136,14,.systemYellow,.semibold,center:true)
            art.text(tutorial.instruction,640,158,12,.white,.medium,center:true)
            if !tutorial.finished { art.box(360,184,560,3,NSColor.white.withAlphaComponent(0.25),1); art.box(360,184,560*tutorial.progress,3,.systemYellow,1) }
        }
        if tutorialToastAge<2.5 { art.text(tutorialToast,640,206,16,.systemGreen,.bold,center:true) }
        if bike.tyreWear>0.08 || bike.suspensionHeat>0.3 {
            art.text(String(format:"Neumáticos %d %%",Int((1-bike.tyreWear*0.3)*100)),28,sceneHeight-58,11,bike.tyreWear>0.6 ? .systemOrange : NSColor.white.withAlphaComponent(0.8),.medium,mono:true)
            art.text(String(format:"Amortiguadores %d %%",Int((1-bike.suspensionHeat*0.35)*100)),28,sceneHeight-40,11,bike.suspensionHeat>0.6 ? .systemOrange : NSColor.white.withAlphaComponent(0.8),.medium,mono:true)
        }
        let stage=BikePhysics.difficultyStage(at:bike.x)
        art.text("TRAMO \(stage+1)/4 · \(BikePhysics.stageTitle(at:bike.x))",28,90,11,.white,.semibold)
        for marker in 1...3 { art.box(29+145*Double(marker)/4,72,1,8,NSColor.white.withAlphaComponent(0.6)) }
        let toNext=Double((stage+1)*300)-bike.x
        if stage<3 && toNext<65 {
            art.text("Próximo tramo: \(BikePhysics.stageTitle(at:Double((stage+1)*300))) · \(max(0,Int(toNext))) m",640,101,12,.white,.medium,center:true)
        } else if stage>0 && bike.x-Double(stage*300)<35 {
            art.text(stage == 3 ? "Anticipa los cambios de pendiente y dosifica el gas" : "Terreno más irregular · controla los aterrizajes",640,101,12,.white,.medium,center:true)
        }
        if obstaclesOn, let next=obstacleList.first(where:{Double($0)>bike.x && !knockedCones.contains($0)}), Double(next)-bike.x<max(10,bike.speed*0.7) {
            let name=BikePhysics.obstacleKind(at:next) == .cone ? "Cono" : BikePhysics.obstacleKind(at:next) == .barrel ? "Barril" : "Tronco"
            art.text("\(name) a \(max(1,Int(Double(next)-bike.x))) m",640,124,12,.white,.medium,center:true)
        }
    }
    func drawControls() {
        art.text("\(Int(bike.speed*3.6))",640,sceneHeight-76,32,.white,.medium,center:true,mono:true)
        art.text("km/h",640,sceneHeight-37,10,NSColor.white.withAlphaComponent(0.6),center:true)
        if bike.kind != .bmx {
            let gear=bike.transmission.gear == 0 ? "CVT" : "\(bike.transmission.automatic ? "A" : "M")\(bike.transmission.gear)"
            art.text("\(gear) · \(Int(bike.transmission.rpm)) rpm",640,sceneHeight-18,11,.white,.medium,center:true,mono:true)
        }
        if max(abs(bike.frontSlip),abs(bike.rearSlip))>0.25 && (bike.frontContact || bike.rearContact) {
            let message=bike.rearSlip>0.25 ? "Pérdida de tracción" : "Rueda deslizando"
            art.text(message,640,sceneHeight-98,11,.systemOrange,.semibold,center:true)
        }
        if elapsed<7 {
            art.text("H sin manos   G giro 360° (en el aire)   V superman (en el aire)   T + ←/→ voltereta",640,sceneHeight-134,12,NSColor.white.withAlphaComponent(0.7),.medium,center:true)
            art.text("↑ acelerar   ← levantar   → peso delante   ↓ frenos   Z delante   X detrás   Q/F marchas   E invertido   Espacio saltar",640,sceneHeight-116,12,NSColor.white.withAlphaComponent(0.78),.medium,center:true)
        }
    }
}

private final class RideDimView:NSView {
    override var isFlipped:Bool { true }
    override func draw(_ dirtyRect:NSRect) { NSColor.black.withAlphaComponent(0.28).setFill(); bounds.fill() }
}
