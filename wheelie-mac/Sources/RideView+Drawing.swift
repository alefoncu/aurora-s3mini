import Cocoa

/// Scene drawing: garage, ride, obstacles, rival, ghost and the rider.
extension RideView {
    /// The garage is drawn by the view itself; while riding, four child views take over (see `buildLayers`).
    override func draw(_ dirtyRect:NSRect) {
        if mode == .garage { drawGarage() }
    }
    func buildLayers() {
        backdropHost=RideLayerHost(content:backdrop.root)
        sceneView=RideDrawView(role:.scene); sceneView.game=self
        overlayHost=RideLayerHost(content:overlay.root)
        hudView=RideDrawView(role:.hud); hudView.game=self
        for view in [backdropHost!,sceneView!,overlayHost!,hudView!] { view.frame=bounds; addSubview(view) }
        updateLayerVisibility()
    }
    func updateLayerVisibility() {
        guard backdropHost != nil else { return }
        let riding = mode != .garage
        for view in [backdropHost!,sceneView!,overlayHost!,hudView!] as [NSView] { view.isHidden = !riding }
        if riding { invalidateLayers() }
    }
    /// The scene is laid out in logical points whose height is normally 720: the view scales to its height, so a wide window shows
    /// more road and a short one never cuts the bike off. The logical width stays within 900...1700 (the backdrop tiles cover that).
    /// Backdrop layers are built in coarse width steps so a live resize does not rebuild them on every pixel.
    var backdropWidth:Double { sceneWidth<=1280 ? 1280 : sceneWidth<=1500 ? 1500 : 1700 }
    func updateGeometry() {
        let w=max(1,bounds.width),h=max(1,bounds.height)
        var s=h/720
        if w/s>1700 { s=w/1700 } else if w/s<900 { s=w/900 }
        viewportScale=s; origin = .zero; sceneWidth=w/s; sceneHeight=h/s
        art.viewWidth=sceneWidth; art.viewHeight=sceneHeight; art.focusX=max(210,min(470,sceneWidth*0.29)); art.groundY=sceneHeight*0.636
    }
    /// Refresh the GPU layers (cheap: a few positions) and ask the two drawing views to redraw.
    func invalidateLayers() {
        guard backdropHost != nil, mode != .garage else { return }
        RideProfile.section("capas") {
            updateGeometry()
            let density=window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
            backdrop.configure(route:bike.route,night:night,width:backdropWidth,height:sceneHeight,backing:density)
            backdrop.update(camera:camX*RideScene.metresToPixels)
            overlay.configure(width:backdropWidth,height:sceneHeight)
            backdrop.setFog(weather.fog*0.6)
            overlay.setWeather(fog:weather.fog*0.2,flash:weather.flash*0.55)
            backdropHost.fit(scale:viewportScale); overlayHost.fit(scale:viewportScale)
        }
        sceneView.needsDisplay=true; hudView.needsDisplay=true
    }
    /// The world: snow, scenery, road, obstacles, rival, ghost, rider and weather (the backdrop is layers).
    func drawScene() {
        guard mode != .garage else { return }
        updateGeometry()
        NSGraphicsContext.saveGraphicsState(); let transform=NSAffineTransform(); transform.translateX(by:origin.x,yBy:origin.y); transform.scale(by:viewportScale); transform.concat()
        NSBezierPath(rect:NSRect(x:0,y:0,width:sceneWidth,height:sceneHeight)).addClip()
        art.snowfall(route:bike.route,time:animationTime)
        RideProfile.section("carretera y escenario") { art.scenery(cameraX:camX,cameraY:cameraY+presentationOffset,route:bike.route,night:night,limit:bike.endless ? .infinity : bike.finishDistance) }
        art.forkRoads(cameraX:camX,cameraY:cameraY+presentationOffset,route:bike.route,night:night)
        drawRide()
        NSGraphicsContext.restoreGraphicsState()
    }
    /// Scores, timers, banners and hints, above the screen-edge shading.
    func drawHUDLayer() {
        guard mode != .garage else { return }
        updateGeometry()
        NSGraphicsContext.saveGraphicsState(); let transform=NSAffineTransform(); transform.translateX(by:origin.x,yBy:origin.y); transform.scale(by:viewportScale); transform.concat()
        NSBezierPath(rect:NSRect(x:0,y:0,width:sceneWidth,height:sceneHeight)).addClip()
        RideProfile.section("HUD") { hud(); drawControls() }
        NSGraphicsContext.restoreGraphicsState()
    }
    /// The garage is a studio: a spotlight, a platform and the bike reflected in it, with its characteristics as bars.
    func drawGarage() {
        let w=bounds.width,h=bounds.height,geo=art.geometry(bike.kind),kind=bike.kind
        let studio=NSColor(hex:0x10141C),glow=NSColor(hex:0x9DB6E6)
        NSGradient(colors:[NSColor(hex:0x2C3446),NSColor(hex:0x161B26),studio],atLocations:[0,0.55,1],colorSpace:.deviceRGB)?.draw(in:bounds,angle:90)
        let floor=h*0.70,z=max(0.8,min(3.0,min((w-120)/(geo.front+80),(floor-150)/175)))
        let spot=NSPoint(x:w/2,y:floor-z*70)
        NSGradient(colors:[glow.withAlphaComponent(0.30),glow.withAlphaComponent(0)],atLocations:[0,1],colorSpace:.deviceRGB)?.draw(fromCenter:spot,radius:0,toCenter:spot,radius:max(w,h)*0.7,options:[])
        // Platform with a lit rim.
        let pw=geo.front*z+260,platform=NSBezierPath(ovalIn:NSRect(x:w/2-pw/2,y:floor-16,width:pw,height:62))
        NSGradient(colors:[NSColor(hex:0x3B4559),NSColor(hex:0x1A202C)],atLocations:[0,1],colorSpace:.deviceRGB)?.draw(in:platform,angle:90)
        glow.withAlphaComponent(0.5).setStroke(); platform.lineWidth=1.6; platform.stroke()
        let ring=NSBezierPath(ovalIn:NSRect(x:w/2-pw*0.42,y:floor-8,width:pw*0.84,height:46)); glow.withAlphaComponent(0.16).setStroke(); ring.lineWidth=1; ring.stroke()
        let rig=kind.rig,ppm=z*rig.drawingUnitsPerMetre,c=cos(bike.pitch),s=sin(bike.pitch)
        func local(_ wheel:RideVector)->RideVector { let d=wheel-bike.chassisPosition;return RideVector(c*d.x+s*d.y,-s*d.x+c*d.y) }
        let midpoint=(bike.rearWheelPosition.x+bike.frontWheelPosition.x)*0.5
        func drawBike() {
            art.wheelBlur=0
            art.motorcycle(x:w/2+(bike.chassisPosition.x-midpoint)*ppm,y:floor-bike.chassisPosition.y*ppm,scale:z,angle:bike.pitch,kind:kind,rotation:0,time:0,rearWheelLocal:local(bike.rearWheelPosition),frontWheelLocal:local(bike.frontWheelPosition),frontCompression:bike.frontCompression,rearCompression:bike.rearCompression)
        }
        // Reflection: the bike mirrored about the floor, faded into the platform.
        NSGraphicsContext.saveGraphicsState()
        platform.addClip(); NSBezierPath(rect:NSRect(x:0,y:floor,width:w,height:h)).addClip()
        let mirror=NSAffineTransform(); mirror.translateX(by:0,yBy:2*floor); mirror.scaleX(by:1,yBy:-1); mirror.concat()
        drawBike()
        NSGraphicsContext.restoreGraphicsState()
        NSGraphicsContext.saveGraphicsState()
        platform.addClip()
        NSGradient(colors:[NSColor(hex:0x232B3B,alpha:0.50),NSColor(hex:0x1A202C,alpha:0.96)],atLocations:[0,1],colorSpace:.deviceRGB)?.draw(in:NSRect(x:0,y:floor,width:w,height:70),angle:90)
        NSGraphicsContext.restoreGraphicsState()
        art.shadow(x:w/2,y:floor+2,width:geo.front*z+90,height:20,alpha:0.5)
        drawBike()
        // Title, then the characteristics as bars.
        let white=NSColor.white
        art.text(kind.title,32,26,30,white,.bold)
        art.text(kind.garageDetail,33,66,12,white.withAlphaComponent(0.62),.medium)
        let rigData=kind.rig,kmh=kind.topSpeed*3.6
        let stats:[(String,Double,String)]=[
            ("VELOCIDAD",kmh/300,"\(Int(kmh.rounded())) km/h"),
            ("ACELERACIÓN",kind.engineAcceleration/7.0,String(format:"%.1f m/s²",kind.engineAcceleration)),
            ("SUSPENSIÓN",(rigData.frontTravel+rigData.rearTravel)/0.57,kind == .bmx ? "rígida" : "\(Int(rigData.frontTravel*1000)) / \(Int(rigData.rearTravel*1000)) mm"),
            ("AGILIDAD",1-(rigData.sprungMass-82)/(290-82),"\(Int(rigData.sprungMass)) kg")]
        for (i,stat) in stats.enumerated() {
            let y=104+Double(i)*38
            art.text(stat.0,33,y,9,white.withAlphaComponent(0.5),.semibold)
            art.box(33,y+17,150,5,white.withAlphaComponent(0.12),2.5)
            let fraction=max(0.04,min(1,stat.1))
            art.box(33,y+17,150*fraction,5,NSColor(hex:0x5AC8FA),2.5)
            art.text(stat.2,194,y+10,11,white.withAlphaComponent(0.85),.medium,mono:true)
        }
        // Coins, and the two records on glass chips.
        art.box(w-170,24,138,30,white.withAlphaComponent(0.09),15)
        art.text("\(progress.wallet) monedas",w-101,31,12,white,.semibold,center:true,mono:true)
        for (i,item) in [("MEJOR CABALLITO",best),("RÉCORD DE RUTA",record)].enumerated() {
            let x=i == 0 ? 32.0 : w-182
            art.box(x-8,h-114,158,78,white.withAlphaComponent(0.07),12)
            art.text(item.0,x+4,h-104,10,white.withAlphaComponent(0.55),.semibold)
            art.text("\(Int(item.1)) m",x+4,h-84,25,white,.medium,mono:true)
        }
    }
    func drawRide() {
        let ppm=art.metresToPixels,rig=bike.kind.rig,camY=cameraY+presentationOffset
        RideProfile.section("obstáculos") { if obstaclesOn {
            for p in BikePhysics.window(BikePhysics.puddlePositions,from:camX-12,to:camX+sceneWidth/ppm+12) { art.puddle(center:Double(p),halfLength:BikePhysics.puddleHalfLength,cameraX:camX,cameraY:camY,route:bike.route) }
            for m in BikePhysics.window(obstacleList,from:camX-12,to:camX+sceneWidth/ppm+12) {
                let knocked=knockedCones.contains(m)
                switch BikePhysics.obstacleKind(at:m) {
                case .cone: art.cone(Double(m),cameraX:camX,cameraY:camY,route:bike.route,knocked:knocked)
                case .barrel: art.barrel(Double(m),cameraX:camX,cameraY:camY,route:bike.route,knocked:knocked)
                case .log: art.log(Double(m),cameraX:camX,cameraY:camY,route:bike.route,knocked:knocked)
                }
            }
        } }
        for p in dust {
            let x=art.focusX+(p.x-camX)*ppm,y=art.ground(p.x,at:camX,cameraY:camY,route:bike.route)-p.y*ppm
            let size=2+(1-p.life/p.maxLife)*10
            art.ellipse(x-size,y-size,size*2,size,NSColor(hex:bike.route==0 ? 0xCFD0C7 : bike.route==3 ? 0xFFFFFF : bike.route==4 ? 0xB8C0C8 : 0xD6BD91,alpha:(p.life/p.maxLife)*0.17))
        }
        RideProfile.section("rival") { for (index,run) in rivalRuns.enumerated() { let r=run.bike
            // Rivals far off screen are not drawn (about 12 m are visible).
            if abs(r.x-camX)>16 { continue }
            let c=cos(r.pitch),s=sin(r.pitch),rrig=r.kind.rig
            func localRival(_ point:RideVector)->RideVector { let d=point-r.chassisPosition; return RideVector(c*d.x+s*d.y,-s*d.x+c*d.y) }
            let savedBody=art.body,savedJacket=art.jacket
            art.body=Self.rivalPalette[index%Self.rivalPalette.count]; art.jacket=NSColor.systemRed
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current?.cgContext.setAlpha(0.8)
            art.wheelBlur=art.blur(speed:r.speed,radius:rrig.wheelRadius); art.motorcycle(x:art.focusX+(r.chassisPosition.x-camX)*ppm,y:art.groundY+camY-r.chassisPosition.y*ppm,scale:ppm/rrig.drawingUnitsPerMetre,angle:r.pitch,kind:r.kind,rotation:-r.rearWheelRotation,time:animationTime,showRider:!r.crashed,rearWheelLocal:localRival(r.rearWheelPosition),frontWheelLocal:localRival(r.frontWheelPosition),frontCompression:r.frontCompression,rearCompression:r.rearCompression,frontRotation:-r.frontWheelRotation,pedalPhase:r.pedalPhase)
            NSGraphicsContext.restoreGraphicsState()
            art.body=savedBody; art.jacket=savedJacket
        } }
        if ghostEnabled,let ghost=challenges.ghostFrame(at:elapsed) {
            let c=cos(ghost.pitch),s=sin(ghost.pitch)
            func localGhost(_ x:Double,_ y:Double)->RideVector {
                let dx=x-ghost.x,dy=y-ghost.y
                return RideVector(c*dx+s*dy,-s*dx+c*dy)
            }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current?.cgContext.setAlpha(0.28)
            art.wheelBlur=art.blur(speed:bike.speed,radius:rig.wheelRadius); art.motorcycle(x:art.focusX+(ghost.x-camX)*ppm,y:art.groundY+camY-ghost.y*ppm,
                scale:ppm/rig.drawingUnitsPerMetre,angle:ghost.pitch,kind:bike.kind,
                rotation:-ghost.wheelRotation,time:elapsed,showRider:true,
                rearWheelLocal:localGhost(ghost.rearWheelX,ghost.rearWheelY),
                frontWheelLocal:localGhost(ghost.frontWheelX,ghost.frontWheelY))
            NSGraphicsContext.restoreGraphicsState()
        }
        let ground=art.ground(bike.x,at:camX,cameraY:camY,route:bike.route,lane:bike.lane)
        art.shadow(x:art.focusX+rig.wheelbase*ppm*0.4,y:ground+4,width:rig.wheelbase*ppm+50,height:10,alpha:max(0.05,0.24-bike.height*0.045))
        let c=cos(bike.pitch),s=sin(bike.pitch)
        func local(_ point:RideVector)->RideVector { let d=point-bike.chassisPosition; return RideVector(c*d.x+s*d.y,-s*d.x+c*d.y) }
        let bodyX=art.focusX+(bike.chassisPosition.x-camX)*ppm,bodyY=art.groundY+camY-bike.chassisPosition.y*ppm
        if night { art.headlight(x:bodyX,y:bodyY,angle:bike.pitch,wheelbasePixels:rig.wheelbase*ppm) }
        // A 360 is shown as the bike turning about its vertical axis: a horizontal squash that
        // mirrors past 90 degrees, with fading afterimages either side to suggest the motion.
        func drawBike(yaw:Double,alpha:Double) {
            let scaleX=abs(cos(yaw))<0.18 ? 0.18*(cos(yaw)<0 ? -1 : 1) : cos(yaw)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current?.cgContext.setAlpha(alpha)
            if scaleX != 1 { let t=NSAffineTransform(); t.translateX(by:bodyX,yBy:0); t.scaleX(by:scaleX,yBy:1); t.translateX(by:-bodyX,yBy:0); t.concat() }
            art.wheelBlur=art.blur(speed:bike.speed,radius:rig.wheelRadius); art.motorcycle(x:bodyX,y:bodyY,scale:ppm/rig.drawingUnitsPerMetre,angle:bike.pitch,kind:bike.kind,rotation:-bike.rearWheelRotation,time:animationTime,lean:riderLean,stunt:held(.stunt),handsOff:riderHandsOff,superman:riderSuperman,showRider:ragdoll == nil,rearWheelLocal:local(bike.rearWheelPosition),frontWheelLocal:local(bike.frontWheelPosition),frontCompression:bike.frontCompression,rearCompression:bike.rearCompression,frontRotation:-bike.frontWheelRotation,pedalPhase:pedalPhase,riderLift:riderLift)
            NSGraphicsContext.restoreGraphicsState()
        }
        if bike.spinYaw != 0 {
            let direction=bike.spinYaw>0 ? 1.0 : -1.0
            drawBike(yaw:bike.spinYaw-0.55*direction,alpha:0.12); drawBike(yaw:bike.spinYaw-0.28*direction,alpha:0.22)
        }
        RideProfile.section("moto y piloto") { drawBike(yaw:bike.spinYaw,alpha:1) }
        if ragdoll != nil {
            NSGraphicsContext.saveGraphicsState(); let t=NSAffineTransform(); t.translateX(by:art.focusX-camX*ppm,yBy:art.groundY+camY); t.concat()
            if let companion=passengerRagdoll { art.drawRider(companion.displayPose,units:ppm,kind:bike.kind,passenger:true,detached:true) }
            if let ragdoll { art.drawRider(ragdoll.displayPose,units:ppm,kind:bike.kind,detached:true) }
            NSGraphicsContext.restoreGraphicsState()
        }
        RideProfile.section("lluvia") { art.weather(intensity:weather.rain,time:animationTime) }
    }
}
