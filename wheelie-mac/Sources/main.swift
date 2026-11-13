import Cocoa

/// Keep the game context attached when a native pause button becomes responder.
final class RideWindow:NSWindow {
    var touchBarFocusChanged:(()->Void)?
    @discardableResult override func makeFirstResponder(_ responder:NSResponder?)->Bool {
        let accepted=super.makeFirstResponder(responder)
        if accepted { touchBarFocusChanged?() }
        return accepted
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSToolbarDelegate, NSToolbarItemValidation, NSMenuItemValidation, NSWindowDelegate {
    var window:RideWindow!, game:RideView!
    var touchBarWindowController:NSWindowController!
    private var bindingTouchBar=false
    var pauseItem:NSToolbarItem?, nightItem:NSToolbarItem?, audioItem:NSToolbarItem?
    var split:NSSplitViewController!, sidebar:GarageSidebarController!, inspector:GarageInspectorController!
    var sidebarItem:NSSplitViewItem!, inspectorItem:NSSplitViewItem!
    var lastGarage:Bool?, lastNarrow:Bool?
    /// Below this window width the vehicle list is hidden; the inspector's vehicle popup replaces it.
    static let narrowWindow:CGFloat = 1060
    func windowDidResize(_ notification:Notification) { adaptGarageLayout() }
    func adaptGarageLayout() {
        guard let window, game != nil else { return }
        let narrow=window.frame.width<Self.narrowWindow
        guard narrow != lastNarrow else { return }
        lastNarrow=narrow
        if game.mode == .garage { sidebarItem.isCollapsed=narrow }
    }
    var settings:NSPanel?, settingsResume=false
    var colorWells:[String:NSColorWell]=[:]
    var smokePreferences:String?
    func applicationDidFinishLaunching(_ notification:Notification) {
        NSApp.appearance=nil
        NSTouchBar.isAutomaticCustomizeTouchBarMenuItemEnabled=true
        window=RideWindow(contentRect:NSRect(x:0,y:0,width:1280,height:720),styleMask:[.titled,.closable,.miniaturizable,.resizable,.fullSizeContentView],backing:.buffered,defer:false)
        window.styleMask.remove(.fullSizeContentView)
        window.title="Wheelie Ride"; window.contentMinSize=NSSize(width:760,height:520)
        window.titlebarAppearsTransparent=true; window.toolbarStyle = .unified; window.isReleasedWhenClosed=false; window.delegate=self
        let preferences:UserDefaults
        if CommandLine.arguments.contains("--smoke-test") {
            let domain="com.scratch.wheelieride.test."+UUID().uuidString
            smokePreferences=domain; preferences=UserDefaults(suiteName:domain)!
            preferences.register(defaults:["vehicle":1,"route":1,"sound":false,"obstacles":false])
        } else { preferences = .standard }
        game=RideView(frame:NSRect(x:0,y:0,width:780,height:720),preferences:preferences)
        sidebar=GarageSidebarController(kind:game.bike.kind,lockText: { [weak self] kind in
            guard let self else { return nil }
            let item=RideUnlock.vehicle(kind); return self.game.progress.isUnlocked(item) ? nil : "\(item.cost) monedas"
        },onSelect: { [weak self] kind in
            guard let self, self.game.mode == .garage else { return }
            self.game.bike.kind=kind; self.game.prefs.set(BikeKind.allCases.firstIndex(of:kind) ?? 0,forKey:"vehicle"); self.game.loadHandlingPreferences(); self.game.loadRecords(); self.game.syncState()
        })
        inspector=GarageInspectorController(game:game,onPlay: { [weak self] in self?.game.start() },onChange: { [weak self] in self?.game.syncState() })
        inspector.onVehicle = { [weak self] kind in
            guard let self, self.game.mode == .garage else { return }
            self.game.bike.kind=kind; self.game.prefs.set(BikeKind.allCases.firstIndex(of:kind) ?? 0,forKey:"vehicle"); self.game.loadHandlingPreferences(); self.game.loadRecords(); self.game.syncState()
        }
        let center=NSViewController(); center.view=game
        split=NSSplitViewController(); split.splitView.dividerStyle = .thin
        sidebarItem=NSSplitViewItem(sidebarWithViewController:sidebar); sidebarItem.minimumThickness=250; sidebarItem.maximumThickness=300; sidebarItem.canCollapse=true
        let middle=NSSplitViewItem(viewController:center); middle.minimumThickness=420
        inspectorItem=NSSplitViewItem(viewController:inspector); inspectorItem.minimumThickness=260; inspectorItem.maximumThickness=300; inspectorItem.canCollapse=true
        split.addSplitViewItem(sidebarItem); split.addSplitViewItem(middle); split.addSplitViewItem(inspectorItem)
        window.contentViewController=split
        let restored=window.setFrameUsingName("WheelieRideNativeWindow")
        window.setFrameAutosaveName("WheelieRideNativeWindow")
        touchBarWindowController=NSWindowController(window:window)
        window.touchBarFocusChanged = { [weak self] in self?.bindTouchBar() }
        bindTouchBar()
        let toolbar=NSToolbar(identifier:"WheelieRideNativeToolbar3"); toolbar.delegate=self; toolbar.displayMode = .iconOnly; toolbar.allowsUserCustomization=true; toolbar.autosavesConfiguration=true; window.toolbar=toolbar
        game.onStateChange = { [weak self] in self?.syncWindow() }
        buildMenu(); syncWindow(); if !restored { window.center() }; window.makeKeyAndOrderFront(nil); window.makeFirstResponder(game); NSApp.activate(ignoringOtherApps:true)
        if CommandLine.arguments.contains("--smoke-test") { smokeTest() }
        if let i=CommandLine.arguments.firstIndex(of:"--snapshot"),i+1<CommandLine.arguments.count { snapshots(to:CommandLine.arguments[i+1]) }
        if let i=CommandLine.arguments.firstIndex(of:"--responsive"),i+1<CommandLine.arguments.count { responsiveSnapshots(to:CommandLine.arguments[i+1]) }
        if let i=CommandLine.arguments.firstIndex(of:"--crash"),i+1<CommandLine.arguments.count { crashSequences(to:CommandLine.arguments[i+1]) }
        if let i=CommandLine.arguments.firstIndex(of:"--ragdoll"),i+1<CommandLine.arguments.count { ragdollSheets(to:CommandLine.arguments[i+1]) }
        if CommandLine.arguments.contains("--bench") { runBenchmark() }
        if CommandLine.arguments.contains("--fps") { measureLiveFrameRate() }
        if let i=CommandLine.arguments.firstIndex(of:"--screenshot"),i+1<CommandLine.arguments.count { windowScreenshots(to:CommandLine.arguments[i+1]) }
    }
    /// Developer aid: real frame rate in the real window, driven by the game's own 60 Hz timer and the run loop.
    func measureLiveFrameRate() {
        game.audio.enabled=false; game.progress.unlockEverything(); game.obstacles=true; game.bike.kind = .sport
        for (name,route,night) in [("Valle",0,false),("Sierra",1,false),("Nieve",3,false),("Ciudad con lluvia y noche",4,true)] {
            game.bike.route=route; game.night=night; game.challengeKind = .free; game.start(); game.keys=[126]
            RunLoop.current.run(until:Date(timeIntervalSinceNow:1))        // warm-up
            let before=game.sceneView.drawCount,start=ProcessInfo.processInfo.systemUptime
            RunLoop.current.run(until:Date(timeIntervalSinceNow:4))
            let fps=Double(game.sceneView.drawCount-before)/(ProcessInfo.processInfo.systemUptime-start)
            print(String(format:"%-28@ %5.1f fotogramas por segundo",name as NSString,fps))
        }
        NSApp.terminate(nil)
    }
    /// Developer aid: capture the real on-screen window (GPU layers included) after letting the run loop present frames.
    func windowScreenshots(to directory:String) {
        game.audio.enabled=false; game.progress.unlockEverything(); game.obstacles=true; game.bike.kind = .sport
        try? FileManager.default.createDirectory(atPath:directory,withIntermediateDirectories:true)
        func pump(_ seconds:Double) { RunLoop.current.run(until:Date(timeIntervalSinceNow:seconds)) }
        for (name,route,night) in [("live-valley",0,false),("live-snow",3,false),("live-city",4,true),("live-dunes",2,false)] {
            game.bike.route=route; game.night=night; game.challengeKind = .free; game.start(); game.bike.x=560
            for _ in 0..<45 { game.previous=ProcessInfo.processInfo.systemUptime-1/60; game.keys=[126]; game.tick(); pump(0.02) }
            pump(0.4)
            let id=CGWindowID(window.windowNumber)
            if let image=CGWindowListCreateImage(.null,.optionIncludingWindow,id,[.boundsIgnoreFraming,.bestResolution]) {
                let rep=NSBitmapImageRep(cgImage:image)
                try? rep.representation(using:.png,properties:[:])?.write(to:URL(fileURLWithPath:directory+"/"+name+".png"))
            }
        }
        NSApp.terminate(nil)
    }
    /// Frame cost of the heaviest scenes: one simulation tick plus one full draw into an offscreen bitmap.
    struct BenchResult { let name:String; let average:Double; let p95:Double; let worst:Double; var sections:[(String,Double)] = [] }
    var benchScale=0.0
    func measure(_ name:String,frames:Int,setup:()->Void)->BenchResult {
        game.audio.enabled=false; game.progress.unlockEverything()
        setup()
        var samples:[Double]=[]
        // The CPU cost per frame: simulation, the layer updates, and rasterising the two drawing views (world and HUD).
        // The backdrop and shading are Core Animation layers composited by the GPU, so they are not part of this number.
        func bitmap(for view:NSView)->NSBitmapImageRep? {
            if benchScale>0 {
                let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:Int(view.bounds.width*benchScale),pixelsHigh:Int(view.bounds.height*benchScale),bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)
                rep?.size=view.bounds.size; return rep
            }
            return view.bitmapImageRepForCachingDisplay(in:view.bounds)
        }
        guard let sceneRep=bitmap(for:game.sceneView),let hudRep=bitmap(for:game.hudView) else { return BenchResult(name:name,average:0,p95:0,worst:0) }
        for i in 0..<frames {
            let start=ProcessInfo.processInfo.systemUptime
            game.previous=start-1/60; game.keys=[126]; game.tick()
            game.sceneView.cacheDisplay(in:game.sceneView.bounds,to:sceneRep)
            game.hudView.cacheDisplay(in:game.hudView.bounds,to:hudRep)
            if i>=5 { samples.append((ProcessInfo.processInfo.systemUptime-start)*1000) }   // skip warm-up (textures, caches)
        }
        samples.sort()
        var result=BenchResult(name:name,average:samples.reduce(0,+)/Double(max(1,samples.count)),p95:samples[min(samples.count-1,Int(Double(samples.count)*0.95))],worst:samples.last ?? 0)
        result.sections=RideProfile.totals.sorted(by:{ $0.value>$1.value }).map { ($0.key,$0.value*1000/Double(frames)) }
        RideProfile.reset()
        return result
    }
    func benchmarkScenes(frames:Int)->[BenchResult] {
        var results:[BenchResult]=[]
        func scene(_ name:String,route:Int,night:Bool,obstacles:Bool,kind:BikeKind,challenge:RideChallengeKind,start:Double) {
            results.append(measure(name,frames:frames) {
                game.garage(); game.bike.kind=kind; game.bike.route=route; game.night=night; game.obstacles=obstacles; game.challengeKind=challenge
                game.start(); game.bike.x=start; game.bike.speed=9
            })
        }
        scene("Valle de día",route:0,night:false,obstacles:false,kind:.sport,challenge:.free,start:300)
        scene("Sierra con obstáculos",route:1,night:false,obstacles:true,kind:.motocross,challenge:.free,start:700)
        scene("Nieve con nevada",route:3,night:false,obstacles:true,kind:.sport,challenge:.free,start:500)
        scene("Ciudad, lluvia y noche",route:4,night:true,obstacles:true,kind:.sport,challenge:.free,start:500)
        game.rivalLevel = .expert
        scene("Ciudad, lluvia, noche y rival",route:4,night:true,obstacles:true,kind:.sport,challenge:.race,start:500)
        scene("Circuito en la Sierra",route:1,night:true,obstacles:true,kind:.sport,challenge:.circuit,start:900)
        game.garage(); game.night=false; game.obstacles=false; game.challengeKind = .free
        return results
    }
    func runBenchmark() {
        if let i=CommandLine.arguments.firstIndex(of:"--scale"),i+1<CommandLine.arguments.count { benchScale=Double(CommandLine.arguments[i+1]) ?? 0 }
        RideProfile.enabled=true
        print("Escena                              media    p95   peor   (ms de CPU por fotograma: simulación + capas + dibujo; el fondo va por GPU)")
        for r in benchmarkScenes(frames:90) {
            print(String(format:"%-34@ %6.2f %6.2f %6.2f",r.name as NSString,r.average,r.p95,r.worst))
            print("    "+r.sections.map { String(format:"%@ %.1f",$0.0 as NSString,$0.1) }.joined(separator:" · "))
        }
        RideProfile.enabled=false
        NSApp.terminate(nil)
    }
    /// Developer aid: the rider's fall alone, in close-up and without a background: several throws, one panel every 0.12 s.
    func ragdollSheets(to directory:String) {
        try? FileManager.default.createDirectory(atPath:directory,withIntermediateDirectories:true)
        let scenarios:[(String,BikeKind,RideVector,Double)]=[("forward-12",.sport,RideVector(12,1.5),2.0),("backward-spin",.sport,RideVector(8,3),-5.0),("slow-tipover",.commuter,RideVector(3,0.5),1.5)]
        let cols=6,rows=3,cw=300,ch=220,u=95.0
        for (name,kind,velocity,spin) in scenarios {
            let pose=RiderRig.solve(vehicle:kind.rig,lean:0.2)
            let doll=RiderRagdoll(pose:pose,origin:RideVector(0,0.6),pitch:0,velocity:velocity,angularVelocity:spin,route:0)
            let sheet=NSImage(size:NSSize(width:cw*cols,height:ch*rows)); sheet.lockFocusFlipped(true)
            NSColor(hex:0xE9EDF2).setFill(); NSRect(x:0,y:0,width:cw*cols,height:ch*rows).fill()
            for k in 0..<(cols*rows) {
                let ox=Double((k%cols)*cw),oy=Double((k/cols)*ch)
                NSGraphicsContext.saveGraphicsState()
                NSBezierPath(rect:NSRect(x:ox,y:oy,width:Double(cw),height:Double(ch))).addClip()
                let hip=doll.pose.hip
                // The panel follows the rider horizontally; the ground is drawn as a line.
                let t=NSAffineTransform(); t.translateX(by:ox+Double(cw)/2-hip.x*u,yBy:oy+Double(ch)-30); t.concat()
                NSColor(hex:0x6B5B4A).setStroke(); let ground=NSBezierPath(); ground.move(to:NSPoint(x:hip.x*u-200,y:-BikePhysics.ground(hip.x-2,route:0)*u)); ground.line(to:NSPoint(x:hip.x*u+200,y:-BikePhysics.ground(hip.x+2,route:0)*u)); ground.lineWidth=2; ground.stroke()
                game.art.drawRider(doll.displayPose,units:u,kind:kind,detached:true)
                NSGraphicsContext.restoreGraphicsState()
                NSColor.black.withAlphaComponent(0.5).setFill(); NSString(string:String(format:"%.2f s",Double(k)*0.12)).draw(at:NSPoint(x:ox+6,y:oy+4),withAttributes:[.font:NSFont.systemFont(ofSize:11)])
                for _ in 0..<14 { doll.update(1.0/120*1.0) }   // 0.12 s of simulation
            }
            sheet.unlockFocus()
            if let tiff=sheet.tiffRepresentation,let rep=NSBitmapImageRep(data:tiff) { try? rep.representation(using:.png,properties:[:])?.write(to:URL(fileURLWithPath:directory+"/"+name+".png")) }
        }
        NSApp.terminate(nil)
    }
    /// Developer aid: filmstrips of the rider's fall in three kinds of crash, one PNG each.
    func crashSequences(to directory:String) {
        game.audio.enabled=false; game.progress.unlockEverything(); game.obstacles=true; game.bike.kind = .sport
        try? FileManager.default.createDirectory(atPath:directory,withIntermediateDirectories:true)
        // key codes: 126 up (gas), 123 left (lift), 124 right (weight forward), 125 down (brake)
        let scenarios:[(String,BikeKind,Double,(Int)->[UInt16])]=[
            ("wheelie-loop",.sport,12,{ i in i<30 ? [126] : [126,123] }),
            ("stoppie-flip",.sport,16,{ i in i<20 ? [126] : [125,124] }),
            ("highspeed-landing",.motocross,22,{ i in i<30 ? [126] : (i<34 ? [126,49] : [126,123]) })]
        for (name,kind,speed,keys) in scenarios {
            game.bike.route=1; game.night=false; game.challengeKind = .free; game.bike.kind=kind; game.start(); game.bike.x=400; game.bike.speed=speed
            var frames:[NSBitmapImageRep]=[]; var crashTick = -1
            for i in 0..<900 {
                game.previous=ProcessInfo.processInfo.systemUptime-1/60; game.keys=Set(keys(i).map{$0}); game.tick()
                if game.mode == .crashing && crashTick<0 { crashTick=i }
                if crashTick>=0 && (i-crashTick)%9 == 0, let rep=game.snapshotRep(scale:0.5) { frames.append(rep) }
                if game.mode == .result || frames.count>=10 { break }
            }
            guard frames.count>0 else { print("no crash in \(name)"); continue }
            let cols=min(5,frames.count),rows=(frames.count+cols-1)/cols
            let w=Int(frames[0].size.width/2.2),h=Int(frames[0].size.height/2.2)
            let sheet=NSImage(size:NSSize(width:w*cols,height:h*rows)); sheet.lockFocus()
            for (k,rep) in frames.enumerated() { NSImage(size:rep.size).draw(in:.zero); let img=NSImage(size:rep.size); img.addRepresentation(rep); img.draw(in:NSRect(x:(k%cols)*w,y:(rows-1-k/cols)*h,width:w,height:h)) }
            sheet.unlockFocus()
            if let tiff=sheet.tiffRepresentation,let rep=NSBitmapImageRep(data:tiff) { try? rep.representation(using:.png,properties:[:])?.write(to:URL(fileURLWithPath:directory+"/"+name+".png")) }
        }
        NSApp.terminate(nil)
    }
    /// Developer aid: the same scene at very different window sizes, to check that nothing is cut off or overlapping.
    func responsiveSnapshots(to directory:String) {
        window.setFrameAutosaveName("")   // never save these artificial sizes as the user's window frame
        game.audio.enabled=false; game.progress.unlockEverything(); game.obstacles=true; game.bike.kind = .sport
        try? FileManager.default.createDirectory(atPath:directory,withIntermediateDirectories:true)
        func pump(_ seconds:Double) { RunLoop.current.run(until:Date(timeIntervalSinceNow:seconds)) }
        game.bike.route=0; game.night=false; game.challengeKind = .race; game.start(); game.bike.x=420
        for _ in 0..<50 { game.previous=ProcessInfo.processInfo.systemUptime-1/60; game.keys=[126]; game.tick() }
        for (w,h) in [(1280,720),(760,520),(900,900),(1700,640),(2560,1080),(1000,1400)] {
            window.setContentSize(NSSize(width:w,height:h)); pump(0.4)
            guard let rep=game.snapshotRep(scale:1) else { continue }
            let name="size-\(Int(game.bounds.width))x\(Int(game.bounds.height))"
            try? rep.representation(using:.png,properties:[:])?.write(to:URL(fileURLWithPath:directory+"/"+name+".png"))
        }
        // The garage in the real window (split view with its side panels) at a wide and a narrow size.
        game.garage()
        for (w,h) in [(1360,760),(820,600)] {
            window.setContentSize(NSSize(width:w,height:h)); syncWindow(); pump(0.7)
            if let image=CGWindowListCreateImage(.null,.optionIncludingWindow,CGWindowID(window.windowNumber),[.boundsIgnoreFraming,.bestResolution]) {
                try? NSBitmapImageRep(cgImage:image).representation(using:.png,properties:[:])?.write(to:URL(fileURLWithPath:directory+"/garage-\(w)x\(h).png"))
            }
        }
        // The whole inspector for a motorcycle and for the BMX (what applies to each).
        for kind in [BikeKind.sport,.bmx] {
            game.bike.kind=kind; game.challengeKind = .free; syncWindow(); pump(0.3)
            if let image=inspector.uiFullImage(),let tiff=image.tiffRepresentation,let rep=NSBitmapImageRep(data:tiff) { try? rep.representation(using:.png,properties:[:])?.write(to:URL(fileURLWithPath:directory+"/inspector-\(kind.rawValue).png")) }
        }
        NSApp.terminate(nil)
    }
    /// Developer aid: write one PNG per route (with obstacles on) using isolated preferences.
    func snapshots(to directory:String) {
        game.audio.enabled=false; game.progress.unlockEverything(); game.obstacles=true; game.bike.kind = .sport
        try? FileManager.default.createDirectory(atPath:directory,withIntermediateDirectories:true)
        for route in 0..<BikePhysics.routeCount {
            game.bike.route=route; game.night=false; game.start()
            game.bike.x = 560; for _ in 0..<90 { game.previous=ProcessInfo.processInfo.systemUptime-1/60; game.keys=[126]; game.tick() }
            guard let rep=game.snapshotRep() else { continue }
            try? rep.representation(using:.png,properties:[:])?.write(to:URL(fileURLWithPath:directory+"/route\(route).png"))
        }
        func shot(_ name:String) {
            guard let rep=game.snapshotRep() else { return }
            try? rep.representation(using:.png,properties:[:])?.write(to:URL(fileURLWithPath:directory+"/"+name+".png"))
        }
        // Every vehicle, same pose, for artwork review (`lineup-<kind>.png`).
        for kind in BikeKind.allCases {
            game.challengeKind = .free; game.bike.kind=kind; game.bike.route=0; game.night=false; game.start(); game.bike.x=400; game.bike.speed=8
            for _ in 0..<30 { game.previous=ProcessInfo.processInfo.systemUptime-1/60; game.keys=[126]; game.tick() }
            shot("lineup-"+kind.rawValue)
        }
        // Endless mode: three different zones, and a long route.
        game.challengeKind = .endless; game.bike.kind = .sport
        for (i,seed) in [(0,UInt64(5)),(1,UInt64(9)),(2,UInt64(21))] {
            game.bike.route = i == 1 ? 1 : 0; game.night=false; game.start(); BikePhysics.seed=seed; BikePhysics.rebuildProceduralCourse()
            game.bike.x=700+Double(i)*520; game.bike.reset(); game.bike.x=700+Double(i)*520; game.bike.speed=10
            for _ in 0..<50 { game.previous=ProcessInfo.processInfo.systemUptime-1/60; game.keys=[126]; game.tick() }
            shot("endless\(i)-\(BikePhysics.zoneTitle(at:game.bike.x).replacingOccurrences(of:" ",with:"_"))")
        }
        game.challengeKind = .free; game.bike.route=0
        // A fork: the warning ahead, the elevated road and the ground road.
        game.challengeKind = .endless; game.bike.kind = .sport; game.bike.route=0; game.night=false; game.start()
        BikePhysics.seed=7; BikePhysics.rebuildProceduralCourse()
        if let f=BikePhysics.nextFork(after:0) {
            for (name,lane,x) in [("fork-ahead",0,f.start-120),("fork-high",1,f.start+150),("fork-low",0,f.start+150)] {
                game.start(); BikePhysics.seed=7; BikePhysics.rebuildProceduralCourse(); game.bike.lanePreference=lane; game.bike.reset()
                game.bike.x=x; game.bike.reset(); game.bike.x=x; game.bike.lane=lane; game.bike.speed=11
                for _ in 0..<45 { game.previous=ProcessInfo.processInfo.systemUptime-1/60; game.keys=[126]; game.tick() }
                shot(name)
            }
        }
        // The newest vehicles.
        for (name,kind) in [("vehicle-cruiser",BikeKind.cruiser),("vehicle-electric",.electric)] {
            game.challengeKind = .free; game.bike.kind=kind; game.bike.route=0; game.night=false; game.start(); game.bike.x=400; game.bike.speed=8
            for _ in 0..<30 { game.previous=ProcessInfo.processInfo.systemUptime-1/60; game.keys=[126]; game.tick() }
            shot(name)
        }
        // Purchased styles on three different vehicles.
        for (name,kind,helmet,jacket,livery) in [("styled-sport",BikeKind.sport,HelmetStyle.flames,JacketStyle.reflective,Livery.number),("styled-street",.commuter,.stripe,.racing,.stripes),("styled-hyper",.hyperbike,.gold,.twoTone,.checker)] {
            game.art.helmetStyle=helmet; game.art.jacketStyle=jacket; game.art.livery=livery
            game.challengeKind = .free; game.bike.kind=kind; game.bike.route=0; game.night=false; game.start(); game.bike.x=400; game.bike.speed=8
            for _ in 0..<30 { game.previous=ProcessInfo.processInfo.systemUptime-1/60; game.keys=[126]; game.tick() }
            shot(name)
        }
        game.art.helmetStyle = .standard; game.art.jacketStyle = .standard; game.art.livery = .none; game.bike.kind = .sport
        // Weather: fog bank in the valley, storm in the city, blizzard on the snow.
        for (name,route,x,night,time) in [("weather-fog",0,550.0,false,1.0),("weather-storm",4,860.0,true,1.0),("weather-blizzard",3,690.0,false,1.0)] {
            game.weatherOn=true; game.challengeKind = .free; game.bike.kind = .sport; game.bike.route=route; game.night=night; game.start(); game.bike.x=x; game.bike.speed=9
            for _ in 0..<40 { game.previous=ProcessInfo.processInfo.systemUptime-1/60; game.keys=[126]; game.tick() }
            shot(name)
        }
        game.night=false
        // Night with headlight, the guided tutorial banner and a 360 in the air.
        game.bike.route=1; game.night=true; game.challengeKind = .free; game.start()
        game.bike.x=300; for _ in 0..<60 { game.previous=ProcessInfo.processInfo.systemUptime-1/60; game.keys=[126]; game.tick() }
        shot("night")
        game.night=false; game.bike.route=0; game.challengeKind = .tutorial; game.start()
        for _ in 0..<40 { game.previous=ProcessInfo.processInfo.systemUptime-1/60; game.keys=[126]; game.tick() }
        shot("tutorial")
        // Rider poses: hands off the bars (on the ground) and superman (in the air).
        game.challengeKind = .free; game.bike.route=0; game.start(); game.bike.speed=12
        for _ in 0..<50 { game.previous=ProcessInfo.processInfo.systemUptime-1/60; game.keys=[126,4]; game.tick() }
        shot("handsoff")
        game.start()
        for i in 0..<300 {
            game.previous=ProcessInfo.processInfo.systemUptime-1/60
            game.keys = i<40 ? [126] : (i<46 ? [126,49] : [126,9])
            game.tick()
            if i>60 && !game.bike.frontContact && !game.bike.rearContact && game.riderSuperman>0.9 { break }
        }
        shot("superman")
        game.challengeKind = .circuit; game.bike.route=1; game.start()
        game.bike.x=1150; for _ in 0..<60 { game.previous=ProcessInfo.processInfo.systemUptime-1/60; game.keys=[126]; game.tick() }
        shot("circuit"); game.garage()
        game.challengeKind = .free; game.start(); game.keys=[126]
        for i in 0..<400 {
            game.previous=ProcessInfo.processInfo.systemUptime-1/60
            game.keys = i<40 ? [126] : [126,49,5]
            game.tick()
            if !game.bike.frontContact && !game.bike.rearContact && game.bike.spinYaw>1.2 { break }
        }
        shot("spin")
        NSApp.terminate(nil)
    }
    func bindTouchBar() {
        guard !bindingTouchBar, let game, let window, let split else { return }
        bindingTouchBar=true
        defer { bindingTouchBar=false }
        game.updateTouchBar()
        let bar=game.bar.touchBar
        // AppKit lets a more narrowly scoped bar hide a window's bar. Pin the
        // game bar through its own responder subtree, including native buttons.
        let hosts:[NSResponder?]=[window,touchBarWindowController,split,split.view,split.splitViewItems[1].viewController]
        for host in hosts.compactMap({$0}) where host.touchBar !== bar { host.touchBar=bar }
        func bind(_ view:NSView) {
            if view.touchBar !== bar { view.touchBar=bar }
            view.subviews.forEach(bind)
        }
        bind(game)
        if let sheet=window.attachedSheet, sheet.touchBar !== bar { sheet.touchBar=bar }
    }
    func windowDidBecomeKey(_ notification:Notification) { bindTouchBar() }
    func syncWindow() {
        bindTouchBar()
        window?.subtitle=game.mode == .garage ? "Taller" : "\(game.bike.kind.title) · \(BikePhysics.routeNames[max(0,min(BikePhysics.routeCount-1,game.bike.route))])"
        let garage=game.mode == .garage
        if lastGarage != garage {
            lastGarage=garage
            if !garage { inspector.endEditing() }
            sidebarItem.isCollapsed = !garage || window.frame.width<Self.narrowWindow
            inspectorItem.isCollapsed = !garage
        }
        if garage { sidebar.reload(); sidebar.sync(kind:game.bike.kind); inspector.refresh() }
        window?.toolbar?.validateVisibleItems()
        let paused=game.mode == .paused, canStart=game.mode == .garage || game.mode == .result
        pauseItem?.image=NSImage(systemSymbolName:paused || canStart ? "play.fill" : "pause.fill",accessibilityDescription:canStart ? "Rodar" : paused ? "Continuar" : "Pausar")
        pauseItem?.label=canStart ? "Rodar" : paused ? "Continuar" : "Pausa"
        pauseItem?.toolTip=canStart ? "Salir a rodar · ⌘R" : "Pausa / continuar · P"
        pauseItem?.isEnabled=game.mode != .crashing
        nightItem?.image=NSImage(systemSymbolName:game.night ? "moon.stars" : "sun.max",accessibilityDescription:"Día o noche")
        audioItem?.image=NSImage(systemSymbolName:game.sound ? "speaker.wave.2" : "speaker.slash",accessibilityDescription:"Sonido")
    }
    func toolbarAllowedItemIdentifiers(_ toolbar:NSToolbar)->[NSToolbarItem.Identifier] { [.init("sidebar"),.init("garage"),.init("pause"),.init("restart"),.flexibleSpace,.space,.init("inspector"),.init("customize"),.init("night"),.init("sound")] }
    func toolbarDefaultItemIdentifiers(_ toolbar:NSToolbar)->[NSToolbarItem.Identifier] { [.init("sidebar"),.init("garage"),.init("pause"),.flexibleSpace,.init("sound"),.init("inspector")] }
    func toolbar(_ toolbar:NSToolbar,itemForItemIdentifier id:NSToolbarItem.Identifier,willBeInsertedIntoToolbar flag:Bool)->NSToolbarItem? {
        let item=NSToolbarItem(itemIdentifier:id)
        let data:(String,String,Selector)
        switch id.rawValue {
        case "sidebar": data=("Mostrar u ocultar vehículos","sidebar.left",#selector(toggleSidebar))
        case "inspector": data=("Mostrar u ocultar inspector","sidebar.right",#selector(toggleInspector))
        case "garage": data=("Taller","square.grid.2x2",#selector(garage))
        case "pause": data=("Rodar / Pausa","play.fill",#selector(primaryAction)); if flag { pauseItem=item }
        case "restart": data=("Reiniciar · R","arrow.counterclockwise",#selector(restart))
        case "customize": data=("Personalizar piloto y moto","slider.horizontal.3",#selector(customize))
        case "night": data=("Día o noche","sun.max",#selector(toggleNight)); if flag { nightItem=item }
        case "sound": data=("Sonido del motor","speaker.wave.2",#selector(toggleSound)); if flag { audioItem=item }
        default:return nil
        }
        item.label=data.0; item.paletteLabel=data.0; item.toolTip=data.0; item.image=NSImage(systemSymbolName:data.1,accessibilityDescription:data.0); item.target=self; item.action=data.2
        return item
    }
    func validateToolbarItem(_ item:NSToolbarItem)->Bool {
        if window?.attachedSheet != nil { return false }
        if ["sidebar","inspector"].contains(item.itemIdentifier.rawValue) { return game.mode == .garage }
        if item.itemIdentifier.rawValue == "pause" { return game.mode != .crashing }
        return true
    }
    func validateMenuItem(_ item:NSMenuItem)->Bool {
        if item.action == #selector(touchBarPalette) { return game.mode == .riding && window.attachedSheet == nil }
        if item.action == #selector(pause) { return (game.mode == .riding || game.mode == .paused) && window.attachedSheet == nil }
        if item.action == #selector(restart) || item.action == #selector(garage) { return window.attachedSheet == nil }
        return true
    }
    @objc func toggleSidebar() { guard game.mode == .garage else { return }; sidebarItem.animator().isCollapsed.toggle() }
    @objc func toggleInspector() { guard game.mode == .garage else { return }; inspectorItem.animator().isCollapsed.toggle() }
    @objc func garage() { game.garage(); window.makeFirstResponder(game) }
    @objc func primaryAction() { if game.mode == .garage || game.mode == .result { game.start() } else { game.pause() }; window.makeFirstResponder(game) }
    @objc func pause() { game.pause(); window.makeFirstResponder(game) }
    @objc func restart() { game.start() }
    @objc func toggleNight() { game.night.toggle(); game.prefs.set(game.night,forKey:"night"); game.needsDisplay=true; syncWindow(); window.makeFirstResponder(game) }
    @objc func toggleSound() { game.sound.toggle(); game.audio.enabled=game.sound; game.prefs.set(game.sound,forKey:"sound"); syncWindow(); window.makeFirstResponder(game) }
    @objc func toggleCones(_ sender:Any?) { game.obstacles.toggle(); game.prefs.set(game.obstacles,forKey:"obstacles"); game.syncState() }
    @objc func toggleFullScreen() { window.toggleFullScreen(nil) }
    @objc func touchBarPalette() { NSApp.toggleTouchBarCustomizationPalette(nil) }
    @objc func showHelp() {
        guard window.attachedSheet == nil else { return }
        let resume=game.mode == .riding
        if resume { game.pause() }
        let alert=NSAlert(); alert.messageText="Encuentra el punto de equilibrio"
        alert.informativeText="↑ o W: acelerar\n← o A: levantar la rueda\n→ o D: inclinarte hacia delante\n↓ o S: frenos combinados\nZ: freno delantero · X: freno trasero\nQ: bajar marcha · F: subir marcha (modo manual)\nE: invertido (freno + peso delante)\nEspacio: saltar · T: truco\nP o Escape: pausar · R: reiniciar\n\nMantén acelerar + levantar para iniciar un caballito. Suelta levantar y corrige con → antes de volcar.\n\nEn la Touch Bar puedes mantener GAS y LEVANTAR con dos dedos. Suelta para dejar de actuar. Para un invertido, entra con velocidad, mantén FRENO + BAJAR y corrige con LEVANTAR. También puedes añadir INVERTIDO desde Visualización > Personalizar Touch Bar."
        alert.addButton(withTitle:"A rodar"); alert.beginSheetModal(for:window) { [weak self] _ in if resume { self?.game.pause() }; self?.game.syncState(); self?.window.makeFirstResponder(self?.game) }; game.syncState()
    }
    func buildMenu() {
        let menu=NSMenu()
        func submenu(_ title:String)->NSMenu { let item=NSMenuItem(title:title,action:nil,keyEquivalent:""); let sub=NSMenu(title:title); item.submenu=sub; menu.addItem(item); return sub }
        func add(_ menu:NSMenu,_ title:String,_ action:Selector,_ key:String="",mods:NSEvent.ModifierFlags = .command) { let i=menu.addItem(withTitle:title,action:action,keyEquivalent:key); i.target=self; i.keyEquivalentModifierMask=mods }
        let app=submenu("Wheelie Ride")
        let about=app.addItem(withTitle:"Acerca de Wheelie Ride",action:#selector(NSApplication.orderFrontStandardAboutPanel(_:)),keyEquivalent:""); about.target=NSApp
        app.addItem(.separator()); add(app,"Personalizar piloto y moto…",#selector(customize),","); app.addItem(.separator())
        let hide=app.addItem(withTitle:"Ocultar Wheelie Ride",action:#selector(NSApplication.hide(_:)),keyEquivalent:"h"); hide.target=NSApp
        app.addItem(.separator()); let quit=app.addItem(withTitle:"Salir de Wheelie Ride",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q"); quit.target=NSApp
        let partida=submenu("Partida"); add(partida,"Salir a rodar / Reiniciar",#selector(restart),"r"); add(partida,"Pausa / Continuar",#selector(pause),"p"); partida.addItem(.separator()); add(partida,"Volver al taller",#selector(garage),"g"); add(partida,"Activar / desactivar conos",#selector(toggleCones(_:)))
        let visual=submenu("Visualización"); add(visual,"Mostrar / ocultar vehículos",#selector(toggleSidebar),"s",mods:[.command,.control]); add(visual,"Mostrar / ocultar inspector",#selector(toggleInspector),"i",mods:[.command,.option]); visual.addItem(.separator()); add(visual,"Día / Noche",#selector(toggleNight),"d",mods:[.command,.shift]); add(visual,"Sonido",#selector(toggleSound),"m",mods:[.command,.shift]); visual.addItem(.separator()); add(visual,"Pantalla completa",#selector(toggleFullScreen),"f",mods:[.command,.control]); add(visual,"Personalizar Touch Bar…",#selector(touchBarPalette))
        let help=submenu("Ayuda"); add(help,"Controles de Wheelie Ride",#selector(showHelp),"?"); NSApp.helpMenu=help
        NSApp.mainMenu=menu
    }
    @objc func customize() {
        guard window.attachedSheet == nil else { return }
        if game.mode == .garage { inspectorItem.isCollapsed=false; return }
        if settings != nil { return }
        settingsResume=game.mode == .riding
        if settingsResume { game.pause() }
        let panel=NSPanel(contentRect:NSRect(x:0,y:0,width:430,height:440),styleMask:[.titled],backing:.buffered,defer:false); panel.title="Piloto y moto"; settings=panel
        let content=NSView(); panel.contentView=content
        let heading=NSTextField(labelWithString:"Hazla tuya"); heading.font = .systemFont(ofSize:22,weight:.bold)
        let subtitle=NSTextField(wrappingLabelWithString:"Los cambios se guardan para la próxima salida."); subtitle.textColor = .secondaryLabelColor; subtitle.font = .systemFont(ofSize:12)
        let stack=NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing=15
        stack.addArrangedSubview(heading); stack.addArrangedSubview(subtitle)
        let values:[(String,String,NSColor)]=[("Moto","body",game.art.body),("Chaqueta","jacket",game.art.jacket),("Casco","helmetColor",game.art.helmet),("Piel","skin",game.art.skin)]
        for (title,key,color) in values {
            let label=NSTextField(labelWithString:title); label.widthAnchor.constraint(equalToConstant:240).isActive=true
            let well=NSColorWell(); well.color=color; well.target=self; well.action=#selector(colorChanged(_:)); well.identifier=NSUserInterfaceItemIdentifier(key); well.widthAnchor.constraint(equalToConstant:62).isActive=true; well.heightAnchor.constraint(equalToConstant:25).isActive=true; colorWells[key]=well
            let row=NSStackView(views:[label,well]); row.orientation = .horizontal; stack.addArrangedSubview(row)
        }
        for (label,key,state) in [("Usar casco","helmet",game.art.helmetOn),("Llevar acompañante (vehículos de dos plazas)","passenger",game.art.passenger),("Conos en la carretera","obstacles",game.obstacles)] {
            let button=NSButton(checkboxWithTitle:label,target:self,action:#selector(optionChanged(_:))); button.identifier=NSUserInterfaceItemIdentifier(key); button.state=state ? .on : .off; stack.addArrangedSubview(button)
        }
        let done=NSButton(title:"Listo",target:self,action:#selector(closeSettings)); done.bezelStyle = .rounded; done.keyEquivalent="\r"; done.bezelColor = .controlAccentColor
        content.addSubview(stack); content.addSubview(done); stack.translatesAutoresizingMaskIntoConstraints=false; done.translatesAutoresizingMaskIntoConstraints=false
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:content.leadingAnchor,constant:30),stack.topAnchor.constraint(equalTo:content.topAnchor,constant:26),stack.trailingAnchor.constraint(equalTo:content.trailingAnchor,constant:-30),done.trailingAnchor.constraint(equalTo:content.trailingAnchor,constant:-28),done.bottomAnchor.constraint(equalTo:content.bottomAnchor,constant:-22),done.widthAnchor.constraint(equalToConstant:96)])
        window.beginSheet(panel)
        game.syncState()
    }
    @objc func colorChanged(_ sender:NSColorWell) {
        let key=sender.identifier?.rawValue ?? "body"
        switch key { case "jacket":game.art.jacket=sender.color; case "helmetColor":game.art.helmet=sender.color; case "skin":game.art.skin=sender.color; default:game.art.body=sender.color }
        game.saveColor(sender.color,key)
    }
    @objc func optionChanged(_ sender:NSButton) {
        let key=sender.identifier?.rawValue ?? "helmet",value=sender.state == .on
        switch key { case "passenger":game.art.passenger=value; case "obstacles":game.obstacles=value; default:game.art.helmetOn=value }
        game.prefs.set(value,forKey:key); game.needsDisplay=true
    }
    @objc func closeSettings() {
        guard let settings else { return }; window.endSheet(settings); settings.orderOut(nil); self.settings=nil; colorWells.removeAll(); NSColorPanel.shared.orderOut(nil)
        if settingsResume && game.mode == .paused { game.pause() }; game.syncState(); window.makeFirstResponder(game)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool { true }
    func applicationWillTerminate(_ notification:Notification) { game?.preserveRun(); game?.audio.stop(); game?.bar.releaseAll() }
    func windowWillClose(_ notification:Notification) { game.preserveRun(); game.audio.stop(); game.bar.releaseAll() }
    /// Exercise the actual UI state machine without injecting global keyboard events.
    func smokeTest() {
        window.setFrameAutosaveName(""); window.setContentSize(NSSize(width:1280,height:720))   // a known, unsaved size: the layout depends on it
        game.audio.enabled=false
        // ---- Garage UI flow: wallet, locks, purchases, challenge, rival and option controls ----
        let originalKind=game.bike.kind,originalRoute=game.bike.route
        func gui() { game.syncState(); inspector.refresh() }
        gui()
        precondition(inspector.uiWalletText.hasPrefix("\(RideProgress.startingCoins)"),"Wallet shows the starting coins")
        precondition(inspector.uiMissionTexts.count == 4 && inspector.uiMissionTexts.allSatisfy { !$0.isEmpty },"Missions are listed in the garage")
        game.bike.kind = .hyperbike; game.start(); gui()
        precondition(game.mode == .garage && !inspector.uiPlayEnabled && inspector.uiUnlockVisible && !inspector.uiUnlockEnabled,"A locked, unaffordable vehicle cannot start or be bought")
        precondition(inspector.uiUnlockTitle.contains("Hyper R 1000") && inspector.uiUnlockTitle.contains("220"),"The unlock button names the vehicle and its price")
        game.bike.kind = .scooter; gui()
        precondition(inspector.uiUnlockVisible && inspector.uiUnlockEnabled && !inspector.uiPlayEnabled,"An affordable vehicle offers purchase")
        inspector.uiUnlock(); gui()
        precondition(game.progress.isUnlocked(.vehicle(.scooter)) && game.progress.wallet == RideProgress.startingCoins-40 && inspector.uiPlayEnabled && !inspector.uiUnlockVisible,"Buying through the inspector spends coins and enables Play")
        inspector.uiSelectRoute(3); gui()
        precondition(game.bike.route == 3 && !inspector.uiPlayEnabled && inspector.uiUnlockTitle.contains("Nieve"),"A locked route blocks Play")
        game.start(); precondition(game.mode == .garage,"A locked route must not start")
        inspector.uiUnlock(); gui()
        precondition(game.progress.wallet == RideProgress.startingCoins-140 && inspector.uiPlayEnabled,"Buying the route spends its price")
        inspector.uiSelectRoute(4); gui()
        precondition(!inspector.uiUnlockEnabled,"Not enough coins left for the city route")
        precondition(!game.progress.unlock(.route(4)) && game.progress.wallet == RideProgress.startingCoins-140,"A failed purchase changes nothing")
        for kind in RideChallengeKind.allCases {
            inspector.uiSelectChallenge(kind); gui()
            precondition(game.challengeKind == kind && inspector.uiRivalEnabled == (kind == .race),"Challenge \(kind.rawValue) and rival controls enable only for the race")
        }
        inspector.uiSelectChallenge(.race); inspector.uiSelectRival(.expert); inspector.uiToggleRivalVehicle()
        precondition(game.rivalLevel == .expert && !game.rivalSameVehicle,"Rival options reach the game")
        inspector.uiSelectChallenge(.free)
        let contextBefore=game.runContext
        inspector.uiToggle("abs"); precondition(game.absOn && game.runContext != contextBefore && game.runContext.contains(".abs"),"ABS changes the record context")
        inspector.uiToggle("abs"); precondition(!game.absOn && game.runContext == contextBefore,"ABS toggles back")
        inspector.uiSelectDifficulty(.realistic)
        precondition(game.difficulty == .realistic && game.runContext.contains(".realista") && game.bike.assist == .realistic,"Difficulty reaches the game and the record context")
        inspector.uiSelectDifficulty(.assisted); precondition(game.runContext.contains(".asistido"),"Assisted has its own records")
        inspector.uiSelectDifficulty(.normal); precondition(game.runContext == contextBefore,"Normal keeps the original record context")
        inspector.uiToggle("weather"); precondition(!game.weatherOn && !game.runContext.contains(".clima"),"Weather toggles off with its own records")
        inspector.uiToggle("weather"); precondition(game.weatherOn && game.runContext.contains(".clima"),"Weather toggles back on")
        inspector.uiToggle("obstacles"); precondition(game.obstacles,"Obstacles checkbox")
        inspector.uiToggle("obstacles")
        // Cosmetic styles must be owned before riding; buying them works through the same unlock button.
        inspector.uiSelectRoute(originalRoute); game.bike.kind=originalKind; gui()
        game.progress.earn(500)
        inspector.uiSelectHelmet(.flames); gui()
        precondition(game.art.helmetStyle == .flames && !inspector.uiPlayEnabled && inspector.uiUnlockVisible && inspector.uiUnlockTitle.contains("llamas"),"A locked helmet style blocks Play and offers purchase")
        game.start(); precondition(game.mode == .garage,"A locked style must not start")
        inspector.uiSelectJacket(.reflective); inspector.uiSelectLivery(.number); gui()
        precondition(inspector.uiUnlockTitle.contains("chaqueta") && inspector.uiUnlockTitle.contains("decoración"),"Several locked styles are bought together")
        let walletBeforeStyles=game.progress.wallet
        inspector.uiUnlock(); gui()
        precondition(game.progress.wallet == walletBeforeStyles-HelmetStyle.flames.cost-JacketStyle.reflective.cost-Livery.number.cost && inspector.uiPlayEnabled && !inspector.uiUnlockVisible,"Buying styles spends their prices and enables Play")
        precondition(game.prefs.integer(forKey:"helmetStyle") == HelmetStyle.flames.rawValue && game.prefs.integer(forKey:"livery") == Livery.number.rawValue,"Styles are remembered")
        // Every vehicle draws with every style combination.
        for helmet in HelmetStyle.allCases { for jacket in JacketStyle.allCases { for livery in Livery.allCases {
            game.art.helmetStyle=helmet; game.art.jacketStyle=jacket; game.art.livery=livery
            for kind in BikeKind.allCases { game.bike.kind=kind; precondition(game.snapshotRep(scale:0.25) != nil,"Styled frame must render") }
        } } }
        inspector.uiSelectHelmet(.standard); inspector.uiSelectJacket(.standard); inspector.uiSelectLivery(.none)
        inspector.uiSelectRoute(originalRoute); game.bike.kind=originalKind; gui()
        game.progress.unlockEverything()
        func checkBar(_ expected:RideTouchBarMode) {
            precondition(game.bar.mode == expected)
            let selected=game.bar.touchBar
            precondition(window.touchBar === selected && game.touchBar === selected)
            precondition(split.touchBar === selected && touchBarWindowController.touchBar === selected)
            precondition(game.continueButton.touchBar === selected && game.retryButton.touchBar === selected)
        }
        checkBar(.garage)
        let selected=game.bike.kind
        for kind in BikeKind.allCases {
            game.bike.kind=kind;game.loadRecords();game.syncState()
            precondition(game.bike.kind == kind && game.bike.frontContact && game.bike.rearContact)
            precondition(game.recordKey.contains(kind.rawValue))
            let image=NSImage(size:game.bounds.size);image.lockFocusFlipped(true)
            game.drawGarage();image.unlockFocus()
        }
        game.bike.kind = .hyperbike;game.start();game.bike.x = -3000;game.bike.speed=45
        for _ in 0..<180 { game.previous=ProcessInfo.processInfo.systemUptime-1/60;game.tick() }
        precondition(game.art.metresToPixels<RideScene.metresToPixels*0.7 && game.art.metresToPixels>=RideScene.metresToPixels*0.15)
        game.garage();precondition(game.art.metresToPixels == RideScene.metresToPixels)
        game.bike.kind=selected;game.loadRecords();game.syncState()
        // Every route renders with obstacles, puddles and weather without crashing.
        game.obstacles=true
        for route in 0..<BikePhysics.routeCount {
            game.bike.route=route; game.night=route == 4; game.start()
            for _ in 0..<45 { game.previous=ProcessInfo.processInfo.systemUptime-1/60; game.tick() }
            precondition(game.snapshotRep(scale:1) != nil,"Every route must compose a frame"); precondition(game.backdrop.route == route && !(game.backdrop.root.sublayers ?? []).isEmpty,"The backdrop layers follow the route")
        }
        // The scrolling backdrop never leaves a gap, whatever the route, time of day, window height or camera position.
        func covers(_ spans:[ClosedRange<Double>])->Bool {
            let sorted=spans.sorted { $0.lowerBound<$1.lowerBound }
            var reach=0.0
            for span in sorted { if span.lowerBound>reach+0.5 { return false }; reach=max(reach,span.upperBound) }
            return reach>=1280
        }
        for (route,night) in [(0,false),(1,true),(2,false),(3,false),(4,true),(4,false)] {
            for height in [620.0,752.0,1100.0] {
                game.backdrop.configure(route:route,night:night,height:height,backing:2)
                for step in 0..<400 {
                    game.backdrop.update(camera:Double(step)*1_234.567+Double(step%7)*0.31)
                    if route == 3 { precondition(covers(game.backdrop.mountainSpans) || game.backdrop.mountainSpans.allSatisfy { $0.lowerBound<=0 && $0.upperBound>=1280 },"Snow mountains must span the window (step \(step))") }
                    else if route == 4 { for strip in game.backdrop.stripSpans { precondition(covers(strip),"A city strip leaves a gap (step \(step), height \(height))") } }
                    else { precondition(covers(game.backdrop.scrollingSpans),"Photo tiles leave a gap on route \(route) at step \(step)") }
                }
            }
        }
        game.night=false; game.obstacles=false; game.bike.route=originalRoute
        // Race mode spawns a rival that rides the same physics.
        game.challengeKind = .race; game.start()
        precondition(game.rival != nil,"Race challenge needs a rival")
        for _ in 0..<120 { game.previous=ProcessInfo.processInfo.systemUptime-1/60; game.tick() }
        precondition((game.rival?.x ?? 0)>1,"The rival must ride")
        game.challengeKind = .free; game.start(); precondition(game.rival == nil)
        // Expert rival on another vehicle.
        game.rivalLevel = .expert; game.rivalSameVehicle=false; game.challengeKind = .race; game.start()
        precondition(game.rivalRun?.level == .expert && game.rivalRun?.bike.kind != game.bike.kind,"The rival may ride another vehicle")
        // Tutorial: no obstacles, and holding the throttle completes the first step.
        game.obstacles=true; game.challengeKind = .tutorial; game.start()
        precondition(!game.obstaclesOn && game.tutorial.step == .accelerate,"Tutorial starts clean")
        game.keys=[126]
        for _ in 0..<240 { game.previous=ProcessInfo.processInfo.systemUptime-1/60; game.tick() }
        precondition(game.tutorial.step != .accelerate || game.bike.crashed,"Throttle completes the first tutorial step")
        game.obstacles=false
        // Endless: no finish line.
        game.bike.route=0; game.challengeKind = .endless; game.start()
        precondition(game.bike.endless && game.runContext.contains(".endless"),"Endless mode flag and record context")
        precondition(BikePhysics.procedural && BikePhysics.endlessCourse && !game.obstacleList.isEmpty && game.obstacleList == BikePhysics.proceduralObstacles,"Endless mode generates its own terrain and obstacles")
        game.bike.x=900; for _ in 0..<90 { game.previous=ProcessInfo.processInfo.systemUptime-1/60; game.keys=[126]; game.tick() }
        precondition(game.snapshotRep(scale:0.25) != nil,"An endless frame composes")
        // A fork, through the real game loop: an automatic cautious rider takes the elevated road and is paid for it.
        game.challengeKind = .endless; game.bike.kind = .sport; game.bike.route=0; game.start()
        BikePhysics.seed=7; BikePhysics.rebuildProceduralCourse(); game.obstacles=false
        guard let fork=BikePhysics.nextFork(after:0) else { preconditionFailure("The endless course must have forks") }
        game.toggleLane(); precondition(game.bike.lanePreference == 1,"C chooses the elevated road")
        var sawHigh=false
        for _ in 0..<40_000 where game.mode == .riding && game.bike.x<fork.end+40 {
            game.previous=ProcessInfo.processInfo.systemUptime-1/60
            var held=Set<UInt16>(); if game.bike.speed<12 { held.insert(126) }; if game.bike.speed>12.6 { held.insert(125) }
            if game.bike.angle < -0.25 { held.insert(123) }; if game.bike.angle>0.25 { held.insert(124) }
            game.keys=held; game.tick()
            if game.bike.lane == 1 && game.bike.x>fork.start+80 && game.bike.x<fork.end-80 { sawHigh=true; precondition(BikePhysics.ground(game.bike.x,route:0,lane:1)-BikePhysics.ground(game.bike.x,route:0,lane:0)>1.5) }
        }
        precondition(game.mode == .riding && !game.bike.crashed && game.bike.x>fork.end,"The rider must cross the fork on the elevated road")
        precondition(sawHigh && game.score.total>=150 && game.forkEnd == nil,"The elevated road is paid out when the roads join")
        game.obstacles=false
        // A longer route: rodar libre at 3,000 m is procedural, has its own finish and its own record context.
        game.lengthIndex=1; game.challengeKind = .free; game.start()
        precondition(BikePhysics.procedural && !BikePhysics.endlessCourse && BikePhysics.finish == 3000 && game.bike.finishDistance == 3000 && game.runContext.contains(".len3000"),"Long route setup")
        game.bike.x=2500; for _ in 0..<60 { game.previous=ProcessInfo.processInfo.systemUptime-1/60; game.keys=[126]; game.tick() }
        precondition(game.snapshotRep(scale:0.25) != nil && !game.bike.finished,"A long-route frame composes")
        // Other challenges keep the classic 1,200 m course whatever length is selected.
        game.challengeKind = .timeTrial; game.start(); precondition(!BikePhysics.procedural && BikePhysics.finish == 1200,"Only rodar libre and carrera use long routes")
        game.lengthIndex=0; game.challengeKind = .endless; game.start()
        game.bike.x = 1190; game.bike.speed=14; game.keys=[126]
        for _ in 0..<300 where game.mode == .riding { game.previous=ProcessInfo.processInfo.systemUptime-1/60; game.tick() }
        precondition(!game.bike.finished,"Endless never finishes")
        // Closed circuit: global terrain switch, lap times, the finish after the last lap, and a clean exit.
        game.bike.route=1; game.challengeKind = .circuit; game.start()
        precondition(BikePhysics.circuit && game.bike.laps == 3 && game.runContext.contains(".circuit3") && game.obstacleList == game.circuitList,"Circuit mode switches the terrain and obstacles")
        game.bike.x = 1196; game.bike.speed=12; game.keys=[126]
        for _ in 0..<240 where game.mode == .riding { game.previous=ProcessInfo.processInfo.systemUptime-1/60; game.tick() }
        precondition(game.lapTimes.count == 1 || game.bike.crashed,"Crossing 1,200 m records a lap time")
        game.garage(); precondition(!BikePhysics.circuit,"Leaving the circuit restores the normal terrain")
        game.bike.route=0; game.challengeKind = .circuit; game.rivalLevel = .normal; game.start()
        precondition(game.rivalRuns.count == 3 && game.rivalRuns.allSatisfy { $0.bike.laps == 3 },"The circuit field has three rivals")
        for _ in 0..<150 { game.previous=ProcessInfo.processInfo.systemUptime-1/60; game.keys=[126]; game.tick() }
        precondition(game.racePosition>=1 && game.racePosition<=4 && game.rivalRuns.allSatisfy { $0.bike.x>0 },"Rivals ride and standings update")
        game.garage(); game.challengeKind = .circuit; game.start()
        game.bike.x = 3596; game.bike.speed=14; game.keys=[126]
        for _ in 0..<240 where game.mode == .riding { game.previous=ProcessInfo.processInfo.systemUptime-1/60; game.tick() }
        precondition(game.mode == .result && game.bike.finished && abs(game.bike.distance-3600)<0.01,"The circuit finishes after three laps")
        precondition(game.racePosition == 1 && game.challenges.completed && game.stateDetail.stringValue.contains("Posición 1/4") && game.runNotes.contains { $0.contains("Premio de posición 1") },"Finishing first on the circuit gives the podium, the prize and the standings text")
        game.garage(); game.bike.route=originalRoute; game.challengeKind = .free
        // Performance guard: even the heaviest scene (rain, night, obstacles, rival) must stay far from a
        // visible stutter. The bound is deliberately generous so a slow CI machine does not flake.
        // Ratios, not absolute times, so a slow CI machine does not flake: the heaviest scene may cost
        // at most 4x the plain valley, and nothing may take half a second per frame.
        let scenes=benchmarkScenes(frames:40)
        let baseline=scenes.first?.average ?? 1
        for r in scenes {
            precondition(r.average<500,"Frame cost absurd in \(r.name): \(r.average) ms average")
            precondition(r.average<baseline*4,"\(r.name) costs \(r.average) ms against \(baseline) ms for the plain valley")
        }
        game.garage(); game.challengeKind = .free; game.bike.route=originalRoute
        // In-run reward toasts: a flip would unlock "Primera voltereta" and the game announces it once.
        if !game.stats.earned.contains("first-flip") {
            game.challengeKind = .free; game.bike.route=0; game.start(); game.report.flips=1
            for _ in 0..<80 { game.previous=ProcessInfo.processInfo.systemUptime-1/60; game.keys=[126]; game.tick() }
            precondition(game.toasts.contains { $0.text.contains("Primera voltereta") },"An achievement within reach is announced during the run")
            let count=game.toasts.count
            for _ in 0..<80 { game.previous=ProcessInfo.processInfo.systemUptime-1/60; game.keys=[126]; game.tick() }
            precondition(game.toasts.filter { $0.text.contains("Primera voltereta") }.count <= 1 && game.toasts.count <= max(count,1)+1,"A toast is not repeated")
            precondition(!game.stats.earned.contains("first-flip"),"Toasts do not pay out: rewards are given when the run ends")
            game.garage()
        }
        // Dynamic weather: a storm on the Sierra soaks the road and shows its label; with it off the road stays dry.
        game.weatherOn=true; game.challengeKind = .free; game.bike.route=1; game.start(); game.bike.x=780; game.bike.speed=8
        for _ in 0..<30 { game.previous=ProcessInfo.processInfo.systemUptime-1/60; game.keys=[126]; game.tick() }
        precondition(game.weather.storm && game.bike.wetness>0.9 && game.weather.label == "Tormenta","A storm must soak the Sierra road")
        precondition(game.snapshotRep(scale:0.25) != nil && game.backdrop.route == 1,"A stormy frame composes")
        game.weatherOn=false; game.start(); game.bike.x=780
        for _ in 0..<30 { game.previous=ProcessInfo.processInfo.systemUptime-1/60; game.keys=[126]; game.tick() }
        precondition(!game.weather.storm && game.bike.wetness == 0,"Dynamic weather off keeps the road dry")
        game.bike.route=4; game.start()
        for _ in 0..<10 { game.previous=ProcessInfo.processInfo.systemUptime-1/60; game.keys=[126]; game.tick() }
        precondition(game.bike.wetness == 1,"The city stays rainy without dynamic weather")
        game.weatherOn=true; game.garage(); game.bike.route=originalRoute
        // Extra tricks: hands off, spin and superman keys are accepted while riding.
        game.challengeKind = .free; game.start(); game.keys=[126,4,5,9]
        for _ in 0..<30 { game.previous=ProcessInfo.processInfo.systemUptime-1/60; game.tick() }
        precondition(game.noHandsHeld && game.spinHeld && game.supermanHeld,"Trick keys")
        // A full run to the finish line: coins, score, stats, missions and achievements all update once.
        game.garage(); game.bike.route=0; game.challengeKind = .free; game.start()
        let walletBefore=game.progress.wallet,runsBefore=game.stats.totals.runs
        game.bike.x = 1196; game.bike.speed=15; game.keys=[126]
        for _ in 0..<240 where game.mode == .riding { game.previous=ProcessInfo.processInfo.systemUptime-1/60; game.tick() }
        precondition(game.mode == .result && game.bike.finished,"The run must reach the finish line")
        precondition(game.progress.wallet>walletBefore && game.lastReward == game.progress.wallet-walletBefore,"Coins are paid exactly once")
        precondition(game.stats.totals.runs == runsBefore+1 && game.stats.totals.finishes>=1 && game.stats.earned.contains("first-finish"),"Stats and achievements record the run")
        precondition(game.stateDetail.stringValue.contains("puntos") && game.stateDetail.stringValue.contains("monedas"),"The result screen reports score and coins")
        game.saveRun(); precondition(game.stats.totals.runs == runsBefore+1,"Saving again must not double count")
        precondition(inspector.statsText.contains("Primera meta") && inspector.statsText.contains("LOGROS"),"Stats sheet text")
        game.garage()
        game.start(); checkBar(.riding)
        game.keys.insert(14)
        precondition(game.held(.brake) && game.held(.leanForward) && !game.held(.leanBack),"E must combine front weight transfer with braking")
        game.keys.remove(14);game.touchHeld.insert(.stoppie)
        precondition(game.held(.brake) && game.held(.leanForward))
        game.pause();precondition(!game.held(.brake) && !game.held(.leanForward));game.pause()
        game.touchHeld.removeAll();game.bike.x = -500;game.bike.speed=12;game.keys.insert(14)
        for _ in 0..<120 where game.bike.angle > -0.4 { game.previous=ProcessInfo.processInfo.systemUptime-1/120;game.tick() }
        precondition(game.bike.isStoppie && game.bike.bestStoppie>0.5,"E must produce a physical front-wheel invertido")
        precondition(game.score.total>0,"A real invertido must score points")
        game.saveRun();let recordedStoppie=game.bike.bestStoppie;game.bestStoppie=0;game.loadRecords()
        precondition(game.bestStoppie>=recordedStoppie,"Invertido record must survive reloading preferences")
        game.garage();game.start()
        let drivingBar=game.bar.touchBar
        let auxiliary=NSWindow(contentRect:.zero,styleMask:[],backing:.buffered,defer:false)
        NotificationCenter.default.post(name:NSWindow.didResignKeyNotification,object:auxiliary)
        precondition(game.mode == .riding, "An auxiliary window must not pause the game")
         precondition(game.mode == .riding && sidebarItem.isCollapsed && inspectorItem.isCollapsed)
        game.keys.insert(126)
        for _ in 0..<150 { game.previous=ProcessInfo.processInfo.systemUptime-1/60; game.tick() }
        precondition(game.bike.speed>5 && game.bike.distance>5 && !game.bike.crashed)
        let pauseID=NSTouchBarItem.Identifier("com.scratch.wheelieride.touchbar.pause")
        let pauseControl=(drivingBar.item(forIdentifier:pauseID) as! NSCustomTouchBarItem).view as! NSButton
        pauseControl.performClick(nil); checkBar(.paused)
        let pausedBar=game.bar.touchBar
        precondition(window.makeFirstResponder(game.continueButton))
        checkBar(.paused)
        precondition(window.makeFirstResponder(game.retryButton))
        checkBar(.paused)
        precondition(game.bar.touchBar === pausedBar, "Native pause-button focus must preserve the context bar")
        let oldX=game.bike.x; game.tick(); precondition(game.bike.x==oldX && game.keys.isEmpty)
        let resumeControl=(pausedBar.item(forIdentifier:pauseID) as! NSCustomTouchBarItem).view as! NSButton
        resumeControl.performClick(nil)
        precondition(game.mode == .riding && window.firstResponder === game && game.bar.touchBar === drivingBar); checkBar(.riding)
        customize(); precondition(settings != nil && game.mode == .paused); checkBar(.blocked)
        game.start(); precondition(game.mode == .paused, "A sheet must block starting a run")
        game.pause(); precondition(game.mode == .paused, "A sheet must block resuming")
        game.garage(); precondition(game.mode == .paused, "A sheet must block garage navigation")
        closeSettings(); precondition(settings == nil && game.mode == .riding); checkBar(.riding)
        game.deactivate(); precondition(game.mode == .paused && game.touchHeld.isEmpty); checkBar(.paused)
        game.garage(); precondition(game.mode == .garage && game.bike.distance==0 && !sidebarItem.isCollapsed && !inspectorItem.isCollapsed)
        checkBar(.garage)
        game.mode = .result; game.syncState(); checkBar(.result)
        game.garage(); checkBar(.garage)
        game.start(); game.keys=[126,123]
        for _ in 0..<1200 where game.mode == .riding { game.previous=ProcessInfo.processInfo.systemUptime-1/60; game.tick() }
        precondition(game.mode == .crashing && game.ragdoll != nil, "A real over-rotation must detach the rider")
        for _ in 0..<150 { game.previous=ProcessInfo.processInfo.systemUptime-1/60; game.tick() }
        precondition(game.mode == .result && game.ragdoll != nil, "Crash dynamics must reach the result state")
        checkBar(.result); game.garage(); checkBar(.garage)
        if let domain=smokePreferences { UserDefaults.standard.removePersistentDomain(forName:domain) }
        game.bar.releaseAll(); print("App smoke: garage UI flow (wallet, locks, purchases, challenges, rival, ABS), race, tutorial, endless, tricks, full run rewards, acceleration, pause/resume, focus loss, settings sheet guards, Touch Bar contexts, native pause-button focus and detached crash dynamics passed.")
        NSApp.terminate(nil)
    }
}

let app=NSApplication.shared
app.setActivationPolicy(.regular)
let delegate=AppDelegate(); app.delegate=delegate
app.run()
