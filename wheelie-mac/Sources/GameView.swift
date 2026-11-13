import Cocoa

final class RideView: NSView {
    enum Mode { case garage, riding, paused, crashing, result }
    let bike = BikePhysics(), art = RideRenderer(), audio = EngineAudio()
    let prefs:UserDefaults
    var mode = Mode.garage { didSet { if mode != oldValue { updateLayerVisibility() } } }
    // Layers, back to front: backdrop (GPU) / world (CPU) / screen-edge shading (GPU) / HUD (CPU).
    lazy var backdrop = RideBackdrop(art:art)
    let overlay = RideOverlay()
    var backdropHost:RideLayerHost!, sceneView:RideDrawView!, overlayHost:RideLayerHost!, hudView:RideDrawView!
    /// Any redraw request also refreshes the layered scene, so existing `needsDisplay = true` calls keep working.
    override var needsDisplay:Bool {
        get { super.needsDisplay }
        set { super.needsDisplay=newValue; if newValue { invalidateLayers() } }   // use the assigned value: the getter reads false for a window that is not on screen
    }
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
    /// Dynamic weather: fog banks, storms and blizzards along the route (its own records when on).
    var weatherOn=true
    var weather=WeatherState(), lastWeatherTime=0.0
    var weatherSeed:UInt64 { UInt64(stats.totals.runs+1)*0x9E3779B1 }
    /// The styles currently selected, each of which must be owned before riding.
    var cosmeticItems:[RideUnlock] { [.helmet(art.helmetStyle),.jacket(art.jacketStyle),.livery(art.livery)] }
    var difficulty=BikePhysics.Assist.normal
    var score=RideScore(), bestScore=0.0
    lazy var progress=RideProgress(preferences:prefs)
    var rewarded=false, lastReward=0
    var lastWheelie=0.0, lastStoppie=0.0, lastLandingSerial=0, lastStage=0
    var passedObstacles=Set<Int>()
    var splitDeltas:[Double?]=[], splitText="", splitAge=99.0
    /// Rivals in the current race: one in a duel, three on the circuit.
    var rivalRuns:[RideRival]=[]
    var rivalRun:RideRival? { rivalRuns.first }
    var rival:BikePhysics? { rivalRun?.bike }
    var rivalFinishTimes:[Double?]=[], playerFinishTime:Double?
    var overtakeTracker=RideRace.OvertakeTracker()
    var racePosition=1
    static let rivalPalette:[NSColor]=[.systemTeal,.systemOrange,.systemPurple]
    /// Standings entries for the player and every rival, for positions and prizes.
    var playerEntry:RaceEntry { RaceEntry(distance:bike.distance,finishTime:playerFinishTime,crashed:bike.crashed) }
    var rivalEntries:[RaceEntry] { rivalRuns.enumerated().map { i,r in RaceEntry(distance:r.bike.distance,finishTime:i<rivalFinishTimes.count ? rivalFinishTimes[i] : nil,crashed:r.crashed) } }
    var rivalLevel=RivalLevel.normal, rivalSameVehicle=true
    lazy var stats=RideStats(preferences:prefs)
    lazy var missions=RideMissions(preferences:prefs)
    var tutorial=RideTutorial(), tutorialToast="", tutorialToastAge=99.0
    var report=RunReport(), reported=false, runNotes:[String]=[]
    var riderHandsOff=0.0, riderSuperman=0.0
    struct Toast { let text:String; var age:Double }
    var toasts:[Toast]=[], toastedIDs=Set<String>(), toastClock=0.0
    var lastBanked=0, lastMultiplier=1.0
    var supermanTime=0.0, lastSupermanTime=0.0, airborneWas=false
    var noHandsHeld:Bool { held(.noHands) }
    var spinHeld:Bool { held(.spin) }
    var supermanHeld:Bool { held(.superman) }
    /// Obstacles and puddles are off in the tutorial so each step is about one skill.
    var obstaclesOn:Bool { obstacles && challengeKind != .tutorial }
    lazy var circuitList=BikePhysics.circuitObstaclePositions(laps:3)
    var lapTimes:[Double]=[], lapStart=0.0
    var obstacleList:[Int] { bike.endless ? BikePhysics.endlessObstaclePositions : BikePhysics.circuit ? circuitList : BikePhysics.obstaclePositions }
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
        art.helmetStyle=HelmetStyle(rawValue:prefs.integer(forKey:"helmetStyle")) ?? .standard
        art.jacketStyle=JacketStyle(rawValue:prefs.integer(forKey:"jacketStyle")) ?? .standard
        art.livery=Livery(rawValue:prefs.integer(forKey:"livery")) ?? .none
        ghostEnabled=prefs.object(forKey:"ghost") == nil ? true : prefs.bool(forKey:"ghost")
        absOn=prefs.bool(forKey:"abs")
        weatherOn=prefs.object(forKey:"weather") == nil ? true : prefs.bool(forKey:"weather")
        difficulty=BikePhysics.Assist(rawValue:prefs.object(forKey:"difficulty") == nil ? 1 : prefs.integer(forKey:"difficulty")) ?? .normal
        rivalLevel=RivalLevel(rawValue:prefs.integer(forKey:"rivalLevel")) ?? .normal
        rivalSameVehicle=prefs.object(forKey:"rivalSame") == nil ? true : prefs.bool(forKey:"rivalSame")
        loadHandlingPreferences()
        audio.enabled=sound; loadRecords(); buildLayers(); buildStateOverlay()
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
        "v6.\(bike.kind.rawValue).\(bike.route).\(obstacles ? "cones" : "clear").\(bike.transmission.automatic ? "auto" : "manual").\(Int((bike.suspensionStiffness*100).rounded())).\(Int((bike.suspensionDamping*100).rounded()))\(absOn ? ".abs" : "")\(weatherOn ? ".clima" : "")\(difficulty == .normal ? "" : ".\(difficulty.title.lowercased())")\(challengeKind == .endless ? ".endless" : "")\(challengeKind == .circuit ? ".circuit\(bike.laps)" : "")"
    }
    var recordKey:String { runContext }
    func ghostSnapshot()->RideGhostFrame {
        RideGhostFrame(time:elapsed,x:bike.x,y:bike.chassisPosition.y,pitch:bike.pitch,
            rearWheelX:bike.rearWheelPosition.x,rearWheelY:bike.rearWheelPosition.y,
            frontWheelX:bike.frontWheelPosition.x,frontWheelY:bike.frontWheelPosition.y,
            wheelRotation:bike.rearWheelRotation,speed:bike.speed)
    }
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
            rewarded=true; lastReward+=RideProgress.reward(distanceCoins:bike.coins,score:score.total,multiplier:difficulty.coinMultiplier); progress.earn(lastReward)
        }
        if !reported && (bike.crashed || bike.finished || bike.distance>50) {
            reported=true
            report.distance=bike.distance; report.score=score.total; report.bestCombo=max(report.bestCombo,score.bestChain)
            report.finished=bike.finished; report.crashed=bike.crashed; report.endless=bike.endless
            report.raceWon=challengeKind == .race && challenges.completed
            for a in stats.record(report) { progress.earn(a.reward); lastReward+=a.reward; runNotes.append("Logro: \(a.title)"+(a.reward>0 ? " (+\(a.reward))" : "")) }
            for m in missions.record(report) { progress.earn(m.reward); lastReward+=m.reward; runNotes.append("Misión: \(m.title) (+\(m.reward))") }
            if !rivalRuns.isEmpty {
                let prize=bike.finished ? RideRace.prize(position:racePosition,fieldSize:rivalRuns.count+1) : 0
                if prize>0 { progress.earn(prize); lastReward+=prize; runNotes.append("Premio de posición \(racePosition)º (+\(prize))") }
            }
            stats.addCoinsEarned(lastReward)
        }
        prefs.set(bestStoppie,forKey:recordKey+".stoppie"); prefs.set(record,forKey:recordKey+".distance"); prefs.set(best,forKey:recordKey+".wheelie")
        if bike.finished && (bestTime==0 || elapsed<bestTime) { bestTime=elapsed; prefs.set(bestTime,forKey:recordKey+".time") }
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
        guard cosmeticItems.allSatisfy({ progress.isUnlocked($0) }),progress.isUnlocked(.vehicle(bike.kind)),progress.isUnlocked(.route(bike.route)) else { audio.play(.denied); NSSound.beep(); return }
        NSColorPanel.shared.orderOut(nil); preserveRun(); challenges.abandon(); bike.hazards=obstaclesOn; bike.absEnabled=absOn; bike.assist=difficulty; bike.endless=challengeKind == .endless; BikePhysics.circuit=challengeKind == .circuit; bike.laps=3; bike.reset(); resetRunState(); startRival(); art.metresToPixels=RideScene.metresToPixels; elapsed=0; crashTime=0; cameraY=0; riderLean=0; riderLift=0; riderLiftVelocity=0; pedalPhase=0; challenges.selected=challengeKind; challenges.start(contextKey:runContext,initialFrame:ghostSnapshot()); ragdoll=nil; passengerRagdoll=nil; knockedCones.removeAll(); dust.removeAll(); clearInput(); mode = .riding; previous=ProcessInfo.processInfo.systemUptime; window?.makeFirstResponder(self); syncState() }
    func garage() { guard window?.attachedSheet == nil else { return }; preserveRun(); challenges.abandon(); clearInput(); mode = .garage; rivalRuns=[]; BikePhysics.circuit=false; bike.hazards=obstacles; bike.endless=false; bike.absEnabled=absOn; bike.assist=difficulty; bike.reset(); resetRunState(); art.metresToPixels=RideScene.metresToPixels; cameraY=0; ragdoll=nil; passengerRagdoll=nil; knockedCones.removeAll(); dust.removeAll(); audio.update(speed:0,throttle:false,vehicle:0,active:false); syncState() }
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
        let codes:[RideAction:[UInt16]]=[.throttle:[13,126],.brake:[1,125],.leanBack:[0,123],.leanForward:[2,124],.jump:[49],.stunt:[17],.stoppie:[14],.frontBrake:[6],.rearBrake:[7],.noHands:[4],.spin:[5],.superman:[9]]
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
    override func mouseDown(with event:NSEvent) { window?.makeFirstResponder(self) }
}
