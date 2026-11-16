import Cocoa

/// Draws the bodywork designed in Design/bikes.js (baked into BikeShapes.swift) on the real bike geometry.
/// The mechanical parts (wheels, forks, swingarm, shock, brakes, bars, pegs) stay with the physics-driven helpers.
extension RideRenderer {
    private static let roleColors:[String:[Int]] = [
        "metal":[0xC9D1D3,0x7C8A91,0x34414A],"metalLt":[0xEDF0EC,0xA3AFB3,0x5A6870],"metalDk":[0x8E9BA1,0x4A585F,0x1E282D],
        "steel":[0x4A565D,0x2B343A],"dark":[0x59666E,0x1B242A],"black":[0x363E44,0x0E1316],"chrome":[0xF3F5EF,0xA3AFB3,0x5A6870],
        "seat":[0x5A666F,0x151D22],"tan":[0xB08A5F,0x4A3D2E],"tanLt":[0xE4C9A2],"lamp":[0xFFF7D6,0xE8D79A],"white":[0xFFFFFF,0xD7DDE0],
        "cream":[0xF4F1DE,0xCFC7A6],"red":[0xFF6A55,0xB2271B],"green":[0x7FF29B,0x2E9E52],"orange":[0xFFB04A,0xE0742A]]

    private func shapeColors(_ role:String)->[NSColor] {
        if role == "paint" { return [vmTone(body,0.3),body,vmTone(body,-0.32)] }
        if role == "paintDk" { return [vmTone(body,-0.4),vmTone(body,-0.5)] }
        return (RideRenderer.roleColors[role] ?? [0x888888,0x444444]).map { NSColor(hex:$0) }
    }
    private func shapeFlat(_ role:String)->NSColor { let c=shapeColors(role); return c[min(1,c.count-1)] }

    /// Parses the absolute M/L/C/Z path data baked by Design/bake.mjs into a y-flipped NSBezierPath.
    func shapePath(_ d:String)->NSBezierPath {
        let path=NSBezierPath()
        var nums:[Double]=[],cmd:Character=" ",token=""
        func flush() { if !token.isEmpty { nums.append(Double(token) ?? 0); token="" } }
        func apply() {
            switch cmd {
            case "M": if nums.count >= 2 { path.move(to:NSPoint(x:nums[0],y:-nums[1])) }
            case "L": var i=0; while i+1 < nums.count { path.line(to:NSPoint(x:nums[i],y:-nums[i+1])); i+=2 }
            case "C": var i=0; while i+5 < nums.count { path.curve(to:NSPoint(x:nums[i+4],y:-nums[i+5]),controlPoint1:NSPoint(x:nums[i],y:-nums[i+1]),controlPoint2:NSPoint(x:nums[i+2],y:-nums[i+3])); i+=6 }
            case "Z": path.close()
            default: break
            }
            nums.removeAll()
        }
        for ch in d {
            if ch.isLetter { flush(); apply(); cmd=ch; if ch == "Z" { apply(); cmd=" " } }
            else if ch == " " { flush() }
            else { token.append(ch) }
        }
        flush(); apply()
        return path
    }

    private func drawShapeLayer(_ l:ShapeLayer) {
        switch l.t {
        case "f":
            let p=shapePath(l.d)
            if l.role == "paint" { vmPanel(p,body,gloss:0.34,outline:l.w) }
            else { vmFill(p,colors:shapeColors(l.role),angle:85,outline:l.w) }
        case "s":
            let p=shapePath(l.d),c=shapeFlat(l.role)
            p.lineCapStyle = .round; p.lineJoinStyle = .round
            p.lineWidth=l.w+1.7; NSColor(hex:0x12191D).setStroke(); p.stroke()
            p.lineWidth=l.w; c.setStroke(); p.stroke()
            p.lineWidth=max(0.5,l.w*0.22); vmTone(c,0.45).withAlphaComponent(0.8).setStroke()
            if let hi=p.copy() as? NSBezierPath { hi.transform(using:AffineTransform(translationByX:-l.w*0.15,byY:-l.w*0.2)); hi.stroke() }
        case "c":
            let c=NSBezierPath(ovalIn:NSRect(x:l.x-l.r,y:-l.y-l.r,width:l.r*2,height:l.r*2))
            vmFill(c,colors:shapeColors(l.role),angle:85,outline:0.6)
        case "l":
            let p=shapePath(l.d); p.lineCapStyle = .round
            p.lineWidth=l.w; (l.role == "paintDk" ? shapeColors("paintDk")[0] : shapeFlat(l.role)).withAlphaComponent(l.a).setStroke(); p.stroke()
        case "x":
            text(l.str,l.x,-l.y,l.r,shapeFlat(l.role),.bold,center:true)
        default: break
        }
    }
    private func drawShapeLayers(_ layers:[ShapeLayer],z:Int) { for l in layers where l.z == z { drawShapeLayer(l) } }

    func hasShapedBody(_ kind:BikeKind)->Bool { !BikeShapes.layers(kind).isEmpty }

    func drawShapedBike(kind:BikeKind,rig:VehicleRig,rearAxle:NSPoint,frontAxle:NSPoint,rotationRear:Double) {
        let u=rig.drawingUnitsPerMetre,layers=BikeShapes.layers(kind)
        func pt(_ v:RideVector)->NSPoint { NSPoint(x:v.x*u,y:-v.y*u) }
        let pivot=pt(rig.swingPivot),fork=pt(rig.frontSuspensionMount),grip=pt(rig.grip)
        let radius=rig.wheelRadius*u
        let offroad=(kind == .motocross || kind == .trials || kind == .scrambler)
        vmFarFork(top:fork,axle:frontAxle,offroad:offroad,upsideDown:false)
        vmSwingarm(pivot:pivot,axle:rearAxle,kind:kind,far:true)
        if kind != .scooter && kind != .electric { vmChain(rear:rearAxle,crank:NSPoint(x:43,y:-8),rotation:rotationRear) }
        let lower=vmMix(rearAxle,pivot,0.48)
        vmShock(top:pt(rig.rearSuspensionMount),bottom:lower,offroad:offroad,reservoir:kind == .motocross,kind:kind)
        drawShapeLayers(layers,z:0)
        vmSwingarm(pivot:pivot,axle:rearAxle,kind:kind,far:false)
        drawShapeLayers(layers,z:1)
        vmNearFork(top:fork,axle:frontAxle,offroad:offroad,upsideDown:false,kind:kind)
        drawShapeLayers(layers,z:2)
        vmBrake(front:frontAxle,rear:rearAxle,radius:radius,kind:kind,grip:grip,fork:fork,pivot:pivot)
        vmHandlebar(fork:fork,grip:grip,kind:kind)
        drawShapeLayers(layers,z:3)
        let peg=pt(rig.footPeg)
        vmMetalLink(NSPoint(x:peg.x-4,y:peg.y),NSPoint(x:peg.x+7,y:peg.y),width:3.0,dark:true)
    }
}
