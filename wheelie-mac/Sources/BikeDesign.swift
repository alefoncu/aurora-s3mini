import Cocoa

/// Hand-authored motorcycle drawing. Every shape is a single flowing outline (smooth points plus a few
/// deliberate corners) placed on the real frame geometry from `VehicleRig`; nothing is a primitive stack.
/// Coordinates are y-up drawing units relative to the rear axle (the helpers flip to screen space).
extension RideRenderer {
    typealias DP = (Double,Double,Bool)   // x, y, corner
    /// Smooth outline through the points (Catmull-Rom as cubic Béziers); corner points break the tangent.
    func vmCurve(_ pts:[DP],closed:Bool=true)->NSBezierPath {
        let p=pts.map { NSPoint(x:$0.0,y:-$0.1) },n=p.count,path=NSBezierPath()
        guard n>1 else { return path }
        func tangent(_ i:Int)->NSPoint {
            if pts[i].2 { return .zero }
            let a=closed ? p[(i+n-1)%n] : p[max(0,i-1)],b=closed ? p[(i+1)%n] : p[min(n-1,i+1)]
            return NSPoint(x:(b.x-a.x)/2,y:(b.y-a.y)/2)
        }
        path.move(to:p[0])
        for i in 0..<(closed ? n : n-1) {
            let j=(i+1)%n,t0=tangent(i),t1=tangent(j)
            path.curve(to:p[j],controlPoint1:NSPoint(x:p[i].x+t0.x/3,y:p[i].y+t0.y/3),controlPoint2:NSPoint(x:p[j].x-t1.x/3,y:p[j].y-t1.y/3))
        }
        if closed { path.close() }
        return path
    }
    func S(_ x:Double,_ y:Double)->DP { (x,y,false) }
    func C(_ x:Double,_ y:Double)->DP { (x,y,true) }
    /// A tapered capsule between two y-up points (silencers, tubes with real thickness).
    func vmCapsule(_ a:(Double,Double),_ b:(Double,Double),_ w0:Double,_ w1:Double,colors:[NSColor],outline:Double=0.8) {
        let dx=b.0-a.0,dy=b.1-a.1,l=max(0.001,hypot(dx,dy)),ux=dx/l,uy=dy/l,nx = -uy,ny=ux
        let pts:[DP]=[C(a.0+nx*w0/2,a.1+ny*w0/2),S(a.0+dx*0.5+nx*(w0+w1)/4,a.1+dy*0.5+ny*(w0+w1)/4),C(b.0+nx*w1/2,b.1+ny*w1/2),
                      S(b.0+ux*w1*0.45,b.1+uy*w1*0.45),C(b.0-nx*w1/2,b.1-ny*w1/2),S(a.0+dx*0.5-nx*(w0+w1)/4,a.1+dy*0.5-ny*(w0+w1)/4),C(a.0-nx*w0/2,a.1-ny*w0/2),S(a.0-ux*w0*0.45,a.1-uy*w0*0.45)]
        vmFill(vmCurve(pts),colors:colors,angle:atan2(-dy,dx)*180/Double.pi+90,outline:outline)
    }
    /// A tube following a smooth y-up path, drawn as dark edge + metal core + highlight.
    func vmPipe(_ pts:[(Double,Double)],width:Double,core:NSColor,edge:NSColor=NSColor(hex:0x1A2227)) {
        let path=vmCurve(pts.map { S($0.0,$0.1) },closed:false)
        path.lineCapStyle = .round; path.lineJoinStyle = .round
        path.lineWidth=width+1.8; edge.setStroke(); path.stroke()
        path.lineWidth=width; core.setStroke(); path.stroke()
        path.lineWidth=max(0.5,width*0.28); vmTone(core,0.55).setStroke()
        if let hi=path.copy() as? NSBezierPath { hi.transform(using:AffineTransform(translationByX:-width*0.18,byY:-width*0.22)); hi.stroke() }
    }

    // MARK: Sport 600 as a designed machine
    func drawSportBike(rig:VehicleRig,rearAxle:NSPoint,frontAxle:NSPoint,rotationRear:Double,rotationFront:Double,time:Double,hyper:Bool=false) {
        let u=rig.drawingUnitsPerMetre
        func pt(_ v:RideVector)->NSPoint { NSPoint(x:v.x*u,y:-v.y*u) }
        let pivot=pt(rig.swingPivot),fork=pt(rig.frontSuspensionMount),grip=pt(rig.grip)
        let radius=rig.wheelRadius*u
        let alu=NSColor(hex:0x7D8A91),aluDark=NSColor(hex:0x2F3A41),black=NSColor(hex:0x20292F)
        // Far side first: second fork leg, far swingarm leg.
        vmFarFork(top:fork,axle:frontAxle,offroad:false,upsideDown:true)
        vmSwingarm(pivot:pivot,axle:rearAxle,kind:.sport,far:true)
        // Rear shock behind the frame plate, anchored to the subframe above and the swingarm below.
        let lower=vmMix(rearAxle,pivot,0.5),shockTop=pt(rig.rearSuspensionMount)
        vmShock(top:shockTop,bottom:lower,offroad:false,reservoir:false,kind:.sport)
        // Engine: crankcase with clutch cover and sump; the lower fairing leaves it visible.
        let case_=vmCurve([S(33,16),C(35,26),S(46,31),S(57,27),C(60,16),S(57,6),S(45,2.5),C(35,6)])
        vmFill(case_,colors:[NSColor(hex:0x8E9BA1),NSColor(hex:0x4A585F),NSColor(hex:0x1E282D)],angle:70,outline:0.9)
        vmClutchCover(vmQ(43,15),r:8.2)
        // Exhaust: headers sweep down from the cylinders into a collector under the engine, then rise to a short silencer
        // that sits parallel to the tail underside, held by a bracket to the subframe.
        vmPipe([(60,22),(60,12),(53,6),(44,5),(37,8),(33,13)],width:3.2,core:NSColor(hex:0x8F9BA0))
        vmCapsule((32,17.5),(3,34),9.4,7.8,colors:[NSColor(hex:0xF7F8F3),NSColor(hex:0x93A0A6),NSColor(hex:0x56646C),NSColor(hex:0xC6CDCC)])
        // Carbon end cap and a heat-shield band.
        vmCapsule((4.6,33.4),(1.2,35.4),7.8,7.4,colors:[NSColor(hex:0x3C4247),NSColor(hex:0x101417)],outline:0.7)
        vmCapsule((25,21.6),(21,24),9.0,8.8,colors:[NSColor(hex:0x30383E),NSColor(hex:0x6B777E),NSColor(hex:0x1D2428)],outline:0.5)
        vmMetalLink(vmQ(15,30.5),vmQ(11,41),width:1.6,dark:true)
        // Frame: twin-spar side plate holding the pivot, and the subframe up to the tail.
        let plate=vmCurve([C(27,43),S(36,45),C(46,38),S(49,24),C(50,9),S(44,5),C(37,7),S(34,19),C(31,32)])
        vmFill(plate,colors:[vmTone(alu,0.5),alu,aluDark],angle:60,outline:0.9)
        vmTube(NSPoint(x:25,y:-41),NSPoint(x:-4,y:-47),2.6,alu)
        vmBolt(pivot.x,pivot.y,r:3.0)
        vmSwingarm(pivot:pivot,axle:rearAxle,kind:.sport,far:false)
        // Tail unit with seat cowl, then the seat pad on top.
        let tail=vmCurve([C(-11,57),S(0,59),S(14,57),S(30,54),C(46,52),S(44,46),S(32,42),S(14,41),S(1,43),S(-7,49)])
        vmPanel(tail,body,gloss:0.5)
        vmClip(tail) { line(-9,-52,36,-53.5,1.0,NSColor.white.withAlphaComponent(0.7)); line(2,-45,40,-46.5,2.6,vmTone(body,-0.42)) }
        let seat=vmCurve([C(-1,56.2),S(12,58),S(30,55.4),C(47,53),S(47,50.6),S(30,50.8),S(12,52.4)])
        vmFill(seat,colors:[NSColor(hex:0x4B5760),NSColor(hex:0x12191E)],angle:85,outline:0.8)
        vmTailLight(-12,53,w:6,h:2.6); vmPlate(-14,40,w:8,h:5,text:"7",size:3.6)
        // Tank: one sculpted volume from the seat to the steering head.
        let tank=vmCurve([C(40,51),S(44,58),S(55,65),S(70,67.5),C(83,64),S(80,57),S(66,50),S(50,47.5)])
        vmPanel(tank,body,gloss:0.55)
        vmClip(tank) { line(42,-60,80,-62,3.0,vmTone(body,-0.5)); line(46,-64,72,-67,0.9,NSColor.white.withAlphaComponent(0.65)) }
        // Fairing in two tones: painted upper shell with a sharp nose, matte-black lower cowl, as on real sport bikes.
        let lowerCowl=vmCurve([C(63,31),S(78,33.5),S(94,38),C(108,43),S(102,30),S(93,18),S(83,9.5),S(71,5.5),C(61,8),S(62,20)])
        vmFill(lowerCowl,colors:[NSColor(hex:0x4A5560),NSColor(hex:0x1B2228),NSColor(hex:0x0E1317)],angle:80,outline:0.9)
        vmClip(lowerCowl) {
            line(66,-8.5,100,-33,1.0,NSColor.white.withAlphaComponent(0.22))
            for i in 0..<4 { line(70+Double(i)*5,-(11+Double(i)*5.5),72.5+Double(i)*5,-(7+Double(i)*5.5),0.9,NSColor(hex:0x0A0E11)) }
        }
        let fairing=vmCurve([C(114.5,51.5),S(106,58.4),S(96,63.4),C(84,66),S(77.5,62),S(70,53),S(65,42),C(63,31.5),S(78,34.2),S(94,38.8),C(108,43.5)])
        vmPanel(fairing,body,gloss:0.6,outline:0.9)
        vmClip(fairing) {
            line(66,-47,108,-54,2.4,vmTone(body,-0.5)); line(64,-42.5,100,-48.5,0.8,NSColor.white.withAlphaComponent(0.85))
        }
        // Headlight: one swept slit with a lit lens and a thin DRL, cut into the nose.
        let slit=vmCurve([C(97.5,59.8),S(106,59.6),C(113.6,53.6),S(106,54.4),C(99,56.2)])
        vmFill(slit,colors:[NSColor(hex:0xFFFFFF),NSColor(hex:0xD6E8F0),NSColor(hex:0x7C9DB0)],angle:80,outline:0.8)
        vmClip(slit) { circle(103.6,-57.4,2.3,NSColor(hex:0xF3FAFF)); circle(103.6,-57.4,1.1,NSColor(hex:0x8DB4CA)); line(99,-58.2,111,-55.2,0.55,NSColor(hex:0x6FD6FF)) }
        vmIndicator(105,44.8)
        // Windscreen: large, raked back, smoked tint with a bright leading edge.
        let screen=vmCurve([C(101,65.6),S(95.5,74.5),C(88.5,82.5),S(83.5,82),C(80,74),S(79,66.4),S(90,66.9)])
        vmFill(screen,colors:[NSColor(hex:0xE4F2F8,alpha:0.88),NSColor(hex:0x7499AB,alpha:0.88),NSColor(hex:0x21404F,alpha:0.92)],angle:55,outline:0.85)
        vmClip(screen) { line(99,-67,91.5,-80,1.1,NSColor.white.withAlphaComponent(0.85)); line(84.5,-73,83,-79.5,0.6,NSColor.white.withAlphaComponent(0.35)) }
        // Mirror on the fairing, behind the screen.
        vmMetalLink(vmQ(84,65.5),vmQ(82,70.5),width:1.3,dark:true)
        vmFill(vmCurve([C(79,72.2),S(83.5,73.4),C(86,71.6),S(82.5,69.8)]),colors:[NSColor(hex:0x2C373F),NSColor(hex:0xA9BBC3)],angle:20,outline:0.5)
        if hyper {
            // Superbike extras: aero winglet under the nose, a vented side cut and a carbon tail cap.
            let wing=vmCurve([C(86,40),S(104,42.5),C(110,40),S(98,38.2),C(84,37.6)])
            vmFill(wing,colors:[NSColor(hex:0x2E3A43),NSColor(hex:0x0B1116)],angle:80,outline:0.7)
            line(88,-39.6,106,-41.2,0.6,NSColor(hex:0x9DB7C2))
            text("R",72,-47,10,NSColor(hex:0xF4F1E2),.heavy,center:true)
            vmClip(tail) { line(-9,-54,10,-56.4,3.0,NSColor(hex:0x14191C)) }
        }
        // Front end: inverted fork, mudguard hugging the tyre, brake and clip-ons.
        vmNearFork(top:fork,axle:frontAxle,offroad:false,upsideDown:true,kind:.sport)
        vmFender(axle:frontAxle,radius:radius,kind:.sport,paint:body)
        vmBrake(front:frontAxle,rear:rearAxle,radius:radius,kind:.sport,grip:grip,fork:fork,pivot:pivot)
        vmHandlebar(fork:fork,grip:grip,kind:.sport)
        // Footpeg plate and bolt-on rear sets.
        let peg=pt(rig.footPeg)
        vmMetalLink(NSPoint(x:peg.x-4,y:peg.y),NSPoint(x:peg.x+7,y:peg.y),width:3.0,dark:true)
        vmMetalLink(NSPoint(x:peg.x,y:peg.y),NSPoint(x:peg.x-6,y:peg.y+9),width:2.2,dark:false)
    }

    /// Round headlamp: chrome bucket on two fork brackets, glass with a reflector and a highlight.
    func vmHeadlamp(center c:(Double,Double),r:Double,fork:NSPoint) {
        let p=vmQ(c.0,c.1)
        line(fork.x+1,fork.y+1,p.x-r*0.6,p.y+r*0.2,1.8,NSColor(hex:0x20292E)); line(fork.x+1,fork.y+6,p.x-r*0.6,p.y+r*0.7,1.8,NSColor(hex:0x20292E))
        vmChrome(NSBezierPath(ovalIn:NSRect(x:p.x-r-1.6,y:p.y-r-1.6,width:(r+1.6)*2,height:(r+1.6)*2)),outline:0.8)
        vmFill(NSBezierPath(ovalIn:NSRect(x:p.x-r,y:p.y-r,width:r*2,height:r*2)),colors:[NSColor(hex:0xFFFFFA),NSColor(hex:0xDDD6A4),NSColor(hex:0x8E8650)],angle:60,outline:0.5)
        circle(p.x+r*0.12,p.y,r*0.45,NSColor(hex:0xFFFFF0)); circle(p.x+r*0.12,p.y,r*0.22,NSColor(hex:0xF1E9B8))
        let shine=NSBezierPath(); shine.appendArc(withCenter:p,radius:r*0.78,startAngle:200,endAngle:262,clockwise:false); shine.lineWidth=0.9; NSColor.white.withAlphaComponent(0.85).setStroke(); shine.stroke()
    }
    /// Air-cooled engine block: crankcase, finned barrel, head with valve cover and a side cover.
    func vmEngineBlock(kind:BikeKind,lean:Double) {
        let c=vmCurve([C(32,10),S(34,22),S(46,27),S(58,23),C(61,10),S(52,4),S(40,3.5)])
        vmFill(c,colors:[NSColor(hex:0xB4BEC1),NSColor(hex:0x5C6C74),NSColor(hex:0x263137)],angle:65,outline:0.9)
        vmCylinder(base:vmQ(49,25),width:16,height:19,angle:lean,fins:7,headColor:NSColor(hex:0x2A343A))
        vmClutchCover(vmQ(42,15),r:8.4)
        circle(vmQ(54,9).x,vmQ(54,9).y,2.6,NSColor(hex:0x20292E))
    }

    // MARK: Standard family: Street 125, Scrambler 400 and Volt E-8
    func drawStandardBike(kind:BikeKind,rig:VehicleRig,rearAxle:NSPoint,frontAxle:NSPoint,rotationRear:Double) {
        let u=rig.drawingUnitsPerMetre
        func pt(_ v:RideVector)->NSPoint { NSPoint(x:v.x*u,y:-v.y*u) }
        let pivot=pt(rig.swingPivot),fork=pt(rig.frontSuspensionMount),grip=pt(rig.grip)
        let radius=rig.wheelRadius*u
        let scr=kind == .scrambler,ev=kind == .electric
        let steel=NSColor(hex:0x2B343A)
        vmFarFork(top:fork,axle:frontAxle,offroad:scr,upsideDown:false)
        vmSwingarm(pivot:pivot,axle:rearAxle,kind:kind,far:true)
        if !ev { vmChain(rear:rearAxle,crank:NSPoint(x:43,y:-8),rotation:rotationRear) }
        // Exhaust runs behind the engine, so draw it before the block.
        if !ev {
            if scr {
                vmPipe([(58,40),(66,30),(65,18),(57,9),(44,7),(34,10)],width:4.0,core:NSColor(hex:0xC6CBC5))
                vmCapsule((38,12),(-2,32),8.0,6.8,colors:[NSColor(hex:0xEEF0EA),NSColor(hex:0x8E9A9F),NSColor(hex:0x52616A),NSColor(hex:0xC3CAC8)])
                vmCapsule((-1,31),(-4,33),6.9,6.4,colors:[NSColor(hex:0x353B40),NSColor(hex:0x101417)],outline:0.7)
                for i in 0..<6 { circle(34-Double(i)*6.0,-(14.4+Double(i)*2.7),0.7,NSColor(hex:0x2A3A40)) }
            } else {
                vmPipe([(58,40),(66,30),(65,18),(57,9),(44,7),(30,9)],width:4.2,core:NSColor(hex:0xC6CBC5))
                vmCapsule((32,11),(-5,19),9.0,8.2,colors:[NSColor(hex:0xF3F5EF),NSColor(hex:0xA3AFB3),NSColor(hex:0x5A6870),NSColor(hex:0xC9D0CF)])
                vmCapsule((-4,18.6),(-7,19.4),8.4,8.0,colors:[NSColor(hex:0x3A4046),NSColor(hex:0x111518)],outline:0.7)
            }
        }
        // Frame: single top tube, down tube, engine cradle and seat rails as real tubes.
        let seatY=rig.seat.y*u
        let head=NSPoint(x:fork.x-1,y:fork.y-1)
        vmTube(head,vmQ(38,seatY-5),3.6,steel)
        vmTube(head,vmQ(50,14),3.4,steel)
        vmTube(vmQ(50,14),vmQ(30,6),3.0,steel); vmTube(vmQ(30,6),pivot,3.0,steel)
        vmTube(vmQ(38,seatY-5),vmQ(-8,seatY+3),2.8,steel)
        vmTube(pivot,vmQ(8,seatY+1),2.6,steel)
        let lower=vmMix(rearAxle,pivot,0.5)
        vmShock(top:pt(rig.rearSuspensionMount),bottom:lower,offroad:false,reservoir:false,kind:kind)
        if ev {
            // Battery pack with cooling ribs and a mid-drive motor.
            let pack=vmCurve([C(33,9),S(33,38),C(50,43),S(66,40),C(68,12),S(50,6)])
            vmFill(pack,colors:[NSColor(hex:0x5B6872),NSColor(hex:0x242E35),NSColor(hex:0x151C21)],angle:75,outline:0.9)
            vmClip(pack) {
                for i in 0..<6 { line(37+Double(i)*5.2,-9,37+Double(i)*5.2,-41,0.8,NSColor(hex:0x0C1115,alpha:0.7)); line(38+Double(i)*5.2,-9,38+Double(i)*5.2,-41,0.4,NSColor(hex:0x73838D,alpha:0.7)) }
            }
            vmRounded(NSRect(x:37,y:-36,width:26,height:3),radius:1.2,colors:[NSColor(hex:0x7FF29B),NSColor(hex:0x2E9E52)])
            vmClutchCover(vmQ(42,14),r:7.6)
            let cable=NSBezierPath(); cable.move(to:vmQ(40,20)); cable.curve(to:vmQ(30,34),controlPoint1:vmQ(26,22),controlPoint2:vmQ(24,30)); cable.lineWidth=2.6; NSColor(hex:0x11171B).setStroke(); cable.stroke(); cable.lineWidth=1.1; NSColor(hex:0xFF9A3C).setStroke(); cable.stroke()
        } else {
            vmEngineBlock(kind:kind,lean:scr ? 6 : 14)
        }
        vmSwingarm(pivot:pivot,axle:rearAxle,kind:kind,far:false)
        // Side cover under the seat, with the badge.
        let side=vmCurve([C(8,27),S(10,38),S(24,41),C(36,37),S(35,26),S(22,20)])
        vmPanel(side,body,gloss:0.3)
        text(scr ? "400" : (ev ? "E-8" : "125"),22,-31,scr || ev ? 5.2 : 6,vmTone(body,-0.65),.bold,center:true)
        // Seat and short tail.
        if scr {
            let seat=vmCurve([C(-9,47),S(0,51.5),S(30,51.5),C(46,50),S(45,45.5),S(20,44),S(-8,43.5)])
            vmFill(seat,colors:[NSColor(hex:0xA48463),NSColor(hex:0x4A3D2E)],angle:85,outline:0.8)
            for i in 0..<9 { line(-4+Double(i)*5.2,-50.6,-3+Double(i)*5.2,-45,0.55,NSColor(hex:0xC9AC84,alpha:0.7)) }
        } else {
            let seat=vmCurve([C(-4,47),S(8,50.5),S(30,50.5),C(44,49),S(43,45),S(20,44.5),S(-4,44)])
            vmFill(seat,colors:[NSColor(hex:0x58646D),NSColor(hex:0x151D22)],angle:85,outline:0.8)
            line(0,-49.6,32,-49.8,0.5,NSColor(hex:0x98A4AB,alpha:0.7))
        }
        let tail=vmCurve([C(-18,30),S(-14,38),S(-6,43),C(8,44),S(2,38),S(-6,33)])
        vmPanel(tail,body,gloss:0.3,outline:0.7)
        vmTailLight(-17,38,w:5,h:3); vmIndicator(-14,29)
        vmMetalLink(vmQ(8,46),vmQ(-12,42),width:2.2,dark:false)   // grab rail
        // Tank: a teardrop sitting on the top tube, with a knee pad and filler cap.
        let tank = scr
            ? vmCurve([C(36,48),S(38,56),S(49,62),S(64,63),C(76,59),S(73,52),S(60,46),S(46,45)])
            : vmCurve([C(35,49),S(37,57),S(50,63.5),S(66,64.5),C(79,60),S(75,52),S(60,46.5),S(45,45.5)])
        if !ev {
            vmPanel(tank,body,gloss:0.55)
            vmClip(tank) { line(40,-52,76,-55,3.0,vmTone(body,-0.5)); line(42,-60,68,-62.5,0.9,NSColor.white.withAlphaComponent(0.6)) }
            vmRounded(NSRect(x:55,y:-66.4,width:9,height:3.0),radius:1.4,colors:[NSColor(hex:0xE3E7E0),NSColor(hex:0x667880)])
        } else {
            // A slim beam over the pack instead of a fuel tank.
            vmPanel(vmCurve([C(24,50),S(34,56),S(56,60),C(77,58),S(70,51),S(40,47)]),body,gloss:0.5)
        }
        // Front end.
        vmNearFork(top:fork,axle:frontAxle,offroad:scr,upsideDown:false,kind:kind)
        vmFender(axle:frontAxle,radius:radius,kind:kind,paint:body)
        vmBrake(front:frontAxle,rear:rearAxle,radius:radius,kind:kind,grip:grip,fork:fork,pivot:pivot)
        vmHandlebar(fork:fork,grip:grip,kind:kind)
        vmHeadlamp(center:(fork.x+9,-(fork.y)+0.5-2.5),r:ev ? 5.2 : 6.2,fork:NSPoint(x:fork.x,y:fork.y))
        // Round clock above the lamp.
        let clock=NSPoint(x:fork.x-1,y:fork.y-11)
        vmFill(NSBezierPath(ovalIn:NSRect(x:clock.x-4.2,y:clock.y-4.2,width:8.4,height:8.4)),colors:[NSColor(hex:0x56626A),NSColor(hex:0x151C21)],angle:60,outline:0.6)
        circle(clock.x,clock.y,2.7,NSColor(hex:0xF4F1DE)); line(clock.x,clock.y,clock.x+1.8,clock.y-1.4,0.5,NSColor(hex:0xC63D2C))
        let peg=pt(rig.footPeg)
        vmMetalLink(NSPoint(x:peg.x-4,y:peg.y),NSPoint(x:peg.x+7,y:peg.y),width:3.0,dark:true)
    }

    // MARK: Off-road family: Enduro 250 and Trial 200
    func drawOffroadBike(kind:BikeKind,rig:VehicleRig,rearAxle:NSPoint,frontAxle:NSPoint,rotationRear:Double) {
        let u=rig.drawingUnitsPerMetre
        func pt(_ v:RideVector)->NSPoint { NSPoint(x:v.x*u,y:-v.y*u) }
        let pivot=pt(rig.swingPivot),fork=pt(rig.frontSuspensionMount),grip=pt(rig.grip)
        let radius=rig.wheelRadius*u
        let trial = kind == .trials
        let steel=NSColor(hex:0x2B343A)
        let seatY=rig.seat.y*u
        let canEnd = trial ? 40.0 : 46.0
        vmFarFork(top:fork,axle:frontAxle,offroad:true,upsideDown:false)
        vmSwingarm(pivot:pivot,axle:rearAxle,kind:kind,far:true)
        vmChain(rear:rearAxle,crank:NSPoint(x:43,y:-8),rotation:rotationRear)
        // Expansion chamber and silencer: header round the cylinder, a bulge ahead of the engine, then a long can to the tail.
        vmPipe([(60,44),(70,34),(68,20),(58,12),(48,12)],width:3.8,core:NSColor(hex:0xC6CBC5))
        vmCapsule((50,13),(26,24),10.5,8.0,colors:[NSColor(hex:0xEEF0EA),NSColor(hex:0x939FA4),NSColor(hex:0x556169),NSColor(hex:0xC2C9C8)])
        vmCapsule((28,23),(-8,canEnd),8.2,7.0,colors:[NSColor(hex:0xF4F6F0),NSColor(hex:0x8E9AA0),NSColor(hex:0x4F5D65),NSColor(hex:0xC3CAC9)])
        vmCapsule((-7,canEnd-0.8),(-10,canEnd+1),7.2,6.8,colors:[NSColor(hex:0x353B40),NSColor(hex:0x101417)],outline:0.7)
        // Frame: central spine, twin down tubes into the cradle, and the subframe.
        let head=NSPoint(x:fork.x-1,y:fork.y-1)
        vmTube(head,vmQ(40,seatY-6),3.8,steel)
        vmTube(head,vmQ(52,22),3.6,steel); vmTube(vmQ(52,22),vmQ(34,8),3.2,steel); vmTube(vmQ(34,8),pivot,3.0,steel)
        vmTube(vmQ(40,seatY-6),vmQ(-8,seatY-2),3.0,steel); vmTube(pivot,vmQ(10,seatY-2),2.8,steel)
        let lower=vmMix(rearAxle,pivot,0.5)
        vmShock(top:pt(rig.rearSuspensionMount),bottom:lower,offroad:true,reservoir:!trial,kind:kind)
        // Engine: single, liquid-cooled, with its radiator ahead of the cylinder.
        let c=vmCurve([C(35,9),S(37,21),S(48,26),S(60,21),C(62,10),S(52,4),S(42,4)])
        vmFill(c,colors:[NSColor(hex:0xB4BEC1),NSColor(hex:0x5C6C74),NSColor(hex:0x263137)],angle:65,outline:0.9)
        vmCylinder(base:vmQ(51,24),width:16,height:16,angle:12,fins:0,headColor:NSColor(hex:0x2C373E))
        vmClutchCover(vmQ(44,15),r:7.6)
        vmSwingarm(pivot:pivot,axle:rearAxle,kind:kind,far:false)
        // Skid plate.
        vmFill(vmCurve([C(34,6),S(48,2.4),C(63,5),S(60,8),S(40,9)]),colors:[NSColor(hex:0xC4CACB),NSColor(hex:0x58666D)],angle:80,outline:0.7)
        // Rear fender and tail plastics rising to the seat.
        let tail=vmCurve([C(-20,47),S(-12,55),S(6,58.5),S(24,56),C(40,55),S(30,50),S(10,49),S(-10,48)])
        vmPanel(tail,body,gloss:0.35)
        vmPanel(vmCurve([C(-26,34),S(-22,43),S(-14,48),C(-8,46),S(-14,40),S(-20,35)]),body,gloss:0.25,outline:0.7)
        vmTailLight(-23,46,w:4,h:2.4)
        // Seat: long and flat, grippy.
        let seat=vmCurve([C(-10,59),S(8,62),S(30,59.5),C(48,58.5),S(47,54.5),S(26,55),S(2,56.5),S(-9,56)])
        vmFill(seat,colors:[NSColor(hex:0x4D5A63),NSColor(hex:0x151D22)],angle:85,outline:0.8)
        // Tank-and-shroud: one plastic sweep from the seat to the steering head.
        let shroud = trial
            ? vmCurve([C(34,58),S(40,64),S(56,67),C(70,64),S(66,57),S(50,54),S(38,55)])
            : vmCurve([C(40,58),S(45,66),S(62,72),S(80,74),C(87,70),S(82,60),S(70,52),S(58,45),S(48,48)])
        vmPanel(shroud,body,gloss:0.45)
        vmClip(shroud) { line(46,-62,84,-68,2.6,vmTone(body,-0.5)); line(48,-68,76,-72,0.9,NSColor.white.withAlphaComponent(0.6)) }
        if !trial {
            // Radiator shroud number panel.
            let panel=vmCurve([C(52,58),S(60,64),S(70,62),C(74,52),S(66,46),S(56,48)])
            vmFill(panel,colors:[NSColor(hex:0xFFFFF4),NSColor(hex:0xBCC6C0)],angle:70,outline:0.6)
            text("7",63,-55,9,NSColor(hex:0x2E434A),.heavy,center:true)
        }
        // Front end: gold stanchions, high fender and the number plate.
        vmNearFork(top:fork,axle:frontAxle,offroad:true,upsideDown:false,kind:kind)
        vmFender(axle:frontAxle,radius:radius,kind:kind,paint:body)
        vmBrake(front:frontAxle,rear:rearAxle,radius:radius,kind:kind,grip:grip,fork:fork,pivot:pivot)
        vmHandlebar(fork:fork,grip:grip,kind:kind)
        let plate=vmCurve([C(86,84),S(96,86),C(103,78),S(101,66),C(92,62),S(85,72)])
        vmFill(plate,colors:[NSColor(hex:0xFFFFF2),NSColor(hex:0xB9C5BE)],angle:70,outline:0.8)
        text(trial ? "2" : "7",94,-79,8.5,NSColor(hex:0x2C4648),.heavy,center:true)
        let peg=pt(rig.footPeg)
        vmMetalLink(NSPoint(x:peg.x-5,y:peg.y),NSPoint(x:peg.x+8,y:peg.y),width:3.2,dark:true)
    }

    /// A fender as a crescent that follows the wheel: `from`/`to` are angles in degrees (y-up, 0 = forward, 90 = top).
    func vmFenderArc(center:NSPoint,inner:Double,outer:Double,from a0:Double,to a1:Double,valance:Double,paint:NSColor) {
        func P(_ r:Double,_ a:Double)->DP { let t=a*Double.pi/180; return S(center.x+cos(t)*r,-(center.y-sin(t)*r)) }
        // center is in screen space; vmCurve expects y-up so convert.
        var pts:[DP]=[]
        let n=8
        for i in 0...n { let a=a0+(a1-a0)*Double(i)/Double(n); pts.append(P(outer,a)) }
        let end=pts.removeLast(); pts.append((end.0,end.1,true))
        let tip=P(outer-valance,a1+4); pts.append(S(tip.0,tip.1))
        for i in 0...n { let a=a1-(a1-a0)*Double(i)/Double(n); pts.append(P(inner,a)) }
        vmPanel(vmCurve(pts),paint,gloss:0.45,outline:0.85)
    }

    // MARK: Cruiser 750
    func drawCruiserBike(rig:VehicleRig,rearAxle:NSPoint,frontAxle:NSPoint,rotationRear:Double) {
        let u=rig.drawingUnitsPerMetre
        func pt(_ v:RideVector)->NSPoint { NSPoint(x:v.x*u,y:-v.y*u) }
        let pivot=pt(rig.swingPivot),fork=pt(rig.frontSuspensionMount),grip=pt(rig.grip)
        let radius=rig.wheelRadius*u
        let steel=NSColor(hex:0x2B343A),leather=[NSColor(hex:0x9A6C48),NSColor(hex:0x4A2E1B)]
        vmFarFork(top:fork,axle:frontAxle,offroad:false,upsideDown:false)
        vmSwingarm(pivot:pivot,axle:rearAxle,kind:.cruiser,far:true)
        vmChain(rear:rearAxle,crank:NSPoint(x:43,y:-8),rotation:rotationRear)
        // Twin drag pipes, one above the other, ending in long chrome mufflers.
        vmPipe([(66,30),(72,20),(66,9),(50,7.5),(34,10)],width:4.2,core:NSColor(hex:0xDDE2E0))
        vmPipe([(60,24),(64,14),(58,5),(44,4.5),(30,6.5)],width:3.8,core:NSColor(hex:0xCDD3D1))
        vmCapsule((38,13),(-17,21),9.6,8.4,colors:[NSColor(hex:0xFFFFFF),NSColor(hex:0xB4BFC3),NSColor(hex:0x5D6D75),NSColor(hex:0xE0E6E5)])
        vmCapsule((34,6.6),(-17,11.5),8.6,7.8,colors:[NSColor(hex:0xFFFFFF),NSColor(hex:0xAEB9BD),NSColor(hex:0x566870),NSColor(hex:0xDDE3E2)])
        // Frame: long low cradle and rigid-style seat rails.
        let head=NSPoint(x:fork.x-1,y:fork.y-1)
        vmTube(head,vmQ(36,33),3.6,steel); vmTube(head,vmQ(52,16),3.6,steel)
        vmTube(vmQ(52,16),vmQ(32,5),3.2,steel); vmTube(vmQ(32,5),pivot,3.0,steel)
        vmTube(vmQ(36,33),vmQ(-8,36),3.0,steel); vmTube(pivot,vmQ(6,34),2.8,steel)
        let lower=vmMix(rearAxle,pivot,0.5)
        vmShock(top:pt(rig.rearSuspensionMount),bottom:lower,offroad:false,reservoir:false,kind:.cruiser)
        // V-twin: two finned cylinders at 45 degrees over a chrome-trimmed crankcase.
        let c=vmCurve([C(32,8),S(33,21),S(48,27),S(63,21),C(66,8),S(52,3)])
        vmFill(c,colors:[NSColor(hex:0xC6CFD1),NSColor(hex:0x66767E),NSColor(hex:0x263137)],angle:65,outline:0.9)
        vmCylinder(base:vmQ(46,24),width:15,height:19,angle:-38,fins:6,headColor:NSColor(hex:0x2B353B))
        vmCylinder(base:vmQ(51,24),width:15,height:19,angle:32,fins:6,headColor:NSColor(hex:0x2B353B))
        vmClutchCover(vmQ(41,13),r:8.2)
        vmChrome(NSBezierPath(ovalIn:NSRect(x:57.5,y:-39,width:16,height:16)))
        vmFill(NSBezierPath(ovalIn:NSRect(x:60.5,y:-36,width:10,height:10)),colors:[NSColor(hex:0x6E7C84),NSColor(hex:0xC4CDCE)],outline:0.4)
        vmSwingarm(pivot:pivot,axle:rearAxle,kind:.cruiser,far:false)
        // Deep rear fender, saddle, and a leather bag hung from rails.
        vmFenderArc(center:rearAxle,inner:27.5,outer:31.5,from:10,to:150,valance:5,paint:body)
        let bag=vmCurve([C(-12,36),S(8,37.2),C(26,35),S(27,26),C(18,19),S(4,18.4),C(-8,21),S(-13,28)])
        vmFill(bag,colors:leather,angle:80,outline:0.8)
        vmClip(bag) {
            for x in [-1.0,17.0] { line(x,-37,x,-19,0.7,NSColor(hex:0xD9B88A,alpha:0.8)); vmRounded(NSRect(x:x-2.2,y:-30.5,width:4.4,height:4),radius:1,colors:[NSColor(hex:0xE6D8B0),NSColor(hex:0x8E7B55)]) }
            line(-12,-36,26,-35,0.6,NSColor(hex:0xE2C698,alpha:0.7))
        }
        let seat=vmCurve([C(-2,40),S(8,37.4),S(22,34.6),S(36,36),C(47,39.5),S(36,41),S(16,41.4)])
        vmFill(seat,colors:[NSColor(hex:0x6A4A33),NSColor(hex:0x22140B)],angle:85,outline:0.8)
        line(2,-39,40,-38.6,0.5,NSColor(hex:0xB38B66,alpha:0.7))
        // Sissy bar and backrest pad, tail lamp.
        vmMetalLink(vmQ(-6,40),vmQ(-12,64),width:1.7,dark:false); vmMetalLink(vmQ(4,40),vmQ(-3,59),width:1.4,dark:false)
        vmFill(vmCurve([C(-20,63),S(-12,66),C(-5,62),S(-9,57.5)]),colors:leather,angle:80,outline:0.7)
        vmTailLight(-27,22,w:5,h:3); vmIndicator(-25,15)
        // Tank: a big teardrop with a chrome strip, dash on top.
        let tank=vmCurve([C(27,41),S(29,49),S(42,56.5),S(64,59),S(80,55.5),C(84,48),S(74,40.5),S(54,37.5),S(36,37.8)])
        vmPanel(tank,body,gloss:0.6)
        vmClip(tank) { line(32,-47,82,-50,1.6,NSColor(hex:0xF1F4F0)); line(34,-44,80,-45.5,0.6,NSColor(hex:0x2B353B)) }
        vmRounded(NSRect(x:52,y:-62,width:10,height:3.2),radius:1.4,colors:[NSColor(hex:0xE3E7E0),NSColor(hex:0x667880)])
        // Front end: valanced fender, chrome nacelle, passing lamps.
        vmNearFork(top:fork,axle:frontAxle,offroad:false,upsideDown:false,kind:.cruiser)
        vmFenderArc(center:frontAxle,inner:radius+2.6,outer:radius+5.8,from:14,to:142,valance:5,paint:body)
        vmBrake(front:frontAxle,rear:rearAxle,radius:radius,kind:.cruiser,grip:grip,fork:fork,pivot:pivot)
        vmHandlebar(fork:fork,grip:grip,kind:.cruiser)
        vmHeadlamp(center:(fork.x+10,-(fork.y)+1),r:7.0,fork:NSPoint(x:fork.x,y:fork.y))
        for y in [-48.0,-42.0] { vmFill(NSBezierPath(ovalIn:NSRect(x:fork.x+4,y:y-2.8,width:5.6,height:5.6)),colors:[NSColor(hex:0xFFF7D2),NSColor(hex:0x9F9265)],outline:0.4) }
        // Chrome floorboard.
        let peg=pt(rig.footPeg)
        vmMetalLink(NSPoint(x:peg.x-8,y:peg.y),NSPoint(x:peg.x+9,y:peg.y),width:3.6,dark:false)
    }
}
