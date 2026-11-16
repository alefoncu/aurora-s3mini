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
}
