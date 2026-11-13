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
            backdrop.update(camera:bike.x*RideScene.metresToPixels)
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
        RideProfile.section("carretera y escenario") { art.scenery(cameraX:bike.x,cameraY:cameraY+presentationOffset,route:bike.route,night:night,limit:bike.endless ? .infinity : bike.finishDistance) }
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
        art.wheelBlur=0; art.motorcycle(x:w/2+(bike.chassisPosition.x-midpoint)*ppm,y:floor-bike.chassisPosition.y*ppm,scale:z,angle:bike.pitch,kind:bike.kind,rotation:0,time:0,rearWheelLocal:local(bike.rearWheelPosition),frontWheelLocal:local(bike.frontWheelPosition),frontCompression:bike.frontCompression,rearCompression:bike.rearCompression)
        art.text("MEJOR CABALLITO",32,h-100,10,.secondaryLabelColor,.semibold)
        art.text("\(Int(best)) m",32,h-80,25,.labelColor,.medium,mono:true)
        art.text("RÉCORD DE RUTA",w-182,h-100,10,.secondaryLabelColor,.semibold)
        art.text("\(Int(record)) m",w-182,h-80,25,.labelColor,.medium,mono:true)
    }
    func drawRide() {
        let ppm=art.metresToPixels,rig=bike.kind.rig,camY=cameraY+presentationOffset
        RideProfile.section("obstáculos") { if obstaclesOn {
            for p in BikePhysics.window(BikePhysics.puddlePositions,from:bike.x-12,to:bike.x+sceneWidth/ppm+12) { art.puddle(center:Double(p),halfLength:BikePhysics.puddleHalfLength,cameraX:bike.x,cameraY:camY,route:bike.route) }
            for m in BikePhysics.window(obstacleList,from:bike.x-12,to:bike.x+sceneWidth/ppm+12) {
                let knocked=knockedCones.contains(m)
                switch BikePhysics.obstacleKind(at:m) {
                case .cone: art.cone(Double(m),cameraX:bike.x,cameraY:camY,route:bike.route,knocked:knocked)
                case .barrel: art.barrel(Double(m),cameraX:bike.x,cameraY:camY,route:bike.route,knocked:knocked)
                case .log: art.log(Double(m),cameraX:bike.x,cameraY:camY,route:bike.route,knocked:knocked)
                }
            }
        } }
        for p in dust {
            let x=art.focusX+(p.x-bike.x)*ppm,y=art.ground(p.x,at:bike.x,cameraY:camY,route:bike.route)-p.y*ppm
            let size=2+(1-p.life/p.maxLife)*10
            art.ellipse(x-size,y-size,size*2,size,NSColor(hex:bike.route==0 ? 0xCFD0C7 : bike.route==3 ? 0xFFFFFF : bike.route==4 ? 0xB8C0C8 : 0xD6BD91,alpha:(p.life/p.maxLife)*0.17))
        }
        RideProfile.section("rival") { for (index,run) in rivalRuns.enumerated() { let r=run.bike
            // Rivals far off screen are not drawn (about 12 m are visible).
            if abs(r.x-bike.x)>16 { continue }
            let c=cos(r.pitch),s=sin(r.pitch),rrig=r.kind.rig
            func localRival(_ point:RideVector)->RideVector { let d=point-r.chassisPosition; return RideVector(c*d.x+s*d.y,-s*d.x+c*d.y) }
            let savedBody=art.body,savedJacket=art.jacket
            art.body=Self.rivalPalette[index%Self.rivalPalette.count]; art.jacket=NSColor.systemRed
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current?.cgContext.setAlpha(0.8)
            art.wheelBlur=art.blur(speed:r.speed,radius:rrig.wheelRadius); art.motorcycle(x:art.focusX+(r.chassisPosition.x-bike.x)*ppm,y:art.groundY+camY-r.chassisPosition.y*ppm,scale:ppm/rrig.drawingUnitsPerMetre,angle:r.pitch,kind:r.kind,rotation:-r.rearWheelRotation,time:animationTime,showRider:!r.crashed,rearWheelLocal:localRival(r.rearWheelPosition),frontWheelLocal:localRival(r.frontWheelPosition),frontCompression:r.frontCompression,rearCompression:r.rearCompression,frontRotation:-r.frontWheelRotation,pedalPhase:r.pedalPhase)
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
            art.wheelBlur=art.blur(speed:bike.speed,radius:rig.wheelRadius); art.motorcycle(x:art.focusX+(ghost.x-bike.x)*ppm,y:art.groundY+camY-ghost.y*ppm,
                scale:ppm/rig.drawingUnitsPerMetre,angle:ghost.pitch,kind:bike.kind,
                rotation:-ghost.wheelRotation,time:elapsed,showRider:true,
                rearWheelLocal:localGhost(ghost.rearWheelX,ghost.rearWheelY),
                frontWheelLocal:localGhost(ghost.frontWheelX,ghost.frontWheelY))
            NSGraphicsContext.restoreGraphicsState()
        }
        let ground=art.ground(bike.x,at:bike.x,cameraY:camY,route:bike.route)
        art.shadow(x:art.focusX+rig.wheelbase*ppm*0.4,y:ground+4,width:rig.wheelbase*ppm+50,height:10,alpha:max(0.05,0.24-bike.height*0.045))
        let c=cos(bike.pitch),s=sin(bike.pitch)
        func local(_ point:RideVector)->RideVector { let d=point-bike.chassisPosition; return RideVector(c*d.x+s*d.y,-s*d.x+c*d.y) }
        let bodyX=art.focusX+(bike.chassisPosition.x-bike.x)*ppm,bodyY=art.groundY+camY-bike.chassisPosition.y*ppm
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
            NSGraphicsContext.saveGraphicsState(); let t=NSAffineTransform(); t.translateX(by:art.focusX-bike.x*ppm,yBy:art.groundY+camY); t.concat()
            if let companion=passengerRagdoll { art.drawRider(companion.pose,units:ppm,kind:bike.kind,passenger:true,detached:true) }
            if let ragdoll { art.drawRider(ragdoll.pose,units:ppm,kind:bike.kind,detached:true) }
            NSGraphicsContext.restoreGraphicsState()
        }
        RideProfile.section("lluvia") { art.weather(intensity:weather.rain,time:animationTime) }
    }
}
