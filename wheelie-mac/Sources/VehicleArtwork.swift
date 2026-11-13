import Cocoa

/// Frame, wheels and suspension are separate pieces. Every axle below is supplied
/// by the simulation in chassis coordinates; the artwork never invents wheel travel.
extension RideRenderer {
    func drawVehicle(kind:BikeKind,rearAxle:NSPoint,frontAxle:NSPoint,
                     frontCompression:Double,rearCompression:Double,
                     rotationRear:Double,rotationFront:Double,pedalPhase:Double,time:Double) {
        let rig=kind.rig, u=rig.drawingUnitsPerMetre
        func pt(_ value:RideVector)->NSPoint { NSPoint(x:value.x*u,y:-value.y*u) }
        let pivot=pt(rig.swingPivot), fork=pt(rig.frontSuspensionMount), grip=pt(rig.grip)
        let radius=rig.wheelRadius*u
        let isCycle=kind == .bmx
        vmWheel(at:rearAxle,radius:radius,rotation:rotationRear,kind:kind,front:false)
        vmWheel(at:frontAxle,radius:radius,rotation:rotationFront,kind:kind,front:true)

        if isCycle {
            vmBicycle(rig:rig,rear:rearAxle,front:frontAxle,pedalPhase:pedalPhase)
            return
        }
        // Far side of the chassis and the two actual suspension connections.
        vmMetalLink(NSPoint(x:20,y:-38),NSPoint(x:59,y:-29),width:5,dark:true)
        vmMetalLink(pivot,rearAxle,width:7.5,dark:false)
        vmMetalLink(NSPoint(x:pivot.x-2,y:pivot.y+3),NSPoint(x:rearAxle.x+5,y:rearAxle.y+2),width:2.3,dark:true)
        vmChain(rear:rearAxle,crank:NSPoint(x:43,y:-8),rotation:rotationRear)
        let lower=vmMix(rearAxle,pivot,0.48)
        vmShock(top:pt(rig.rearSuspensionMount),bottom:lower,offroad:(kind == .motocross || kind == .trials || kind == .scrambler))
        vmFork(top:fork,axle:frontAxle,offroad:(kind == .motocross || kind == .trials || kind == .scrambler))
        // The front mudguard and caliper move with the unsprung wheel assembly.
        vmFender(axle:frontAxle,radius:radius,offroad:(kind == .motocross || kind == .trials || kind == .scrambler),paint:body)
        let caliper=NSPoint(x:frontAxle.x-6,y:frontAxle.y-7)
        vmRounded(NSRect(x:caliper.x-2,y:caliper.y-4,width:5,height:8),radius:1.5,
                  colors:[NSColor(hex:0xA7A391),NSColor(hex:0x555B5B)],angle:0)
        let brakeLine=NSBezierPath(); brakeLine.move(to:grip)
        brakeLine.curve(to:caliper,controlPoint1:NSPoint(x:grip.x+10,y:grip.y+18),controlPoint2:NSPoint(x:frontAxle.x-17,y:frontAxle.y-26))
        brakeLine.lineWidth=0.65; NSColor(hex:0x242C33).setStroke(); brakeLine.stroke()
        if kind != .scooter && kind != .electric { vmEngine(kind:kind); vmExhaust(kind:kind) }
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
        vmHandlebar(fork:fork,grip:grip,kind:kind)
        let peg=pt(rig.footPeg)
        vmMetalLink(NSPoint(x:peg.x-4,y:peg.y),NSPoint(x:peg.x+7,y:peg.y),width:2.9,dark:true)
        for i in 0..<5 { line(peg.x-2+Double(i)*1.5,peg.y-1.5,peg.x-2+Double(i)*1.5,peg.y+1,0.5,NSColor(hex:0xC5CBCD)) }
        vmBolt(pivot.x,pivot.y,r:2)
        vmBolt(fork.x,fork.y,r:1.7)
    }

    private func vmMix(_ a:NSPoint,_ b:NSPoint,_ t:Double)->NSPoint { NSPoint(x:a.x+(b.x-a.x)*t,y:a.y+(b.y-a.y)*t) }
    private func vmTone(_ c:NSColor,_ amount:Double)->NSColor {
        c.blended(withFraction:abs(amount),of:amount>=0 ? .white : .black) ?? c
    }
    private func vmFill(_ path:NSBezierPath,colors:[NSColor],angle:Double=90,outline:Double=0.65) {
        NSGradient(colors:colors)?.draw(in:path,angle:angle)
        if outline>0 { NSColor(hex:0x17232B,alpha:0.9).setStroke(); path.lineWidth=outline; path.lineJoinStyle = .round; path.stroke() }
    }
    private func vmRounded(_ rect:NSRect,radius:Double,colors:[NSColor],angle:Double=90) {
        vmFill(NSBezierPath(roundedRect:rect,xRadius:radius,yRadius:radius),colors:colors,angle:angle)
    }
    private func vmMetalLink(_ a:NSPoint,_ b:NSPoint,width:Double,dark:Bool) {
        let c1=NSColor(hex:dark ? 0x53616A : 0xEDF1ED), c2=NSColor(hex:dark ? 0x202C33 : 0x788890)
        let dx=b.x-a.x,dy=b.y-a.y,d=max(0.001,hypot(dx,dy)),nx = -dy/d,ny=dx/d
        let p=NSBezierPath();p.move(to:NSPoint(x:a.x+nx*width/2,y:a.y+ny*width/2))
        p.line(to:NSPoint(x:b.x+nx*width/2,y:b.y+ny*width/2))
        p.curve(to:NSPoint(x:b.x-nx*width/2,y:b.y-ny*width/2),controlPoint1:NSPoint(x:b.x+dx/d*width/2+nx*width/2,y:b.y+dy/d*width/2+ny*width/2),controlPoint2:NSPoint(x:b.x+dx/d*width/2-nx*width/2,y:b.y+dy/d*width/2-ny*width/2))
        p.line(to:NSPoint(x:a.x-nx*width/2,y:a.y-ny*width/2))
        p.curve(to:NSPoint(x:a.x+nx*width/2,y:a.y+ny*width/2),controlPoint1:NSPoint(x:a.x-dx/d*width/2-nx*width/2,y:a.y-dy/d*width/2-ny*width/2),controlPoint2:NSPoint(x:a.x-dx/d*width/2+nx*width/2,y:a.y-dy/d*width/2+ny*width/2));p.close()
        vmFill(p,colors:[c1,c2],angle:atan2(dy,dx)*180/Double.pi+90,outline:0.65)
        line(a.x+nx*width*0.23,a.y+ny*width*0.23,b.x+nx*width*0.23,b.y+ny*width*0.23,0.55,NSColor.white.withAlphaComponent(dark ? 0.12 : 0.55))
    }
    private func vmBolt(_ x:Double,_ y:Double,r:Double=1.3) {
        let disc=NSBezierPath(ovalIn:NSRect(x:x-r,y:y-r,width:r*2,height:r*2))
        vmFill(disc,colors:[NSColor(hex:0xE6EBE8),NSColor(hex:0x6D7B82)],outline:0.35)
        line(x-r*0.45,y+r*0.2,x+r*0.45,y-r*0.2,max(0.35,r*0.22),NSColor(hex:0x37454C))
    }
    private func vmWheel(at axle:NSPoint,radius r:Double,rotation:Double,kind:BikeKind,front:Bool) {
        let x=axle.x,y=axle.y,cycle=kind == .bmx,offroad=(kind == .motocross || kind == .trials || kind == .scrambler)
        let tyre=NSBezierPath(ovalIn:NSRect(x:x-r,y:y-r,width:r*2,height:r*2))
        vmFill(tyre,colors:[NSColor(hex:0x465159),NSColor(hex:0x111A21),NSColor(hex:0x263039)],angle:65,outline:0.6)
        let treadRadius=r-1.1
        let count=offroad ? 36 : 42
        for i in 0..<count {
            let a=Double(i)*2*Double.pi/Double(count)+rotation
            let inner=treadRadius-(offroad ? 1.3 : 0.4), outer=treadRadius+(offroad ? 1.2 : 0.2)
            line(x+cos(a)*inner,y+sin(a)*inner,x+cos(a+0.012)*outer,y+sin(a+0.012)*outer,offroad ? 1.55 : 0.48,NSColor(hex:offroad ? 0x172127 : 0x647078,alpha:offroad ? 1 : 0.5))
        }
        let rimRadius=r-(cycle ? 3.7 : 5.5)
        let rim=NSBezierPath(ovalIn:NSRect(x:x-rimRadius,y:y-rimRadius,width:rimRadius*2,height:rimRadius*2))
        vmFill(rim,colors:[NSColor(hex:0xE9ECE7),NSColor(hex:0x7B8A92),NSColor(hex:0xC5CED0)],angle:70,outline:0.4)
        circle(x,y,rimRadius-1.25,NSColor(hex:0x303E45))
        if kind == .sport || kind == .hyperbike {
            for i in 0..<5 {
                let a=Double(i)*2*Double.pi/5+rotation
                let p=NSBezierPath(); p.move(to:NSPoint(x:x+cos(a)*4,y:y+sin(a)*4))
                p.curve(to:NSPoint(x:x+cos(a+0.30)*(rimRadius-2),y:y+sin(a+0.30)*(rimRadius-2)),controlPoint1:NSPoint(x:x+cos(a-0.2)*8,y:y+sin(a-0.2)*8),controlPoint2:NSPoint(x:x+cos(a+0.02)*15,y:y+sin(a+0.02)*15))
                p.line(to:NSPoint(x:x+cos(a+0.49)*(rimRadius-2),y:y+sin(a+0.49)*(rimRadius-2)))
                p.curve(to:NSPoint(x:x+cos(a+0.5)*4,y:y+sin(a+0.5)*4),controlPoint1:NSPoint(x:x+cos(a+0.4)*13,y:y+sin(a+0.4)*13),controlPoint2:NSPoint(x:x+cos(a+0.45)*8,y:y+sin(a+0.45)*8)); p.close()
                vmFill(p,colors:[NSColor(hex:0xC4CDD0),NSColor(hex:0x606E77)],angle:45,outline:0.4)
            }
        } else {
            let spokeCount=cycle ? 28 : 24
            for i in 0..<spokeCount {
                let a=Double(i)*2*Double.pi/Double(spokeCount)+rotation
                line(x+cos(a+0.50)*3,y+sin(a+0.50)*3,x+cos(a)*(rimRadius-1.7),y+sin(a)*(rimRadius-1.7),cycle ? 0.45 : 0.55,NSColor(hex:0xBCCACD,alpha:0.92))
            }
        }
        if !cycle {
            let discRadius=front ? rimRadius*0.62 : rimRadius*0.46
            let rotor=NSBezierPath(ovalIn:NSRect(x:x-discRadius,y:y-discRadius,width:discRadius*2,height:discRadius*2))
            vmFill(rotor,colors:[NSColor(hex:0xCED4CD,alpha:0.9),NSColor(hex:0x7F8C8F,alpha:0.8)],outline:0.45)
            circle(x,y,discRadius*0.68,NSColor(hex:0x3E4C52))
            for i in 0..<14 {
                let a=Double(i)*2*Double.pi/14+rotation
                circle(x+cos(a)*discRadius*0.84,y+sin(a)*discRadius*0.84,0.58,NSColor(hex:0x33424A))
            }
        }
        circle(x,y,cycle ? 3.3 : 4.4,NSColor(hex:0x45545B)); vmBolt(x,y,r:cycle ? 1.6 : 2.3)
        // Fixed specular arcs remain independent of the rotating spokes.
        let shine=NSBezierPath();shine.appendArc(withCenter:axle,radius:r-2.2,startAngle:208,endAngle:258,clockwise:false)
        shine.lineWidth=0.75;NSColor(hex:0xA2ADB2,alpha:0.45).setStroke();shine.stroke()
    }
    private func vmChain(rear:NSPoint,crank:NSPoint,rotation:Double) {
        circle(crank.x,crank.y,6,NSColor(hex:0xA2ADB2));circle(crank.x,crank.y,4.8,NSColor(hex:0x394950))
        let p=NSBezierPath();p.move(to:NSPoint(x:rear.x,y:rear.y-4));p.line(to:NSPoint(x:crank.x,y:crank.y-5));p.curve(to:NSPoint(x:crank.x,y:crank.y+5),controlPoint1:NSPoint(x:crank.x+7,y:crank.y-5),controlPoint2:NSPoint(x:crank.x+7,y:crank.y+5));p.line(to:NSPoint(x:rear.x,y:rear.y+4));p.curve(to:NSPoint(x:rear.x,y:rear.y-4),controlPoint1:NSPoint(x:rear.x-5,y:rear.y+4),controlPoint2:NSPoint(x:rear.x-5,y:rear.y-4));p.close()
        p.lineWidth=1.25;NSColor(hex:0x29363B).setStroke();p.stroke();p.lineWidth=0.5;NSColor(hex:0xC2C5B7).setStroke();p.stroke()
        for i in 0..<8 { let a=Double(i)*Double.pi/4+rotation; circle(crank.x+cos(a)*4.8,crank.y+sin(a)*4.8,0.45,NSColor(hex:0xD2D7D1)) }
    }
    private func vmShock(top:NSPoint,bottom:NSPoint,offroad:Bool) {
        vmMetalLink(top,bottom,width:3.2,dark:false)
        let dx=bottom.x-top.x,dy=bottom.y-top.y,len=max(0.001,hypot(dx,dy)),nx = -dy/len,ny=dx/len
        let start=vmMix(top,bottom,0.16),end=vmMix(top,bottom,0.85)
        let coil=NSBezierPath();coil.move(to:start)
        for i in 1...48 {
            let t=Double(i)/48,base=vmMix(start,end,t),wave=sin(t*Double.pi*12)*3.3
            coil.line(to:NSPoint(x:base.x+nx*wave,y:base.y+ny*wave))
        }
        coil.lineWidth=1.65;NSColor(hex:0x24343A).setStroke();coil.stroke();coil.lineWidth=1.0;NSColor(hex:offroad ? 0xE3BC58 : 0xD2D9D6).setStroke();coil.stroke()
        vmBolt(top.x,top.y,r:1.8); vmBolt(bottom.x,bottom.y,r:1.8)
    }
    private func vmFork(top:NSPoint,axle:NSPoint,offroad:Bool) {
        let dx=axle.x-top.x,dy=axle.y-top.y,length=max(0.001,hypot(dx,dy))
        let direction=NSPoint(x:dx/length,y:dy/length)
        // Both tube sections retain their manufactured lengths. Their overlap,
        // rather than the tubes themselves, changes with the simulated travel.
        let outerLength=offroad ? 47.0 : 36.0,innerLength=offroad ? 43.0 : 35.0
        let upperEnd=NSPoint(x:top.x+direction.x*outerLength,y:top.y+direction.y*outerLength)
        let chromeStart=NSPoint(x:axle.x-direction.x*innerLength,y:axle.y-direction.y*innerLength)
        vmMetalLink(chromeStart,axle,width:4.2,dark:false)
        vmMetalLink(top,upperEnd,width:6.4,dark:!offroad)
        if offroad {
            let p=NSBezierPath();p.move(to:top);p.line(to:upperEnd);p.lineWidth=4.8;p.lineCapStyle = .round;NSColor(hex:0xBBA25D).setStroke();p.stroke()
            line(top.x-0.8,top.y,upperEnd.x-0.8,upperEnd.y,0.8,NSColor(hex:0xEDDB95))
        }
        vmMetalLink(NSPoint(x:upperEnd.x-direction.x*1.8,y:upperEnd.y-direction.y*1.8),NSPoint(x:upperEnd.x+direction.x*1.3,y:upperEnd.y+direction.y*1.3),width:7.1,dark:true)
        vmBolt(axle.x,axle.y,r:2.1)
    }
    private func vmFender(axle:NSPoint,radius:Double,offroad:Bool,paint:NSColor) {
        let p=NSBezierPath()
        if offroad {
            p.move(to:NSPoint(x:axle.x-18,y:axle.y-radius-9))
            p.curve(to:NSPoint(x:axle.x+20,y:axle.y-radius-6),controlPoint1:NSPoint(x:axle.x-4,y:axle.y-radius-15),controlPoint2:NSPoint(x:axle.x+13,y:axle.y-radius-11))
            p.line(to:NSPoint(x:axle.x+24,y:axle.y-radius-3));p.curve(to:NSPoint(x:axle.x-17,y:axle.y-radius-5),controlPoint1:NSPoint(x:axle.x+8,y:axle.y-radius-5),controlPoint2:NSPoint(x:axle.x-6,y:axle.y-radius-8))
        } else {
            p.move(to:NSPoint(x:axle.x-17,y:axle.y-radius+2));p.curve(to:NSPoint(x:axle.x+16,y:axle.y-radius+2),controlPoint1:NSPoint(x:axle.x-7,y:axle.y-radius-6),controlPoint2:NSPoint(x:axle.x+7,y:axle.y-radius-6));p.line(to:NSPoint(x:axle.x+15,y:axle.y-radius+5));p.curve(to:NSPoint(x:axle.x-16,y:axle.y-radius+5),controlPoint1:NSPoint(x:axle.x+4,y:axle.y-radius-1),controlPoint2:NSPoint(x:axle.x-6,y:axle.y-radius-1))
        }
        p.close();vmFill(p,colors:[vmTone(paint,0.28),paint,vmTone(paint,-0.28)],angle:90)
    }
    private func vmEngine(kind:BikeKind) {
        let casePath=NSBezierPath();casePath.move(to:NSPoint(x:35,y:-31));casePath.curve(to:NSPoint(x:60,y:-23),controlPoint1:NSPoint(x:43,y:-37),controlPoint2:NSPoint(x:60,y:-35));casePath.curve(to:NSPoint(x:56,y:-6),controlPoint1:NSPoint(x:64,y:-19),controlPoint2:NSPoint(x:64,y:-10));casePath.line(to:NSPoint(x:37,y:-6));casePath.curve(to:NSPoint(x:35,y:-31),controlPoint1:NSPoint(x:29,y:-9),controlPoint2:NSPoint(x:29,y:-24));casePath.close()
        vmFill(casePath,colors:[NSColor(hex:0x9AA5A8),NSColor(hex:0x3A4950),NSColor(hex:0x65757D)],angle:60,outline:0.8)
        for i in 0..<6 { let yy = -36.0+Double(i)*2.1; vmMetalLink(NSPoint(x:44,y:yy),NSPoint(x:60,y:yy+2),width:1.05,dark:i%2==0) }
        let cover=NSBezierPath(ovalIn:NSRect(x:34,y:-27,width:21,height:20));vmFill(cover,colors:[NSColor(hex:0xB2BCBC),NSColor(hex:0x53626A)],angle:60)
        let inset=NSBezierPath(ovalIn:NSRect(x:39,y:-22,width:11,height:10));vmFill(inset,colors:[NSColor(hex:0x4D5E66),NSColor(hex:0x859399)],outline:0.4)
        for i in 0..<5 { let a=Double(i)*Double.pi*2/5;vmBolt(44.5+cos(a)*8, -17+sin(a)*7,r:0.8) }
        vmRounded(NSRect(x:59,y:-30,width:9,height:13),radius:2,colors:[NSColor(hex:0x252F35),NSColor(hex:0x526068)])
        line(49,-34,52,-40,1.3,NSColor(hex:0x2B353C))
    }
    private func vmExhaust(kind:BikeKind) {
        let pipe=NSBezierPath();pipe.move(to:NSPoint(x:62,y:-27));pipe.curve(to:NSPoint(x:68,y:-4),controlPoint1:NSPoint(x:75,y:-25),controlPoint2:NSPoint(x:73,y:-8));pipe.curve(to:NSPoint(x:17,y:-7),controlPoint1:NSPoint(x:62,y:3),controlPoint2:NSPoint(x:31,y:-3));pipe.lineWidth=4.2;pipe.lineCapStyle = .round;NSColor(hex:0x27353C).setStroke();pipe.stroke();pipe.lineWidth=2.7;NSColor(hex:0xB1B7AF).setStroke();pipe.stroke();pipe.lineWidth=0.7;NSColor(hex:0xE5E8DC).setStroke();pipe.stroke()
        let y=(kind == .motocross || kind == .trials || kind == .scrambler) ? -28.0 : -14.0
        vmMetalLink(NSPoint(x:3,y:y-5),NSPoint(x:29,y:y),width:9,dark:kind == .sport || kind == .hyperbike)
        line(5,y-7,26,y-2,0.8,NSColor(hex:0xD9E1DC,alpha:0.65));vmMetalLink(NSPoint(x:1,y:y-5),NSPoint(x:4,y:y-4.5),width:7.3,dark:true)
        vmBolt(21,y-2,r:0.8)
    }
    private func vmSeat(rig:VehicleRig,kind:BikeKind) {
        let x=rig.seat.x*rig.drawingUnitsPerMetre,y = -rig.seat.y*rig.drawingUnitsPerMetre
        let p=NSBezierPath();p.move(to:NSPoint(x:(kind == .motocross || kind == .trials || kind == .scrambler) ? -13 : -5,y:y))
        p.curve(to:NSPoint(x:x+20,y:y+1.5),controlPoint1:NSPoint(x:7,y:y-3),controlPoint2:NSPoint(x:x+8,y:y-1))
        p.line(to:NSPoint(x:x+19,y:y+6));p.curve(to:NSPoint(x:-5,y:y+5),controlPoint1:NSPoint(x:22,y:y+7),controlPoint2:NSPoint(x:5,y:y+6));p.close()
        vmFill(p,colors:[NSColor(hex:0x53606A),NSColor(hex:0x17242C)],angle:85,outline:0.65)
        line(1,y+1,x+12,y+2,0.55,NSColor(hex:0x849099,alpha:0.7))
        for i in 0..<5 { let xx=Double(i)*6;line(xx,y+4,xx+2,y+4.3,0.45,NSColor(hex:0x818A90,alpha:0.45)) }
    }
    private func vmStreetBody(rig:VehicleRig) {
        let tank=NSBezierPath();tank.move(to:NSPoint(x:31,y:-42));tank.curve(to:NSPoint(x:45,y:-59),controlPoint1:NSPoint(x:32,y:-53),controlPoint2:NSPoint(x:38,y:-59));tank.curve(to:NSPoint(x:65,y:-58),controlPoint1:NSPoint(x:52,y:-62),controlPoint2:NSPoint(x:59,y:-61));tank.curve(to:NSPoint(x:78,y:-45),controlPoint1:NSPoint(x:74,y:-56),controlPoint2:NSPoint(x:76,y:-51));tank.curve(to:NSPoint(x:62,y:-35),controlPoint1:NSPoint(x:76,y:-38),controlPoint2:NSPoint(x:69,y:-34));tank.curve(to:NSPoint(x:31,y:-42),controlPoint1:NSPoint(x:50,y:-34),controlPoint2:NSPoint(x:39,y:-36));tank.close()
        vmFill(tank,colors:[vmTone(body,0.48),body,vmTone(body,-0.30)],angle:80,outline:0.8)
        let shine=NSBezierPath();shine.move(to:NSPoint(x:37,y:-49));shine.curve(to:NSPoint(x:65,y:-54),controlPoint1:NSPoint(x:44,y:-59),controlPoint2:NSPoint(x:58,y:-58));shine.lineWidth=1.4;shine.lineCapStyle = .round;NSColor.white.withAlphaComponent(0.46).setStroke();shine.stroke()
        vmRounded(NSRect(x:51,y:-61,width:9,height:2.5),radius:1.1,colors:[NSColor(hex:0xCFD3C8),NSColor(hex:0x68777B)],angle:90)
        let side=NSBezierPath(roundedRect:NSRect(x:7,y:-36,width:27,height:15),xRadius:4,yRadius:4)
        vmFill(side,colors:[vmTone(body,0.14),vmTone(body,-0.31)],angle:80)
        text("125",19,-32,6.4,NSColor(hex:0x23363C),.bold,center:true)
        vmSeat(rig:rig,kind:.commuter)
        vmMetalLink(NSPoint(x:2,y:-28),NSPoint(x:-12,y:-27),width:3.4,dark:true)
        vmRounded(NSRect(x:-13,y:-30,width:5,height:5),radius:1.3,colors:[NSColor(hex:0xF78364),NSColor(hex:0xB23828)],angle:90)
        let headlamp=NSBezierPath(ovalIn:NSRect(x:84,y:-60,width:11,height:12));vmFill(headlamp,colors:[NSColor(hex:0x8C9A9C),NSColor(hex:0x26363E)],angle:0)
        let lens=NSBezierPath(ovalIn:NSRect(x:90,y:-58.5,width:6,height:9));vmFill(lens,colors:[NSColor(hex:0xFFF9D7),NSColor(hex:0xDACB96)],outline:0.45)
        line(93,-57,93,-51,0.7,NSColor.white.withAlphaComponent(0.8))
        vmMetalLink(NSPoint(x:79,y:-63),NSPoint(x:74,y:-81),width:1.2,dark:false)
        vmRounded(NSRect(x:69,y:-85,width:11,height:6),radius:2.6,colors:[NSColor(hex:0x889CA5),NSColor(hex:0x243740)],angle:90)
    }
    /// Cruiser: the street body plus a rear saddlebag, a chrome backrest and a deep fender.
    private func vmCruiserBody(rig:VehicleRig) {
        vmStreetBody(rig:rig)
        let bag=NSBezierPath(roundedRect:NSRect(x:-12,y:-41,width:34,height:19),xRadius:6,yRadius:6)
        vmFill(bag,colors:[NSColor(hex:0x8A5E3C),NSColor(hex:0x4A2F1C)],angle:80,outline:0.7)
        for x in [-3.0,18.0] { line(x,-41,x,-22,0.6,NSColor(hex:0xC8A070,alpha:0.7)) }
        vmRounded(NSRect(x:3,y:-37,width:8,height:5),radius:1.6,colors:[NSColor(hex:0xD8C9A6),NSColor(hex:0x8E7B55)])
        vmMetalLink(NSPoint(x:-10,y:-42),NSPoint(x:-11,y:-66),width:1.5,dark:false)
        vmRounded(NSRect(x:-17,y:-72,width:12,height:7),radius:3,colors:[NSColor(hex:0x6B4A33),NSColor(hex:0x33200F)])
        vmMetalLink(NSPoint(x:-3,y:-47),NSPoint(x:-10,y:-60),width:1.1,dark:false)
    }
    /// Electric bike: a minimal frame (borrowed from the trials bike) with a battery pack and hub motor instead of an engine.
    private func vmElectricBody(rig:VehicleRig) {
        vmTrialsBody(rig:rig)
        let pack=NSBezierPath(roundedRect:NSRect(x:33,y:-37,width:32,height:26),xRadius:5,yRadius:5)
        vmFill(pack,colors:[NSColor(hex:0x4A5560),NSColor(hex:0x1E262D)],angle:80,outline:0.8)
        for i in 0..<4 { line(38+Double(i)*6.5,-33,38+Double(i)*6.5,-15,0.8,NSColor(hex:0x6FE08A,alpha:0.55)) }
        vmRounded(NSRect(x:36,y:-35,width:10,height:3),radius:1,colors:[NSColor(hex:0x6FE08A),NSColor(hex:0x2E9E52)])
        text("E",58,-30,8,NSColor(hex:0x6FE08A),.heavy,center:true)
        vmMetalLink(NSPoint(x:12,y:-9),NSPoint(x:36,y:-18),width:3.2,dark:true)
    }
    private func vmEnduroBody(rig:VehicleRig) {
        let shroud=NSBezierPath();shroud.move(to:NSPoint(x:39,y:-54));shroud.curve(to:NSPoint(x:66,y:-68),controlPoint1:NSPoint(x:44,y:-62),controlPoint2:NSPoint(x:57,y:-69));shroud.line(to:NSPoint(x:79,y:-60));shroud.line(to:NSPoint(x:69,y:-34));shroud.curve(to:NSPoint(x:47,y:-32),controlPoint1:NSPoint(x:60,y:-28),controlPoint2:NSPoint(x:52,y:-31));shroud.close()
        vmFill(shroud,colors:[vmTone(body,0.35),body,vmTone(body,-0.25)],angle:70,outline:0.8)
        poly([(51,-54),(65,-59),(68,-52),(60,-36),(52,-38)],NSColor(hex:0xEEEFE3),stroke:NSColor(hex:0x34434B),width:0.4)
        text("07",60,-53,8.5,NSColor(hex:0x31444B),.heavy,center:true)
        line(71,-57,68,-48,1.3,NSColor(hex:0x37494F));line(74,-55,71,-46,1.1,NSColor(hex:0x37494F))
        let tail=NSBezierPath();tail.move(to:NSPoint(x:-17,y:-58));tail.curve(to:NSPoint(x:26,y:-60),controlPoint1:NSPoint(x:-4,y:-64),controlPoint2:NSPoint(x:12,y:-63));tail.line(to:NSPoint(x:39,y:-53));tail.line(to:NSPoint(x:16,y:-46));tail.line(to:NSPoint(x:-13,y:-52));tail.close()
        vmFill(tail,colors:[vmTone(body,0.28),body,vmTone(body,-0.28)],angle:90)
        vmSeat(rig:rig,kind:.motocross)
        let plate=NSBezierPath();plate.move(to:NSPoint(x:78,y:-78));plate.line(to:NSPoint(x:91,y:-76));plate.line(to:NSPoint(x:88,y:-59));plate.curve(to:NSPoint(x:77,y:-60),controlPoint1:NSPoint(x:83,y:-56),controlPoint2:NSPoint(x:79,y:-57));plate.close()
        vmFill(plate,colors:[NSColor(hex:0xFFFFEF),NSColor(hex:0xB3C1BB)],angle:65)
        vmBolt(82,-75,r:0.7); vmBolt(84,-61,r:0.7)
        vmMetalLink(NSPoint(x:30,y:-24),NSPoint(x:68,y:-15),width:2.5,dark:true)
    }
    private func vmSportBody(rig:VehicleRig) {
        let tail=NSBezierPath();tail.move(to:NSPoint(x:-15,y:-48));tail.curve(to:NSPoint(x:23,y:-56),controlPoint1:NSPoint(x:0,y:-54),controlPoint2:NSPoint(x:12,y:-55));tail.line(to:NSPoint(x:41,y:-47));tail.line(to:NSPoint(x:20,y:-38));tail.line(to:NSPoint(x:-9,y:-42));tail.close();vmFill(tail,colors:[vmTone(body,0.3),body,vmTone(body,-0.3)],angle:80)
        let tank=NSBezierPath();tank.move(to:NSPoint(x:32,y:-47));tank.curve(to:NSPoint(x:60,y:-65),controlPoint1:NSPoint(x:35,y:-58),controlPoint2:NSPoint(x:46,y:-67));tank.curve(to:NSPoint(x:78,y:-56),controlPoint1:NSPoint(x:68,y:-66),controlPoint2:NSPoint(x:74,y:-62));tank.line(to:NSPoint(x:64,y:-39));tank.close();vmFill(tank,colors:[vmTone(body,0.5),body,vmTone(body,-0.25)],angle:80)
        let fairing=NSBezierPath();fairing.move(to:NSPoint(x:63,y:-53));fairing.curve(to:NSPoint(x:91,y:-65),controlPoint1:NSPoint(x:73,y:-65),controlPoint2:NSPoint(x:85,y:-67));fairing.curve(to:NSPoint(x:107,y:-45),controlPoint1:NSPoint(x:100,y:-61),controlPoint2:NSPoint(x:108,y:-50));fairing.line(to:NSPoint(x:91,y:-32));fairing.line(to:NSPoint(x:78,y:-4));fairing.curve(to:NSPoint(x:50,y:-2),controlPoint1:NSPoint(x:67,y:2),controlPoint2:NSPoint(x:55,y:1));fairing.line(to:NSPoint(x:48,y:-21));fairing.curve(to:NSPoint(x:63,y:-53),controlPoint1:NSPoint(x:52,y:-30),controlPoint2:NSPoint(x:56,y:-44));fairing.close()
        vmFill(fairing,colors:[vmTone(body,0.4),body,vmTone(body,-0.34)],angle:75,outline:0.85)
        let inset=NSBezierPath();inset.move(to:NSPoint(x:64,y:-36));inset.curve(to:NSPoint(x:96,y:-50),controlPoint1:NSPoint(x:75,y:-44),controlPoint2:NSPoint(x:87,y:-47));inset.line(to:NSPoint(x:79,y:-14));inset.line(to:NSPoint(x:60,y:-8));inset.line(to:NSPoint(x:67,y:-27));inset.close();vmFill(inset,colors:[NSColor(hex:0xF9F9ED),NSColor(hex:0xBFCBC7)],angle:90,outline:0.3)
        let vent=NSBezierPath();vent.move(to:NSPoint(x:72,y:-31));vent.curve(to:NSPoint(x:88,y:-37),controlPoint1:NSPoint(x:76,y:-35),controlPoint2:NSPoint(x:83,y:-37));vent.line(to:NSPoint(x:84,y:-28));vent.line(to:NSPoint(x:71,y:-25));vent.close();vmFill(vent,colors:[NSColor(hex:0x152D39),NSColor(hex:0x45616B)],outline:0.3)
        for i in 0..<3 { line(73,-29+Double(i)*1.2,84-Double(i)*0.5,-33+Double(i)*1.2,0.55,NSColor(hex:0x80999D)) }
        let windscreen=NSBezierPath();windscreen.move(to:NSPoint(x:79,y:-62));windscreen.curve(to:NSPoint(x:80,y:-79),controlPoint1:NSPoint(x:77,y:-69),controlPoint2:NSPoint(x:77,y:-75));windscreen.curve(to:NSPoint(x:94,y:-65),controlPoint1:NSPoint(x:89,y:-77),controlPoint2:NSPoint(x:92,y:-70));windscreen.close();vmFill(windscreen,colors:[NSColor(hex:0xBAD4DD,alpha:0.8),NSColor(hex:0x365364,alpha:0.9)],angle:60,outline:0.65)
        line(81,-76,88,-72,0.8,NSColor.white.withAlphaComponent(0.65))
        vmSeat(rig:rig,kind:.sport)
        vmRounded(NSRect(x:-7,y:-47,width:7,height:3),radius:1,colors:[NSColor(hex:0xFF8B68),NSColor(hex:0xA62F26)])
        vmBolt(59,-9,r:1);vmBolt(95,-48,r:0.9)
    }
    private func vmHyperBody(rig:VehicleRig) {
        // Compact raised tail, sculpted tank and angular full fairing make the
        // litre bike identifiable before its lettering or chosen paint colour.
        let tail=NSBezierPath();tail.move(to:NSPoint(x:-11,y:-52));tail.line(to:NSPoint(x:19,y:-60));tail.line(to:NSPoint(x:42,y:-51));tail.line(to:NSPoint(x:29,y:-43));tail.line(to:NSPoint(x:4,y:-44));tail.close()
        vmFill(tail,colors:[vmTone(body,0.35),body,vmTone(body,-0.4)],angle:80)
        let tank=NSBezierPath();tank.move(to:NSPoint(x:31,y:-49));tank.curve(to:NSPoint(x:57,y:-69),controlPoint1:NSPoint(x:34,y:-63),controlPoint2:NSPoint(x:45,y:-70));tank.curve(to:NSPoint(x:79,y:-57),controlPoint1:NSPoint(x:67,y:-70),controlPoint2:NSPoint(x:76,y:-64));tank.line(to:NSPoint(x:65,y:-39));tank.close()
        vmFill(tank,colors:[vmTone(body,0.45),body,vmTone(body,-0.3)],angle:80)
        let fairing=NSBezierPath();fairing.move(to:NSPoint(x:55,y:-45));fairing.line(to:NSPoint(x:83,y:-67));fairing.line(to:NSPoint(x:103,y:-59));fairing.line(to:NSPoint(x:114,y:-49));fairing.line(to:NSPoint(x:98,y:-39));fairing.line(to:NSPoint(x:91,y:-20));fairing.line(to:NSPoint(x:78,y:0));fairing.line(to:NSPoint(x:42,y:-1));fairing.line(to:NSPoint(x:46,y:-20));fairing.close()
        vmFill(fairing,colors:[vmTone(body,0.40),body,vmTone(body,-0.42)],angle:70,outline:0.85)
        poly([(51,-35),(91,-53),(102,-50),(79,-34),(71,-9),(48,-7)],NSColor(hex:0x20323E),stroke:vmTone(body,-0.45),width:0.45)
        poly([(55,-30),(83,-43),(79,-35),(58,-22)],NSColor(hex:0xCED8D8),stroke:ink,width:0.35)
        for i in 0..<3 { line(62,-29+Double(i)*3,77,-36+Double(i)*3,0.8,NSColor(hex:0x708A95)) }
        // A winglet projects from the side panel rather than being painted on.
        poly([(81,-46),(103,-43),(99,-39),(78,-41)],NSColor(hex:0x182A36),stroke:NSColor(hex:0x526B77),width:0.5)
        line(84,-44,100,-42,0.6,NSColor(hex:0xA2BAC2))
        let screen=NSBezierPath();screen.move(to:NSPoint(x:81,y:-64));screen.curve(to:NSPoint(x:86,y:-76),controlPoint1:NSPoint(x:79,y:-69),controlPoint2:NSPoint(x:81,y:-74));screen.line(to:NSPoint(x:101,y:-61));screen.close()
        vmFill(screen,colors:[NSColor(hex:0xA2C3CE,alpha:0.85),NSColor(hex:0x233D50)],angle:60)
        line(85,-73,94,-66,0.8,NSColor.white.withAlphaComponent(0.60))
        vmSeat(rig:rig,kind:.sport)
        vmRounded(NSRect(x:-5,y:-51,width:10,height:2.5),radius:0.8,colors:[NSColor(hex:0xFF7164),NSColor(hex:0x8D2429)])
        text("R",69,-44,11,NSColor(hex:0xF2F0DF),.heavy,center:true)
        text("1000",63,-12,4.8,NSColor(hex:0xD8E4E6),.bold,center:true)
        line(103,-54,110,-50,1.1,NSColor(hex:0xEAF7F5))
        vmBolt(48,-9,r:0.9);vmBolt(96,-46,r:0.9)
    }
    private func vmScooterBody(rig:VehicleRig) {
        // Step-through leg shield, flat floor and enclosed rear transmission.
        let shell=NSBezierPath();shell.move(to:NSPoint(x:-9,y:-14))
        shell.curve(to:NSPoint(x:18,y:-43),controlPoint1:NSPoint(x:-13,y:-33),controlPoint2:NSPoint(x:1,y:-43))
        shell.line(to:NSPoint(x:38,y:-42));shell.curve(to:NSPoint(x:47,y:-10),controlPoint1:NSPoint(x:47,y:-39),controlPoint2:NSPoint(x:38,y:-15))
        shell.line(to:NSPoint(x:69,y:-10));shell.line(to:NSPoint(x:70,y:-54))
        shell.curve(to:NSPoint(x:87,y:-59),controlPoint1:NSPoint(x:71,y:-64),controlPoint2:NSPoint(x:84,y:-65))
        shell.line(to:NSPoint(x:93,y:-27));shell.curve(to:NSPoint(x:78,y:2),controlPoint1:NSPoint(x:95,y:-12),controlPoint2:NSPoint(x:86,y:1))
        shell.line(to:NSPoint(x:37,y:1));shell.curve(to:NSPoint(x:-9,y:-14),controlPoint1:NSPoint(x:16,y:4),controlPoint2:NSPoint(x:-6,y:-1));shell.close()
        vmFill(shell,colors:[vmTone(body,0.4),body,vmTone(body,-0.3)],angle:75,outline:0.8)
        vmRounded(NSRect(x:41,y:-9,width:30,height:5),radius:2,colors:[NSColor(hex:0x6D7475),NSColor(hex:0x243238)])
        for i in 0..<6 { line(45+Double(i)*4,-8,44+Double(i)*4,-4,0.7,NSColor(hex:0xA9ADAB)) }
        vmRounded(NSRect(x:-3,y:-16,width:35,height:12),radius:5,colors:[NSColor(hex:0x8A9595),NSColor(hex:0x35434B)])
        for i in 0..<4 { line(6,-32+Double(i)*3,22,-32+Double(i)*3,1,vmTone(body,-0.45)) }
        vmSeat(rig:rig,kind:.commuter)
        vmRounded(NSRect(x:72,y:-70,width:16,height:9),radius:3.5,colors:[vmTone(body,0.3),vmTone(body,-0.15)])
        vmRounded(NSRect(x:84,y:-68,width:6,height:5),radius:1.5,colors:[NSColor(hex:0xFFF7D7),NSColor(hex:0xCFD4C5)])
        vmRounded(NSRect(x:-7,y:-34,width:5,height:6),radius:1.2,colors:[NSColor(hex:0xEE846C),NSColor(hex:0x9E3C2E)])
        text("80",18,-30,6,vmTone(body,-0.65),.semibold,center:true)
        line(78,-52,83,-24,1,NSColor.white.withAlphaComponent(0.4))
    }
    private func vmScramblerBody(rig:VehicleRig) {
        let tank=NSBezierPath();tank.move(to:NSPoint(x:32,y:-45));tank.curve(to:NSPoint(x:51,y:-63),controlPoint1:NSPoint(x:34,y:-58),controlPoint2:NSPoint(x:43,y:-65));tank.curve(to:NSPoint(x:76,y:-48),controlPoint1:NSPoint(x:65,y:-64),controlPoint2:NSPoint(x:77,y:-58));tank.curve(to:NSPoint(x:32,y:-45),controlPoint1:NSPoint(x:73,y:-34),controlPoint2:NSPoint(x:43,y:-34));tank.close()
        vmFill(tank,colors:[vmTone(body,0.4),body,vmTone(body,-0.35)],angle:80,outline:0.85)
        let stripe=NSBezierPath();stripe.move(to:NSPoint(x:37,y:-50));stripe.curve(to:NSPoint(x:72,y:-50),controlPoint1:NSPoint(x:47,y:-57),controlPoint2:NSPoint(x:62,y:-57));stripe.lineWidth=3;vmTone(body,-0.55).setStroke();stripe.stroke()
        vmRounded(NSRect(x:6,y:-39,width:26,height:14),radius:3,colors:[NSColor(hex:0xD4D1BC),NSColor(hex:0x929C92)])
        text("400",19,-35,5.5,NSColor(hex:0x34423C),.bold,center:true)
        // Flat ribbed brown saddle is distinct from the road bike's tank/seat.
        vmRounded(NSRect(x:-8,y:-51,width:54,height:8),radius:3,colors:[NSColor(hex:0x8B7054),NSColor(hex:0x493E32)],angle:90)
        for i in 0..<9 { line(-4+Double(i)*5,-50,-3+Double(i)*5,-44,0.55,NSColor(hex:0xB79B75,alpha:0.6)) }
        let lamp=NSBezierPath(ovalIn:NSRect(x:88,y:-68,width:12,height:13));vmFill(lamp,colors:[NSColor(hex:0x9FA9A8),NSColor(hex:0x27373A)])
        let lens=NSBezierPath(ovalIn:NSRect(x:94,y:-66,width:6,height:9));vmFill(lens,colors:[NSColor(hex:0xFCF1C5),NSColor(hex:0xC0C2AF)])
        for y in stride(from:-65.0,through:-59.0,by:2) { line(94,y,100,y,0.7,NSColor(hex:0x313F41)) }
        // Elevated exhaust heat shield and engine bash plate.
        vmMetalLink(NSPoint(x:0,y:-29),NSPoint(x:31,y:-25),width:8,dark:true)
        vmRounded(NSRect(x:3,y:-31,width:25,height:5),radius:2,colors:[NSColor(hex:0xB8BDB6),NSColor(hex:0x6D7A78)])
        for i in 0..<7 { circle(6+Double(i)*3,-28.5,0.65,NSColor(hex:0x2C3B3F)) }
        vmMetalLink(NSPoint(x:30,y:-1),NSPoint(x:61,y:-1),width:3.3,dark:false)
    }
    private func vmTrialsBody(rig:VehicleRig) {
        // Exposed triangulated chassis; very low saddle and narrow fuel spine.
        let frame=NSBezierPath();frame.move(to:NSPoint(x:17,y:-31));frame.line(to:NSPoint(x:72,y:-63));frame.line(to:NSPoint(x:77,y:-48));frame.line(to:NSPoint(x:49,y:-8));frame.line(to:NSPoint(x:28,y:-7));frame.close()
        frame.lineJoinStyle = .round;frame.lineWidth=4.5;vmTone(body,-0.5).setStroke();frame.stroke();frame.lineWidth=2.8;body.setStroke();frame.stroke()
        vmMetalLink(NSPoint(x:27,y:-32),NSPoint(x:63,y:-16),width:2.4,dark:false)
        let spine=NSBezierPath();spine.move(to:NSPoint(x:20,y:-45));spine.line(to:NSPoint(x:63,y:-61));spine.line(to:NSPoint(x:74,y:-57));spine.line(to:NSPoint(x:52,y:-43));spine.line(to:NSPoint(x:21,y:-39));spine.close();vmFill(spine,colors:[vmTone(body,0.4),body,vmTone(body,-0.3)],angle:90)
        vmRounded(NSRect(x:17,y:-48,width:29,height:4),radius:1.5,colors:[NSColor(hex:0x4E5B60),NSColor(hex:0x1D2D34)])
        poly([(-16,-44),(18,-48),(26,-43),(-12,-39)],body,stroke:vmTone(body,-0.45),width:0.65)
        vmMetalLink(NSPoint(x:26,y:0),NSPoint(x:61,y:0),width:4,dark:false)
        for i in 0..<4 { line(32+Double(i)*6,-1,34+Double(i)*6,1,0.55,NSColor(hex:0x586B70)) }
        let plate=NSBezierPath();plate.move(to:NSPoint(x:79,y:-77));plate.line(to:NSPoint(x:91,y:-75));plate.line(to:NSPoint(x:91,y:-58));plate.line(to:NSPoint(x:78,y:-61));plate.close();vmFill(plate,colors:[NSColor(hex:0xF4F1D8),NSColor(hex:0xBCC8BC)])
        text("2",85,-73,8,NSColor(hex:0x2C4648),.bold,center:true)
        vmMetalLink(NSPoint(x:5,y:-25),NSPoint(x:27,y:-22),width:6,dark:true)
    }
    private func vmHandlebar(fork:NSPoint,grip:NSPoint,kind:BikeKind) {
        let top=NSPoint(x:fork.x+1,y:fork.y-7)
        vmMetalLink(fork,top,width:3.3,dark:false); vmMetalLink(top,grip,width:2.7,dark:false)
        vmMetalLink(NSPoint(x:grip.x-4,y:grip.y),NSPoint(x:grip.x+5,y:grip.y),width:3.5,dark:true)
        let lever=NSBezierPath();lever.move(to:NSPoint(x:grip.x+3,y:grip.y-1));lever.curve(to:NSPoint(x:grip.x+8,y:grip.y-5),controlPoint1:NSPoint(x:grip.x+8,y:grip.y-1),controlPoint2:NSPoint(x:grip.x+9,y:grip.y-3));lever.lineWidth=0.9;NSColor(hex:0xC7D0D1).setStroke();lever.stroke()
    }
    private func vmBicycle(rig:VehicleRig,rear:NSPoint,front:NSPoint,pedalPhase:Double) {
        let u=rig.drawingUnitsPerMetre, seat=NSPoint(x:rig.seat.x*u,y:-rig.seat.y*u),head=NSPoint(x:rig.frontSuspensionMount.x*u,y:-rig.frontSuspensionMount.y*u),grip=NSPoint(x:rig.grip.x*u,y:-rig.grip.y*u),crank=NSPoint(x:rig.crank.x*u,y:-rig.crank.y*u)
        func frameTube(_ a:NSPoint,_ b:NSPoint,_ w:Double) {
            vmMetalLink(a,b,width:w,dark:true)
            line(a.x-0.25,a.y-0.3,b.x-0.25,b.y-0.3,w-1,body)
            line(a.x-0.6,a.y-0.8,b.x-0.6,b.y-0.8,0.55,vmTone(body,0.55))
        }
        vmChain(rear:rear,crank:crank,rotation:pedalPhase)
        frameTube(rear,seat,2.9);frameTube(rear,crank,2.9);frameTube(seat,crank,3.4)
        frameTube(seat,head,3.7);frameTube(head,crank,3.7)
        vmMetalLink(head,front,width:3.2,dark:false)
        vmMetalLink(head,NSPoint(x:grip.x-2,y:grip.y+10),width:2.9,dark:false);vmMetalLink(NSPoint(x:grip.x-2,y:grip.y+10),grip,width:2.7,dark:false)
        line(grip.x-5,grip.y,grip.x+6,grip.y,3.5,NSColor(hex:0x1D2E37))
        let cable=NSBezierPath();cable.move(to:grip);cable.curve(to:front,controlPoint1:NSPoint(x:grip.x+12,y:grip.y+18),controlPoint2:NSPoint(x:front.x-16,y:front.y-29));cable.lineWidth=0.6;NSColor(hex:0x283E45).setStroke();cable.stroke()
        vmMetalLink(seat,NSPoint(x:seat.x,y:seat.y-5),width:2.5,dark:false)
        vmRounded(NSRect(x:seat.x-11,y:seat.y-5,width:22,height:5),radius:2.3,colors:[NSColor(hex:0x687078),NSColor(hex:0x1C2B34)],angle:90)
        circle(crank.x,crank.y,7.3,NSColor(hex:0x30454D));circle(crank.x,crank.y,5.5,NSColor(hex:0xA6B4B5));circle(crank.x,crank.y,3.4,NSColor(hex:0x43565D))
        let length=0.12*u
        for side in [-1.0,1.0] {
            let p=NSPoint(x:crank.x+cos(pedalPhase)*length*side,y:crank.y-sin(pedalPhase)*length*side)
            vmMetalLink(crank,p,width:2.1,dark:side<0)
            vmRounded(NSRect(x:p.x-5,y:p.y-1.3,width:10,height:2.6),radius:0.8,colors:[NSColor(hex:0x8B9693),NSColor(hex:0x263B43)],angle:90)
        }
        vmBolt(crank.x,crank.y,r:1.7)
        vmBolt(head.x,head.y,r:1.4)
    }
}
