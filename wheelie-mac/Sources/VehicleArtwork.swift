import Cocoa

/// Frame, wheels and suspension are separate pieces. Every axle below is supplied
/// by the simulation in chassis coordinates; the artwork never invents wheel travel.
/// Drawing units are screen points relative to the rear axle (x forward, y down); the
/// helpers named `vmQ`/`vmShape` take y *upwards* to keep the shapes readable.
extension RideRenderer {
    func drawVehicle(kind:BikeKind,rearAxle:NSPoint,frontAxle:NSPoint,
                     frontCompression:Double,rearCompression:Double,
                     rotationRear:Double,rotationFront:Double,pedalPhase:Double,time:Double) {
        let rig=kind.rig, u=rig.drawingUnitsPerMetre
        func pt(_ value:RideVector)->NSPoint { NSPoint(x:value.x*u,y:-value.y*u) }
        let pivot=pt(rig.swingPivot), fork=pt(rig.frontSuspensionMount), grip=pt(rig.grip)
        let radius=rig.wheelRadius*u
        let offroad=(kind == .motocross || kind == .trials || kind == .scrambler)
        let sporty=(kind == .sport || kind == .hyperbike)
        vmWheel(at:rearAxle,radius:radius,rotation:rotationRear,kind:kind,front:false)
        vmWheel(at:frontAxle,radius:radius,rotation:rotationFront,kind:kind,front:true)
        if kind == .bmx {
            vmBicycle(rig:rig,rear:rearAxle,front:frontAxle,pedalPhase:pedalPhase)
            return
        }
        // Far side: second swingarm leg, far fork leg and the chain run.
        vmSwingarm(pivot:pivot,axle:rearAxle,kind:kind,far:true)
        vmFarFork(top:fork,axle:frontAxle,offroad:offroad,upsideDown:sporty)
        if kind != .scooter && kind != .electric { vmChain(rear:rearAxle,crank:NSPoint(x:43,y:-8),rotation:rotationRear) }
        vmSwingarm(pivot:pivot,axle:rearAxle,kind:kind,far:false)
        let lower=vmMix(rearAxle,pivot,0.48)
        vmShock(top:pt(rig.rearSuspensionMount),bottom:lower,offroad:offroad,reservoir:(sporty || kind == .motocross),kind:kind)
        vmFrame(kind:kind,rig:rig,pivot:pivot,fork:fork)
        if kind != .scooter && kind != .electric { vmPowertrain(kind:kind) }
        switch kind {
        case .commuter: vmStreetBody(rig:rig)
        case .motocross: vmEnduroBody(rig:rig)
        case .sport: vmSportBody(rig:rig)
        case .hyperbike: vmHyperBody(rig:rig)
        case .scooter: vmScooterBody(rig:rig)
        case .scrambler: vmScramblerBody(rig:rig)
        case .trials: vmTrialsBody(rig:rig)
        case .cruiser: vmCruiserBody(rig:rig)
        case .electric: vmElectricBody(rig:rig)
        case .bmx: break
        }
        // The near fork leg, brake and mudguard move with the unsprung wheel assembly.
        vmNearFork(top:fork,axle:frontAxle,offroad:offroad,upsideDown:sporty,kind:kind)
        vmFender(axle:frontAxle,radius:radius,kind:kind,paint:body)
        vmBrake(front:frontAxle,rear:rearAxle,radius:radius,kind:kind,grip:grip,fork:fork,pivot:pivot)
        vmHandlebar(fork:fork,grip:grip,kind:kind)
        let peg=pt(rig.footPeg)
        vmMetalLink(NSPoint(x:peg.x-5,y:peg.y),NSPoint(x:peg.x+8,y:peg.y),width:3.0,dark:true)
        for i in 0..<5 { line(peg.x-2+Double(i)*1.6,peg.y-1.6,peg.x-2+Double(i)*1.6,peg.y+1.1,0.5,NSColor(hex:0xC5CBCD)) }
        vmBolt(pivot.x,pivot.y,r:2.2)
    }

    // MARK: Primitives
    func vmMix(_ a:NSPoint,_ b:NSPoint,_ t:Double)->NSPoint { NSPoint(x:a.x+(b.x-a.x)*t,y:a.y+(b.y-a.y)*t) }
    func vmQ(_ x:Double,_ y:Double)->NSPoint { NSPoint(x:x,y:-y) }
    func vmTone(_ c:NSColor,_ amount:Double)->NSColor {
        c.blended(withFraction:abs(amount),of:amount>=0 ? .white : .black) ?? c
    }
    func vmFill(_ path:NSBezierPath,colors:[NSColor],angle:Double=90,outline:Double=0.65) {
        NSGradient(colors:colors)?.draw(in:path,angle:angle)
        if outline>0 { NSColor(hex:0x17232B,alpha:0.9).setStroke(); path.lineWidth=outline; path.lineJoinStyle = .round; path.stroke() }
    }
    func vmRounded(_ rect:NSRect,radius:Double,colors:[NSColor],angle:Double=90) {
        vmFill(NSBezierPath(roundedRect:rect,xRadius:radius,yRadius:radius),colors:colors,angle:angle)
    }
    /// Closed (or open) Catmull-Rom spline through y-up points.
    func vmSpline(_ pts:[(Double,Double)],closed:Bool=true)->NSBezierPath {
        let p=pts.map { NSPoint(x:$0.0,y:-$0.1) },n=p.count,path=NSBezierPath()
        guard n>2 else { return path }
        path.move(to:p[0])
        for i in 0..<(closed ? n : n-1) {
            let p0=closed ? p[(i+n-1)%n] : p[max(0,i-1)],p1=p[i],p2=p[(i+1)%n],p3=closed ? p[(i+2)%n] : p[min(n-1,i+2)]
            path.curve(to:p2,controlPoint1:NSPoint(x:p1.x+(p2.x-p0.x)/6,y:p1.y+(p2.y-p0.y)/6),controlPoint2:NSPoint(x:p2.x-(p3.x-p1.x)/6,y:p2.y-(p3.y-p1.y)/6))
        }
        if closed { path.close() }
        return path
    }
    /// A polygon whose corners are softened with quadratic curves of the given radius: crisp bodywork without egg shapes.
    func vmRoundedPoly(_ pts:[(Double,Double)],radius r:Double)->NSBezierPath {
        let p=pts.map { NSPoint(x:$0.0,y:-$0.1) },n=p.count,path=NSBezierPath()
        guard n>2 else { return path }
        for i in 0..<n {
            let a=p[(i+n-1)%n],b=p[i],c=p[(i+1)%n]
            let l1=max(0.001,hypot(b.x-a.x,b.y-a.y)),l2=max(0.001,hypot(c.x-b.x,c.y-b.y))
            let r1=min(r,l1*0.45),r2=min(r,l2*0.45)
            let s0=NSPoint(x:b.x+(a.x-b.x)/l1*r1,y:b.y+(a.y-b.y)/l1*r1),e0=NSPoint(x:b.x+(c.x-b.x)/l2*r2,y:b.y+(c.y-b.y)/l2*r2)
            if i == 0 { path.move(to:s0) } else { path.line(to:s0) }
            path.curve(to:e0,controlPoint1:NSPoint(x:s0.x+(b.x-s0.x)*0.7,y:s0.y+(b.y-s0.y)*0.7),controlPoint2:NSPoint(x:e0.x+(b.x-e0.x)*0.7,y:e0.y+(b.y-e0.y)*0.7))
        }
        path.close(); return path
    }
    func vmPoly(_ pts:[(Double,Double)])->NSBezierPath {
        let p=NSBezierPath(); guard let f=pts.first else { return p }
        p.move(to:NSPoint(x:f.0,y:-f.1)); for q in pts.dropFirst() { p.line(to:NSPoint(x:q.0,y:-q.1)) }; p.close(); return p
    }
    /// A painted panel: gradient from highlight to shadow, a glossy sheen on its upper edge and an outline.
    @discardableResult
    func vmPanel(_ path:NSBezierPath,_ paint:NSColor,gloss:Double=0.34,outline:Double=0.8,angle:Double=82)->NSBezierPath {
        NSGradient(colors:[vmTone(paint,0.42),paint,vmTone(paint,-0.34)])?.draw(in:path,angle:angle)
        NSGraphicsContext.saveGraphicsState(); path.addClip()
        let b=path.bounds
        NSGradient(colors:[NSColor.white.withAlphaComponent(gloss),NSColor.white.withAlphaComponent(0)])?.draw(in:NSRect(x:b.minX,y:b.minY,width:b.width,height:b.height*0.38),angle:90)
        NSGraphicsContext.restoreGraphicsState()
        if outline>0 { NSColor(hex:0x17232B,alpha:0.9).setStroke(); path.lineWidth=outline; path.lineJoinStyle = .round; path.stroke() }
        return path
    }
    func vmClip(_ path:NSBezierPath,_ draw:()->Void) {
        NSGraphicsContext.saveGraphicsState(); path.addClip(); draw(); NSGraphicsContext.restoreGraphicsState()
    }
    func vmMetalLink(_ a:NSPoint,_ b:NSPoint,width:Double,dark:Bool) {
        let c1=NSColor(hex:dark ? 0x56646D : 0xF1F4F0), c2=NSColor(hex:dark ? 0x1F2A31 : 0x75858D)
        let dx=b.x-a.x,dy=b.y-a.y,d=max(0.001,hypot(dx,dy)),nx = -dy/d,ny=dx/d
        let p=NSBezierPath();p.move(to:NSPoint(x:a.x+nx*width/2,y:a.y+ny*width/2))
        p.line(to:NSPoint(x:b.x+nx*width/2,y:b.y+ny*width/2))
        p.curve(to:NSPoint(x:b.x-nx*width/2,y:b.y-ny*width/2),controlPoint1:NSPoint(x:b.x+dx/d*width/2+nx*width/2,y:b.y+dy/d*width/2+ny*width/2),controlPoint2:NSPoint(x:b.x+dx/d*width/2-nx*width/2,y:b.y+dy/d*width/2-ny*width/2))
        p.line(to:NSPoint(x:a.x-nx*width/2,y:a.y-ny*width/2))
        p.curve(to:NSPoint(x:a.x+nx*width/2,y:a.y+ny*width/2),controlPoint1:NSPoint(x:a.x-dx/d*width/2-nx*width/2,y:a.y-dy/d*width/2-ny*width/2),controlPoint2:NSPoint(x:a.x-dx/d*width/2+nx*width/2,y:a.y-dy/d*width/2+ny*width/2));p.close()
        vmFill(p,colors:[c1,c2],angle:atan2(dy,dx)*180/Double.pi+90,outline:0.65)
        line(a.x+nx*width*0.23,a.y+ny*width*0.23,b.x+nx*width*0.23,b.y+ny*width*0.23,0.55,NSColor.white.withAlphaComponent(dark ? 0.12 : 0.55))
    }
    /// A painted tube (frame member): dark edge, body-coloured core and a highlight.
    func vmTube(_ a:NSPoint,_ b:NSPoint,_ w:Double,_ c:NSColor) {
        line(a.x,a.y,b.x,b.y,w+1.5,NSColor(hex:0x17232B,alpha:0.92))
        line(a.x,a.y,b.x,b.y,w,vmTone(c,-0.1))
        line(a.x-0.3,a.y-w*0.2,b.x-0.3,b.y-w*0.2,max(0.5,w*0.3),vmTone(c,0.45))
    }
    func vmBolt(_ x:Double,_ y:Double,r:Double=1.3) {
        let disc=NSBezierPath(ovalIn:NSRect(x:x-r,y:y-r,width:r*2,height:r*2))
        vmFill(disc,colors:[NSColor(hex:0xE6EBE8),NSColor(hex:0x6D7B82)],outline:0.35)
        line(x-r*0.45,y+r*0.2,x+r*0.45,y-r*0.2,max(0.35,r*0.22),NSColor(hex:0x37454C))
    }
    func vmChrome(_ path:NSBezierPath,outline:Double=0.7) {
        vmFill(path,colors:[NSColor(hex:0xFAFCFA),NSColor(hex:0x9BA8AD),NSColor(hex:0x4A5961),NSColor(hex:0xC9D2D3)],angle:90,outline:outline)
    }

    // MARK: Wheels and brakes
    private func vmWheel(at axle:NSPoint,radius r:Double,rotation:Double,kind:BikeKind,front:Bool) {
        let x=axle.x,y=axle.y,cycle=kind == .bmx,offroad=(kind == .motocross || kind == .trials || kind == .scrambler)
        let cast=(kind == .sport || kind == .hyperbike || kind == .electric)
        let tyre=NSBezierPath(ovalIn:NSRect(x:x-r,y:y-r,width:r*2,height:r*2))
        vmFill(tyre,colors:[NSColor(hex:0x4A555D),NSColor(hex:0x10181E),NSColor(hex:0x2A343C)],angle:65,outline:0.7)
        // Sidewall: a lighter ring with lettering ticks, then the bead.
        let side=NSBezierPath(ovalIn:NSRect(x:x-(r-3.2),y:y-(r-3.2),width:(r-3.2)*2,height:(r-3.2)*2)); side.lineWidth=0.6; NSColor(hex:0x66727A,alpha:0.55).setStroke(); side.stroke()
        for i in 0..<14 { let a=Double(i)*2*Double.pi/14+rotation*0.0+0.3; line(x+cos(a)*(r-2.1),y+sin(a)*(r-2.1),x+cos(a+0.08)*(r-2.1),y+sin(a+0.08)*(r-2.1),0.9,NSColor(hex:0x56626A,alpha:0.6)) }
        let treadRadius=r-1.0
        let count=offroad ? 38 : 44
        for i in 0..<count {
            let a=Double(i)*2*Double.pi/Double(count)+rotation
            let inner=treadRadius-(offroad ? 1.6 : 0.5), outer=treadRadius+(offroad ? 1.3 : 0.2)
            line(x+cos(a)*inner,y+sin(a)*inner,x+cos(a+0.014)*outer,y+sin(a+0.014)*outer,offroad ? 1.8 : 0.5,NSColor(hex:offroad ? 0x151E24 : 0x6A767E,alpha:offroad ? 1 : 0.5))
        }
        let rimRadius=r-(cycle ? 3.7 : 5.8)
        let rim=NSBezierPath(ovalIn:NSRect(x:x-rimRadius,y:y-rimRadius,width:rimRadius*2,height:rimRadius*2))
        vmFill(rim,colors:[NSColor(hex:0xF0F2EE),NSColor(hex:0x7B8A92),NSColor(hex:0xC9D2D4)],angle:70,outline:0.45)
        circle(x,y,rimRadius-1.4,NSColor(hex:0x2C393F))
        if cast {
            // Five split spokes (three on the litre bike) sweeping from the hub to the rim.
            let n=kind == .hyperbike ? 3 : 5
            for i in 0..<n {
                let a=Double(i)*2*Double.pi/Double(n)+rotation
                let sweep=2*Double.pi/Double(n)
                let p=NSBezierPath(); p.move(to:NSPoint(x:x+cos(a)*4.5,y:y+sin(a)*4.5))
                p.curve(to:NSPoint(x:x+cos(a+0.3)*(rimRadius-1.5),y:y+sin(a+0.3)*(rimRadius-1.5)),controlPoint1:NSPoint(x:x+cos(a-0.25)*9,y:y+sin(a-0.25)*9),controlPoint2:NSPoint(x:x+cos(a+0.0)*15,y:y+sin(a+0.0)*15))
                p.line(to:NSPoint(x:x+cos(a+sweep*0.34)*(rimRadius-1.5),y:y+sin(a+sweep*0.34)*(rimRadius-1.5)))
                p.curve(to:NSPoint(x:x+cos(a+sweep*0.2)*4.5,y:y+sin(a+sweep*0.2)*4.5),controlPoint1:NSPoint(x:x+cos(a+sweep*0.3)*14,y:y+sin(a+sweep*0.3)*14),controlPoint2:NSPoint(x:x+cos(a+sweep*0.28)*8,y:y+sin(a+sweep*0.28)*8)); p.close()
                vmFill(p,colors:[NSColor(hex:0xCDD5D8),NSColor(hex:0x5D6B74)],angle:45,outline:0.4)
            }
        } else {
            // Laced wheel: crossed spoke pairs from a flanged hub.
            let spokeCount=cycle ? 28 : 32
            for i in 0..<spokeCount {
                let a=Double(i)*2*Double.pi/Double(spokeCount)+rotation, tw=(i%2==0) ? 0.55 : -0.55
                line(x+cos(a+tw)*3.4,y+sin(a+tw)*3.4,x+cos(a)*(rimRadius-1.5),y+sin(a)*(rimRadius-1.5),cycle ? 0.45 : 0.5,NSColor(hex:0xC2CFD1,alpha:0.92))
            }
        }
        if !cycle {
            // Drilled disc with a wavy outer edge.
            let discRadius=front ? rimRadius*0.66 : rimRadius*0.48
            let rotor=NSBezierPath(ovalIn:NSRect(x:x-discRadius,y:y-discRadius,width:discRadius*2,height:discRadius*2))
            vmFill(rotor,colors:[NSColor(hex:0xDCE1DB,alpha:0.95),NSColor(hex:0x88959A,alpha:0.9)],outline:0.5)
            circle(x,y,discRadius*0.62,NSColor(hex:0x3A484F))
            for i in 0..<18 {
                let a=Double(i)*2*Double.pi/18+rotation, rr=discRadius*0.84
                circle(x+cos(a)*rr,y+sin(a)*rr,0.62,NSColor(hex:0x33424A))
                if i%2==0 { circle(x+cos(a+0.17)*discRadius*0.74,y+sin(a+0.17)*discRadius*0.74,0.45,NSColor(hex:0x33424A)) }
            }
        }
        circle(x,y,cycle ? 3.4 : 4.8,NSColor(hex:0x4A5A62)); vmBolt(x,y,r:cycle ? 1.6 : 2.4)
        // Fixed specular arcs remain independent of the rotating spokes.
        let shine=NSBezierPath();shine.appendArc(withCenter:axle,radius:r-2.4,startAngle:208,endAngle:262,clockwise:false)
        shine.lineWidth=0.85;NSColor(hex:0xB3BDC1,alpha:0.5).setStroke();shine.stroke()
    }
    private func vmBrake(front:NSPoint,rear:NSPoint,radius:Double,kind:BikeKind,grip:NSPoint,fork:NSPoint,pivot:NSPoint) {
        let sporty=kind == .sport || kind == .hyperbike
        let gold=NSColor(hex:0xE4B551),dark=NSColor(hex:0x293238)
        // Front caliper, radially mounted on sport bikes.
        let cal=sporty ? NSPoint(x:front.x-radius*0.52,y:front.y-radius*0.52) : NSPoint(x:front.x-radius*0.47,y:front.y-radius*0.14)
        let cp=NSBezierPath(roundedRect:NSRect(x:cal.x-4,y:cal.y-4.5,width:8.5,height:9),xRadius:2,yRadius:2)
        vmFill(cp,colors:sporty ? [NSColor(hex:0xF5F6F2),NSColor(hex:0x9AA3A5)] : [NSColor(hex:0xB9BDB3),NSColor(hex:0x4B5559)],angle:60,outline:0.6)
        circle(cal.x-1.2,cal.y-1.6,1.1,dark); circle(cal.x+2.2,cal.y+1.4,1.1,dark)
        // Rear caliper on the swingarm.
        let rc=NSPoint(x:rear.x+radius*0.25,y:rear.y-radius*0.42)
        vmRounded(NSRect(x:rc.x-3.5,y:rc.y-3,width:7,height:6),radius:1.5,colors:[NSColor(hex:0xBFC4BA),NSColor(hex:0x4B5559)],angle:60)
        // Hydraulic line from the lever, with a small reservoir at the grip.
        let brakeLine=NSBezierPath(); brakeLine.move(to:grip)
        brakeLine.curve(to:cal,controlPoint1:NSPoint(x:grip.x+9,y:grip.y+16),controlPoint2:NSPoint(x:front.x-radius*0.9,y:front.y-radius-16))
        brakeLine.lineWidth=1.1; NSColor(hex:0x151D22).setStroke(); brakeLine.stroke()
        brakeLine.lineWidth=0.35; NSColor(hex:0x8C99A0,alpha:0.7).setStroke(); brakeLine.stroke()
        _=gold; _=fork; _=pivot
    }

    // MARK: Chassis pieces
    private func vmSwingarm(pivot:NSPoint,axle:NSPoint,kind:BikeKind,far:Bool) {
        let sporty=kind == .sport || kind == .hyperbike
        let dx=axle.x-pivot.x,dy=axle.y-pivot.y,l=max(0.001,hypot(dx,dy)),nx = -dy/l,ny=dx/l
        func at(_ t:Double,_ n:Double)->NSPoint { NSPoint(x:pivot.x+dx*t+nx*n,y:pivot.y+dy*t+ny*n) }
        let w0=sporty ? 6.2 : 4.6,w1=sporty ? 3.6 : 2.8
        let arm=NSBezierPath()
        arm.move(to:at(-0.05,-w0)); arm.line(to:at(1.0,-w1)); arm.line(to:at(1.04,w1*0.6)); arm.line(to:at(1.0,w1)); arm.line(to:at(-0.05,w0)); arm.close()
        if far { vmFill(arm,colors:[NSColor(hex:0x4A5961),NSColor(hex:0x1D272D)],angle:80,outline:0.6); return }
        vmFill(arm,colors:sporty ? [NSColor(hex:0xE1E6E4),NSColor(hex:0x717F87),NSColor(hex:0x3B4950)] : [NSColor(hex:0x66747C),NSColor(hex:0x242F36)],angle:80,outline:0.7)
        // Brace under the arm and the axle adjuster block with its tension bolt.
        line(at(0.22,w0*0.9).x,at(0.22,w0*0.9).y,at(0.62,w1*0.9).x,at(0.62,w1*0.9).y,1.4,NSColor(hex:0x2B363D,alpha:0.9))
        line(at(0.3,-w0*0.5).x,at(0.3,-w0*0.5).y,at(0.85,-w1*0.5).x,at(0.85,-w1*0.5).y,0.55,NSColor.white.withAlphaComponent(0.5))
        let ad=NSBezierPath(roundedRect:NSRect(x:axle.x-4.2,y:axle.y-3.8,width:8.4,height:7.6),xRadius:2.2,yRadius:2.2)
        vmFill(ad,colors:[NSColor(hex:0xA9B4B7),NSColor(hex:0x4D5C63)],angle:70,outline:0.55)
        vmBolt(axle.x,axle.y,r:1.7)
        vmBolt(pivot.x,pivot.y,r:2.2)
    }
    private func vmShock(top:NSPoint,bottom:NSPoint,offroad:Bool,reservoir:Bool,kind:BikeKind) {
        let dx=bottom.x-top.x,dy=bottom.y-top.y,len=max(0.001,hypot(dx,dy)),nx = -dy/len,ny=dx/len
        // Damper body and shaft, then the coil spring and an optional remote reservoir.
        vmMetalLink(top,bottom,width:3.6,dark:false)
        if reservoir {
            let a=vmMix(top,bottom,0.35),b=NSPoint(x:a.x+nx*7+dx/len*3,y:a.y+ny*7+dy/len*3)
            let tank=NSBezierPath(roundedRect:NSRect(x:min(a.x,b.x)+nx*6-2.2,y:min(a.y,b.y)+ny*6-4,width:4.4,height:9),xRadius:2,yRadius:2)
            vmFill(tank,colors:[NSColor(hex:0x2B353C),NSColor(hex:0x6B7A82)],angle:0,outline:0.5)
            line(a.x,a.y,a.x+nx*6,a.y+ny*6,1.0,NSColor(hex:0x151D22))
        }
        let start=vmMix(top,bottom,0.18),end=vmMix(top,bottom,0.86)
        let coil=NSBezierPath();coil.move(to:start)
        let turns=(kind == .cruiser || kind == .scooter) ? 9.0 : 11.0
        for i in 1...56 {
            let t=Double(i)/56,base=vmMix(start,end,t),wave=sin(t*Double.pi*2*turns)*3.7
            coil.line(to:NSPoint(x:base.x+nx*wave,y:base.y+ny*wave))
        }
        let spring = offroad ? NSColor(hex:0xE3BC58) : (kind == .sport || kind == .hyperbike) ? NSColor(hex:0xD94A34) : NSColor(hex:0xD2D9D6)
        coil.lineWidth=1.9;NSColor(hex:0x1F2B31).setStroke();coil.stroke();coil.lineWidth=1.1;spring.setStroke();coil.stroke()
        vmBolt(top.x,top.y,r:1.9); vmBolt(bottom.x,bottom.y,r:1.9)
    }
    private func vmFarFork(top:NSPoint,axle:NSPoint,offroad:Bool,upsideDown:Bool) {
        vmMetalLink(NSPoint(x:top.x+1.2,y:top.y+1),NSPoint(x:axle.x+1.2,y:axle.y+0.5),width:4.0,dark:true)
    }
    private func vmNearFork(top:NSPoint,axle:NSPoint,offroad:Bool,upsideDown:Bool,kind:BikeKind) {
        let dx=axle.x-top.x,dy=axle.y-top.y,length=max(0.001,hypot(dx,dy))
        let d=NSPoint(x:dx/length,y:dy/length)
        // Two tube sections keep their manufactured lengths; only their overlap changes with travel.
        let outerLength=offroad ? 47.0 : 36.0,innerLength=offroad ? 43.0 : 35.0
        let upperEnd=NSPoint(x:top.x+d.x*outerLength,y:top.y+d.y*outerLength)
        let chromeStart=NSPoint(x:axle.x-d.x*innerLength,y:axle.y-d.y*innerLength)
        if upsideDown {
            // Inverted fork: thick anodised sliders at the bottom, polished stanchions above.
            vmMetalLink(top,chromeStart,width:4.4,dark:false)
            vmMetalLink(NSPoint(x:axle.x-d.x*innerLength*0.9,y:axle.y-d.y*innerLength*0.9),axle,width:7.0,dark:true)
            line(axle.x-d.x*innerLength*0.85-0.8,axle.y-d.y*innerLength*0.85,axle.x-0.8,axle.y,1.2,NSColor(hex:0xE4B551,alpha:0.85))
        } else {
            vmMetalLink(chromeStart,axle,width:4.4,dark:false)
            vmMetalLink(top,upperEnd,width:6.6,dark:!offroad)
            if offroad {
                let p=NSBezierPath();p.move(to:top);p.line(to:upperEnd);p.lineWidth=5.0;p.lineCapStyle = .round;NSColor(hex:0xC1A862).setStroke();p.stroke()
                line(top.x-0.9,top.y,upperEnd.x-0.9,upperEnd.y,0.8,NSColor(hex:0xEDDB95))
            }
            // Rubber gaiter above the seal.
            let g0=NSPoint(x:upperEnd.x-d.x*2,y:upperEnd.y-d.y*2),g1=NSPoint(x:upperEnd.x+d.x*6,y:upperEnd.y+d.y*6)
            line(g0.x,g0.y,g1.x,g1.y,7.2,NSColor(hex:0x161E24)); for i in 0..<3 { let t=Double(i)/2,c=vmMix(g0,g1,t); line(c.x-3,c.y,c.x+3,c.y,0.5,NSColor(hex:0x3B484F)) }
        }
        // Upper clamp (triple tree) and the lower clamp.
        vmMetalLink(NSPoint(x:top.x-d.x*1.8-1.6,y:top.y-d.y*1.8),NSPoint(x:top.x+d.x*1.8+1.6,y:top.y+d.y*1.8),width:8.2,dark:true)
        let low=NSPoint(x:top.x+d.x*10,y:top.y+d.y*10)
        vmMetalLink(NSPoint(x:low.x-1.5,y:low.y),NSPoint(x:low.x+1.5,y:low.y),width:7.4,dark:true)
        vmBolt(axle.x,axle.y,r:2.2); vmBolt(top.x,top.y,r:1.8)
        // Fork cap on top and the front axle nut.
        vmRounded(NSRect(x:top.x-2.2,y:top.y-4.4,width:4.4,height:3),radius:1,colors:[NSColor(hex:0xDADFDA),NSColor(hex:0x6D7B82)])
        _=kind
    }
    private func vmFender(axle:NSPoint,radius:Double,kind:BikeKind,paint:NSColor) {
        let offroad=(kind == .motocross || kind == .trials || kind == .scrambler)
        let low = (kind == .sport || kind == .hyperbike)
        let top=axle.y-radius
        let p:NSBezierPath
        if offroad {
            p=NSBezierPath()
            p.move(to:NSPoint(x:axle.x-19,y:top-8.5))
            p.curve(to:NSPoint(x:axle.x+22,y:top-5),controlPoint1:NSPoint(x:axle.x-4,y:top-16),controlPoint2:NSPoint(x:axle.x+14,y:top-11))
            p.line(to:NSPoint(x:axle.x+26,y:top-2));p.curve(to:NSPoint(x:axle.x-18,y:top-4.5),controlPoint1:NSPoint(x:axle.x+8,y:top-4.5),controlPoint2:NSPoint(x:axle.x-6,y:top-7.5)); p.close()
        } else {
            let a=low ? 2.0 : 0.0
            p=NSBezierPath()
            p.move(to:NSPoint(x:axle.x-20,y:top+3.5+a)); p.curve(to:NSPoint(x:axle.x+19,y:top+3+a),controlPoint1:NSPoint(x:axle.x-8,y:top-7+a),controlPoint2:NSPoint(x:axle.x+8,y:top-7+a))
            p.line(to:NSPoint(x:axle.x+18,y:top+6.5+a)); p.curve(to:NSPoint(x:axle.x-19,y:top+7+a),controlPoint1:NSPoint(x:axle.x+5,y:top-1+a),controlPoint2:NSPoint(x:axle.x-6,y:top-1+a)); p.close()
        }
        vmPanel(p,paint,gloss:0.3,outline:0.75)
    }
    private func vmChain(rear:NSPoint,crank:NSPoint,rotation:Double) {
        // Front sprocket, rear sprocket and the chain run between them.
        let rs:Double=9.4
        let p=NSBezierPath();p.move(to:NSPoint(x:rear.x,y:rear.y-rs));p.line(to:NSPoint(x:crank.x,y:crank.y-4.6));p.curve(to:NSPoint(x:crank.x,y:crank.y+4.6),controlPoint1:NSPoint(x:crank.x+6,y:crank.y-4.6),controlPoint2:NSPoint(x:crank.x+6,y:crank.y+4.6))
        p.line(to:NSPoint(x:rear.x,y:rear.y+rs));p.curve(to:NSPoint(x:rear.x,y:rear.y-rs),controlPoint1:NSPoint(x:rear.x-rs,y:rear.y+rs),controlPoint2:NSPoint(x:rear.x-rs,y:rear.y-rs));p.close()
        p.lineWidth=1.5;NSColor(hex:0x1E292E).setStroke();p.stroke();p.lineWidth=0.55;NSColor(hex:0xC9B97A).setStroke();p.stroke()
        // Rear sprocket with its bolts and teeth.
        circle(rear.x,rear.y,rs,NSColor(hex:0x8E9BA0,alpha:0.95)); circle(rear.x,rear.y,rs-2.6,NSColor(hex:0x364349))
        for i in 0..<24 { let a=Double(i)*Double.pi/12+rotation; line(rear.x+cos(a)*(rs-0.4),rear.y+sin(a)*(rs-0.4),rear.x+cos(a)*(rs+0.9),rear.y+sin(a)*(rs+0.9),0.9,NSColor(hex:0x8E9BA0)) }
        for i in 0..<5 { let a=Double(i)*Double.pi*2/5+rotation; circle(rear.x+cos(a)*(rs-4.4),rear.y+sin(a)*(rs-4.4),0.7,NSColor(hex:0xD2D7D1)) }
        circle(crank.x,crank.y,5.2,NSColor(hex:0xAAB4B7));circle(crank.x,crank.y,3.6,NSColor(hex:0x394950))
        for i in 0..<9 { let a=Double(i)*Double.pi*2/9+rotation; circle(crank.x+cos(a)*4.6,crank.y+sin(a)*4.6,0.5,NSColor(hex:0xD2D7D1)) }
    }
    /// The visible frame, per kind: trellis, twin-spar, cradle or backbone.
    private func vmFrame(kind:BikeKind,rig:VehicleRig,pivot:NSPoint,fork:NSPoint) {
        let steel=NSColor(hex:0x2D363C),alu=NSColor(hex:0xB9C0BF)
        let head=NSPoint(x:fork.x-1,y:fork.y-1)
        switch kind {
        case .commuter,.scrambler,.cruiser:
            // Double-cradle steel frame: top tube, down tube, engine cradle and seat rails.
            vmTube(head,vmQ(36,rig.seat.y*rig.drawingUnitsPerMetre-4),3.6,steel)
            vmTube(head,vmQ(46,14),3.6,steel)
            vmTube(vmQ(46,14),vmQ(22,12),3.2,steel); vmTube(vmQ(22,12),pivot,3.0,steel)
            vmTube(vmQ(36,rig.seat.y*rig.drawingUnitsPerMetre-4),vmQ(-8,rig.seat.y*rig.drawingUnitsPerMetre+6),2.8,steel)
            vmTube(pivot,vmQ(6,rig.seat.y*rig.drawingUnitsPerMetre+2),2.6,steel)
        case .sport,.hyperbike:
            // Aluminium twin-spar: two deep beams from the steering head to the swingarm pivot.
            let spar=NSBezierPath(); spar.move(to:head); spar.curve(to:vmQ(42,20),controlPoint1:vmQ(64,60),controlPoint2:vmQ(46,44)); spar.line(to:NSPoint(x:pivot.x,y:pivot.y+3)); spar.line(to:NSPoint(x:pivot.x-6,y:pivot.y-4)); spar.curve(to:NSPoint(x:head.x-4,y:head.y+4),controlPoint1:vmQ(40,44),controlPoint2:vmQ(60,54)); spar.close()
            vmFill(spar,colors:[vmTone(alu,0.3),alu,NSColor(hex:0x6D7B82)],angle:60,outline:0.8)
            vmTube(vmQ(24,rig.seat.y*rig.drawingUnitsPerMetre-6),vmQ(-6,rig.seat.y*rig.drawingUnitsPerMetre+2),2.8,alu)
        case .motocross,.trials,.electric:
            vmTube(head,vmQ(40,rig.seat.y*rig.drawingUnitsPerMetre-6),4.0,steel)
            vmTube(head,vmQ(48,20),3.8,steel); vmTube(vmQ(48,20),vmQ(30,8),3.4,steel); vmTube(vmQ(30,8),pivot,3.0,steel)
            vmTube(vmQ(40,rig.seat.y*rig.drawingUnitsPerMetre-6),vmQ(-10,rig.seat.y*rig.drawingUnitsPerMetre-2),3.0,steel)
        case .scooter,.bmx: break
        }
        // Steering head bearing cup.
        vmRounded(NSRect(x:head.x-3.2,y:head.y-3,width:6.4,height:6),radius:2,colors:[NSColor(hex:0xBFC6C5),NSColor(hex:0x5A6970)])
    }

    // MARK: Powertrains
    private func vmFins(_ rect:NSRect,count:Int,angle:Double,about c:NSPoint) {
        let t=NSAffineTransform(); t.translateX(by:c.x,yBy:c.y); t.rotate(byDegrees:angle); t.translateX(by:-c.x,yBy:-c.y)
        NSGraphicsContext.saveGraphicsState(); t.concat()
        for i in 0..<count {
            let y=rect.minY+rect.height*(Double(i)+0.5)/Double(count)
            line(rect.minX-0.8,y,rect.maxX+0.8,y,rect.height/Double(count)*0.55,NSColor(hex:0x687880))
            line(rect.minX-0.8,y-0.7,rect.maxX+0.8,y-0.7,0.4,NSColor(hex:0xD7DDD9,alpha:0.7))
        }
        NSGraphicsContext.restoreGraphicsState()
    }
    private func vmCylinder(base:NSPoint,width:Double,height:Double,angle:Double,fins:Int,headColor:NSColor) {
        NSGraphicsContext.saveGraphicsState()
        let t=NSAffineTransform(); t.translateX(by:base.x,yBy:base.y); t.rotate(byDegrees:angle); t.concat()
        vmRounded(NSRect(x:-width/2,y:-height,width:width,height:height),radius:1.2,colors:[NSColor(hex:0x9AA6A8),NSColor(hex:0x3C4A52),NSColor(hex:0x6B7B83)],angle:0)
        for i in 0..<fins {
            let y = -height+height*(Double(i)+0.5)/Double(fins+1)
            line(-width/2-0.9,y,width/2+0.9,y,height/Double(fins+1)*0.5,NSColor(hex:0x5F6F77)); line(-width/2-0.9,y-0.6,width/2+0.9,y-0.6,0.4,NSColor(hex:0xDCE2DE,alpha:0.7))
        }
        let head=NSRect(x:-width/2-1.4,y:-height-7.5,width:width+2.8,height:8)
        vmRounded(head,radius:2,colors:[vmTone(headColor,0.35),headColor,vmTone(headColor,-0.45)],angle:90)
        for i in 0..<4 { let x=head.minX+3+Double(i)*(head.width-6)/3; vmBolt(x,head.minY+4,r:0.75) }
        NSGraphicsContext.restoreGraphicsState()
    }
    func vmRadiator(rect:NSRect,angle:Double,about c:NSPoint,hoses:Bool) {
        NSGraphicsContext.saveGraphicsState()
        let t=NSAffineTransform(); t.translateX(by:c.x,yBy:c.y); t.rotate(byDegrees:angle); t.translateX(by:-c.x,yBy:-c.y); t.concat()
        vmRounded(rect,radius:1.8,colors:[NSColor(hex:0x4C5961),NSColor(hex:0x1B252B)],angle:0)
        var x=rect.minX+1.4; while x<rect.maxX-1 { line(x,rect.minY+1.2,x,rect.maxY-1.2,0.5,NSColor(hex:0xB5BFC1,alpha:0.7)); x+=1.7 }
        var y=rect.minY+2.5; while y<rect.maxY-1 { line(rect.minX+1,y,rect.maxX-1,y,0.35,NSColor(hex:0x080D10,alpha:0.5)); y+=2.2 }
        NSGraphicsContext.restoreGraphicsState()
        if hoses {
            let h=NSBezierPath(); h.move(to:NSPoint(x:c.x,y:rect.minY+1)); h.curve(to:NSPoint(x:c.x-16,y:rect.minY-5),controlPoint1:NSPoint(x:c.x-4,y:rect.minY-6),controlPoint2:NSPoint(x:c.x-9,y:rect.minY-9))
            h.lineWidth=2.4; NSColor(hex:0x12181C).setStroke(); h.stroke(); h.lineWidth=0.6; NSColor(hex:0x4C5961).setStroke(); h.stroke()
        }
    }
    private func vmCase(_ pts:[(Double,Double)],_ outline:Double=0.85) {
        vmFill(vmSpline(pts),colors:[NSColor(hex:0xA1ACAE),NSColor(hex:0x3C4A52),NSColor(hex:0x687A82)],angle:62,outline:outline)
    }
    func vmClutchCover(_ c:NSPoint,r:Double) {
        vmFill(NSBezierPath(ovalIn:NSRect(x:c.x-r,y:c.y-r,width:r*2,height:r*2)),colors:[NSColor(hex:0xB9C3C3),NSColor(hex:0x4C5B63)],angle:60,outline:0.75)
        vmFill(NSBezierPath(ovalIn:NSRect(x:c.x-r*0.55,y:c.y-r*0.55,width:r*1.1,height:r*1.1)),colors:[NSColor(hex:0x56666E),NSColor(hex:0x8C9AA0)],angle:60,outline:0.4)
        for i in 0..<6 { let a=Double(i)*Double.pi/3; vmBolt(c.x+cos(a)*(r*0.8),c.y+sin(a)*(r*0.8),r:0.7) }
    }
    /// Engine, cooling and exhaust, drawn between the frame and the bodywork.
    private func vmPowertrain(kind:BikeKind) {
        let steel=NSColor(hex:0x151D22)
        switch kind {
        case .sport,.hyperbike:
            // Inline four: tall tilted block, black valve cover, four headers merging into a belly collector.
            vmRadiator(rect:NSRect(x:78,y:-37,width:9,height:26),angle:-8,about:NSPoint(x:82,y:-24),hoses:true)
            vmCase([(37,9),(38,24),(52,30),(70,26),(74,12),(60,4),(46,4)])
            vmCylinder(base:vmQ(56,27),width:24,height:20,angle:24,fins:5,headColor:NSColor(hex:0x2B353B))
            vmClutchCover(vmQ(44,17),r:8.5)
            // Headers sweep from the head down and back to the collector.
            for i in 0..<4 {
                let o=Double(i)*2.3
                let h=NSBezierPath(); h.move(to:vmQ(70+o*0.2,44-o)); h.curve(to:vmQ(66,10+o*0.4),controlPoint1:vmQ(84,42-o),controlPoint2:vmQ(80,18+o*0.4)); h.curve(to:vmQ(40,6),controlPoint1:vmQ(56,6),controlPoint2:vmQ(48,4))
                h.lineWidth=2.6; NSColor(hex:0x20292E).setStroke(); h.stroke(); h.lineWidth=1.5; NSColor(hex:i%2==0 ? 0xC7CCC5 : 0xAEB6B2).setStroke(); h.stroke()
            }
            // Belly collector and short silencer (titanium can with a carbon end cap).
            let can=vmSpline([(40,2),(20,7),(2,17),(-1,23),(6,26),(26,17),(46,10)])
            vmFill(can,colors:[NSColor(hex:0xE9ECE6),NSColor(hex:0x707D83),NSColor(hex:0xB6BEBD)],angle:75,outline:0.8)
            let cap=vmSpline([(-2,17),(-5,22),(1,27),(5,24)]); vmFill(cap,colors:[NSColor(hex:0x3C4045),NSColor(hex:0x15191C)],angle:60,outline:0.6)
            line(36,-5,4,-22,0.7,NSColor.white.withAlphaComponent(0.55))
        case .motocross,.trials:
            // Single, liquid-cooled; twin radiators, expansion-chamber pipe over the engine.
            vmCase([(36,9),(37,22),(50,27),(63,22),(64,11),(52,5),(42,5)])
            vmCylinder(base:vmQ(52,25),width:17,height:15,angle:14,fins:0,headColor:NSColor(hex:0x2E3A40))
            vmClutchCover(vmQ(44,16),r:7.4)
            vmRadiator(rect:NSRect(x:62,y:-45,width:7,height:24),angle:-16,about:NSPoint(x:66,y:-33),hoses:true)
            let pipe=NSBezierPath(); pipe.move(to:vmQ(64,40)); pipe.curve(to:vmQ(56,11),controlPoint1:vmQ(80,38),controlPoint2:vmQ(76,14)); pipe.curve(to:vmQ(24,24),controlPoint1:vmQ(40,5),controlPoint2:vmQ(28,12)); pipe.curve(to:vmQ(10,46),controlPoint1:vmQ(14,32),controlPoint2:vmQ(14,40))
            pipe.lineWidth=5; pipe.lineCapStyle = .round; steel.setStroke(); pipe.stroke(); pipe.lineWidth=3.3; NSColor(hex:0xC4C8C0).setStroke(); pipe.stroke(); pipe.lineWidth=0.8; NSColor.white.withAlphaComponent(0.6).setStroke(); pipe.stroke()
            // Silencer.
            let sil=vmSpline([(-16,38),(0,43),(22,47),(26,41),(4,35)])
            vmFill(sil,colors:[NSColor(hex:0xE7EAE4),NSColor(hex:0x6D7B81),NSColor(hex:0xB1B8B6)],angle:80,outline:0.8)
            vmRounded(NSRect(x:-19,y:-43,width:5,height:7),radius:1.5,colors:[NSColor(hex:0x33393D),NSColor(hex:0x15191C)],angle:0)
        case .cruiser:
            // 45° V-twin: two finned cylinders, chrome pushrod tubes and a round air cleaner.
            vmCase([(30,8),(32,22),(48,28),(64,22),(66,8),(50,3)])
            vmCylinder(base:vmQ(46,24),width:15,height:19,angle:-38,fins:6,headColor:NSColor(hex:0x2B353B))
            vmCylinder(base:vmQ(50,24),width:15,height:19,angle:32,fins:6,headColor:NSColor(hex:0x2B353B))
            vmClutchCover(vmQ(40,13),r:8.2)
            vmChrome(NSBezierPath(ovalIn:NSRect(x:58,y:-38,width:16,height:16)))
            vmFill(NSBezierPath(ovalIn:NSRect(x:61,y:-35,width:10,height:10)),colors:[NSColor(hex:0x6E7C84),NSColor(hex:0xC4CDCE)],outline:0.4)
            // Staggered drag pipes.
            for (i,y) in [8.0,15.0].enumerated() {
                let pp=NSBezierPath(); pp.move(to:vmQ(70-Double(i)*14,26-Double(i)*2)); pp.curve(to:vmQ(60,y),controlPoint1:vmQ(80,20),controlPoint2:vmQ(72,y)); pp.line(to:vmQ(-12,y+2))
                pp.lineWidth=5.6; pp.lineCapStyle = .round; steel.setStroke(); pp.stroke(); pp.lineWidth=4.1; NSColor(hex:0xB9C3C5).setStroke(); pp.stroke(); pp.lineWidth=1.2; NSColor.white.setStroke(); pp.stroke()
            }
        default:
            // Air-cooled single: finned barrel, valve cover, clutch cover and a chrome muffler.
            vmCase([(34,9),(35,24),(49,29),(62,24),(64,11),(52,5),(40,5)])
            vmCylinder(base:vmQ(50,27),width:16,height:19,angle:(kind == .scrambler ? 8 : 16),fins:7,headColor:NSColor(hex:0x2B353B))
            vmClutchCover(vmQ(42,16),r:8.0)
            let pipe=NSBezierPath(); pipe.move(to:vmQ(62,48)); pipe.curve(to:vmQ(66,12),controlPoint1:vmQ(78,46),controlPoint2:vmQ(76,14)); pipe.curve(to:vmQ(24,13),controlPoint1:vmQ(60,4),controlPoint2:vmQ(38,8))
            pipe.lineWidth=4.6; pipe.lineCapStyle = .round; steel.setStroke(); pipe.stroke(); pipe.lineWidth=3.0; NSColor(hex:0xC0C6BE).setStroke(); pipe.stroke(); pipe.lineWidth=0.7; NSColor.white.withAlphaComponent(0.65).setStroke(); pipe.stroke()
            let ms=vmSpline([(-4,12),(2,20),(26,22),(30,13),(18,8)])
            if kind == .scrambler {
                // Upswept pipe with a perforated heat shield along the right side.
                let up=vmSpline([(-14,40),(2,32),(30,18),(34,11),(30,10),(0,25),(-16,34)])
                vmChrome(up)
                for i in 0..<7 { circle(30-Double(i)*7,-(16+Double(i)*3.1),0.75,NSColor(hex:0x2C3B3F)) }
            } else { vmChrome(ms); line(0,-20,26,-20,0.6,NSColor.white.withAlphaComponent(0.8)) }
            vmFill(NSBezierPath(ovalIn:NSRect(x:-6,y:-17,width:6,height:6)),colors:[NSColor(hex:0x20292E),NSColor(hex:0x5C6A72)],outline:0.5)
        }
        // Shift lever and the sparking-plug wire.
        vmMetalLink(vmQ(34,6),vmQ(28,7),width:1.6,dark:true)
    }
    private func vmHandlebar(fork:NSPoint,grip:NSPoint,kind:BikeKind) {
        let sporty=kind == .sport || kind == .hyperbike
        let wide=kind == .motocross || kind == .trials
        let top=NSPoint(x:fork.x+1,y:fork.y-6)
        if sporty {
            // Low clip-on bars hanging under the top clamp.
            vmMetalLink(NSPoint(x:fork.x+4,y:fork.y+2),grip,width:3.0,dark:true)
        } else if wide {
            vmMetalLink(fork,top,width:3.6,dark:false); vmMetalLink(top,grip,width:2.8,dark:false)
            vmMetalLink(NSPoint(x:top.x-1,y:top.y-4),NSPoint(x:grip.x-4,y:grip.y-3),width:2.0,dark:false)   // cross-brace
            // Hand guard.
            let hg=NSBezierPath(); hg.move(to:NSPoint(x:grip.x-6,y:grip.y-4)); hg.curve(to:NSPoint(x:grip.x+9,y:grip.y-3),controlPoint1:NSPoint(x:grip.x-3,y:grip.y-10),controlPoint2:NSPoint(x:grip.x+8,y:grip.y-9))
            hg.lineWidth=2.4; hg.lineCapStyle = .round; NSColor(hex:0x1B242A).setStroke(); hg.stroke()
        } else {
            let rise = kind == .cruiser ? 12.0 : 7.0
            let mid=NSPoint(x:fork.x+1,y:fork.y-rise)
            vmMetalLink(fork,mid,width:3.3,dark:false); vmMetalLink(mid,grip,width:2.7,dark:false)
        }
        // Black grip, brake lever, throttle housing and a mirror on a stalk.
        let lever=NSBezierPath();lever.move(to:NSPoint(x:grip.x+3,y:grip.y-1));lever.curve(to:NSPoint(x:grip.x+9,y:grip.y-5.5),controlPoint1:NSPoint(x:grip.x+9,y:grip.y-1),controlPoint2:NSPoint(x:grip.x+10,y:grip.y-3.5));lever.lineWidth=1.0;NSColor(hex:0xC7D0D1).setStroke();lever.stroke()
        vmRounded(NSRect(x:grip.x-1.5,y:grip.y-5.4,width:5.2,height:3.5),radius:1,colors:[NSColor(hex:0x3C464D),NSColor(hex:0x151D22)])
        if !wide && kind != .scooter && kind != .hyperbike {
            let m0=NSPoint(x:grip.x-1,y:grip.y-5),m1=NSPoint(x:grip.x-5,y:grip.y-(sporty ? 14 : 18))
            vmMetalLink(m0,m1,width:1.0,dark:true)
            let mirror=NSBezierPath(ovalIn:NSRect(x:m1.x-6,y:m1.y-3.6,width:11,height:7)); vmFill(mirror,colors:[NSColor(hex:0x253038),NSColor(hex:0x90A2AA)],angle:20,outline:0.55)
            line(m1.x-3,m1.y-1.6,m1.x+1,m1.y-2.2,0.6,NSColor.white.withAlphaComponent(0.55))
        }
    }
    func vmSeat(rig:VehicleRig,kind:BikeKind,length:Double?=nil) {
        let x=rig.seat.x*rig.drawingUnitsPerMetre,y = -rig.seat.y*rig.drawingUnitsPerMetre
        let off=(kind == .motocross || kind == .trials || kind == .scrambler)
        let back = off ? -13.0 : (kind == .cruiser ? -3.0 : -6.0)
        let p=NSBezierPath();p.move(to:NSPoint(x:back,y:y))
        p.curve(to:NSPoint(x:x+(length ?? 20),y:y+1.5),controlPoint1:NSPoint(x:7,y:y-3.5),controlPoint2:NSPoint(x:x+8,y:y-1.2))
        p.line(to:NSPoint(x:x+(length ?? 20)-1,y:y+6.5));p.curve(to:NSPoint(x:back,y:y+6),controlPoint1:NSPoint(x:x+22,y:y+7.5),controlPoint2:NSPoint(x:5,y:y+6.5));p.close()
        vmFill(p,colors:[NSColor(hex:0x5C6872),NSColor(hex:0x151F26)],angle:85,outline:0.7)
        line(back+3,y+0.9,x+12,y+1.8,0.55,NSColor(hex:0x93A0A8,alpha:0.75))
        for i in 0..<7 { let xx=back+4+Double(i)*5.5;line(xx,y+4.2,xx+2,y+4.5,0.45,NSColor(hex:0x818A90,alpha:0.5)) }
    }
    private func vmBicycle(rig:VehicleRig,rear:NSPoint,front:NSPoint,pedalPhase:Double) {
        let u=rig.drawingUnitsPerMetre, seat=NSPoint(x:rig.seat.x*u,y:-rig.seat.y*u),head=NSPoint(x:rig.frontSuspensionMount.x*u,y:-rig.frontSuspensionMount.y*u),grip=NSPoint(x:rig.grip.x*u,y:-rig.grip.y*u),crank=NSPoint(x:rig.crank.x*u,y:-rig.crank.y*u)
        func frameTube(_ a:NSPoint,_ b:NSPoint,_ w:Double) { vmTube(a,b,w,body) }
        vmChain(rear:rear,crank:crank,rotation:pedalPhase)
        // Gusset plates, chainstays and a stout BMX frame.
        frameTube(rear,seat,3.0);frameTube(rear,crank,3.2);frameTube(seat,crank,3.8)
        frameTube(seat,head,4.0);frameTube(head,crank,4.2)
        let top=NSPoint(x:(seat.x+head.x)/2,y:(seat.y+head.y)/2); frameTube(NSPoint(x:top.x-2,y:top.y),NSPoint(x:(seat.x+crank.x)/2,y:(seat.y+crank.y)/2),2.2)
        vmMetalLink(head,front,width:3.4,dark:false)
        vmMetalLink(NSPoint(x:head.x-1,y:head.y+1),NSPoint(x:front.x-1,y:front.y),width:3.0,dark:true)
        vmMetalLink(head,NSPoint(x:grip.x-2,y:grip.y+10),width:3.0,dark:false);vmMetalLink(NSPoint(x:grip.x-2,y:grip.y+10),grip,width:2.8,dark:false)
        vmMetalLink(NSPoint(x:grip.x-8,y:grip.y+4),NSPoint(x:grip.x+3,y:grip.y+3),width:1.8,dark:false)   // crossbar
        line(grip.x-6,grip.y,grip.x+7,grip.y,3.8,NSColor(hex:0x1D2E37))
        let cable=NSBezierPath();cable.move(to:grip);cable.curve(to:front,controlPoint1:NSPoint(x:grip.x+12,y:grip.y+18),controlPoint2:NSPoint(x:front.x-16,y:front.y-29));cable.lineWidth=0.7;NSColor(hex:0x283E45).setStroke();cable.stroke()
        vmMetalLink(seat,NSPoint(x:seat.x,y:seat.y-5),width:2.6,dark:false)
        vmRounded(NSRect(x:seat.x-11,y:seat.y-5.5,width:22,height:5.5),radius:2.5,colors:[NSColor(hex:0x6A727A),NSColor(hex:0x1C2B34)],angle:90)
        circle(crank.x,crank.y,7.6,NSColor(hex:0x30454D));circle(crank.x,crank.y,5.8,NSColor(hex:0xAEBBBC));circle(crank.x,crank.y,3.5,NSColor(hex:0x43565D))
        let length=0.12*u
        for side in [-1.0,1.0] {
            let p=NSPoint(x:crank.x+cos(pedalPhase)*length*side,y:crank.y-sin(pedalPhase)*length*side)
            vmMetalLink(crank,p,width:2.3,dark:side<0)
            vmRounded(NSRect(x:p.x-5.5,y:p.y-1.5,width:11,height:3),radius:0.9,colors:[NSColor(hex:0x939E9B),NSColor(hex:0x263B43)],angle:90)
        }
        vmBolt(crank.x,crank.y,r:1.7); vmBolt(head.x,head.y,r:1.5)
    }
}
