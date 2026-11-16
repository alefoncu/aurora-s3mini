import Cocoa

/// Assembles a vehicle: physics-driven mechanics from Mechanics.swift plus the designed bodywork baked from Design/bikes.js.
extension RideRenderer {
    private func artColor(_ c: ArtColor) -> NSColor {
        guard c.paint else { return NSColor(hex: c.rgb) }
        return c.tone >= 0 ? lighten(body, c.tone) : darken(body, -c.tone)
    }
    private func drawLayers(_ layers: [ArtLayer], z: Int) {
        for l in layers where l.z == z {
            if !l.text.isEmpty { text(l.text, l.tx, l.ty - l.size * 0.62, l.size, artColor(l.stops[0].color), .bold, center: true); continue }
            let path = bakedPath(l.d)
            if l.stops.count == 1 { artColor(l.stops[0].color).withAlphaComponent(l.op).setFill(); path.fill() }
            else if l.stops.count > 1, let g = NSGradient(colors: l.stops.map { artColor($0.color).withAlphaComponent(l.op) }, atLocations: l.stops.map { CGFloat($0.at) }, colorSpace: .sRGB) { g.draw(in: path, angle: 90) }
            if let s = l.stroke { path.lineWidth = l.sw; path.lineCapStyle = .round; path.lineJoinStyle = .round; artColor(s).withAlphaComponent(l.op).setStroke(); path.stroke() }
        }
    }

    func drawVehicle(kind: BikeKind, rearAxle: NSPoint, frontAxle: NSPoint, frontCompression: Double, rearCompression: Double, rotationRear: Double, rotationFront: Double, pedalPhase: Double, time: Double) {
        let rig = kind.rig, u = rig.drawingUnitsPerMetre, radius = rig.wheelRadius * u
        func pt(_ v: RideVector) -> NSPoint { NSPoint(x: v.x * u, y: -v.y * u) }
        let pivot = pt(rig.swingPivot), fork = pt(rig.frontSuspensionMount), grip = pt(rig.grip), layers = BikeShapes.layers(kind)
        drawWheel(at: rearAxle, r: radius, rotation: rotationRear, kind: kind, front: false)
        drawWheel(at: frontAxle, r: radius, rotation: rotationFront, kind: kind, front: true)
        drawFork(top: fork, axle: frontAxle, far: true, kind: kind)
        if kind != .bmx {
            drawSwingarm(pivot: pivot, axle: rearAxle, kind: kind, far: true)
            drawShock(top: pt(rig.rearSuspensionMount), bottom: NSPoint(x: rearAxle.x + (pivot.x - rearAxle.x) * 0.48, y: rearAxle.y + (pivot.y - rearAxle.y) * 0.48), kind: kind)
        }
        drawLayers(layers, z: 0)
        if kind != .bmx { drawSwingarm(pivot: pivot, axle: rearAxle, kind: kind, far: false) }
        drawLayers(layers, z: 1)
        drawFork(top: fork, axle: frontAxle, far: false, kind: kind)
        drawLayers(layers, z: 2)
        drawBrakes(front: frontAxle, rear: rearAxle, radius: radius, kind: kind, forkTop: fork, grip: grip, pivot: pivot)
        drawBars(forkTop: fork, axle: frontAxle, grip: grip, kind: kind)
        drawLayers(layers, z: 3)
        drawPeg(at: pt(rig.footPeg))
        if kind == .bmx { drawCranks(rig: rig, u: u, rear: rearAxle, phase: pedalPhase) }
    }

    /// BMX drivetrain: chainring, chain to the rear cog, cranks and platform pedals that follow the rider's feet.
    private func drawCranks(rig: VehicleRig, u: Double, rear: NSPoint, phase: Double) {
        let crank = NSPoint(x: rig.crank.x * u, y: -rig.crank.y * u)
        let top = NSBezierPath(); top.move(to: NSPoint(x: crank.x, y: crank.y - 7.4)); top.line(to: NSPoint(x: rear.x, y: rear.y - 3.8))
        let bot = NSBezierPath(); bot.move(to: NSPoint(x: crank.x, y: crank.y + 7.4)); bot.line(to: NSPoint(x: rear.x, y: rear.y + 3.8))
        stroke(top, 1.6, inkColor); stroke(top, 0.9, NSColor(hex: 0x8C98A0)); stroke(bot, 1.6, inkColor); stroke(bot, 0.9, NSColor(hex: 0x8C98A0))
        cel(disc(rear, 4.3), NSColor(hex: 0x8C98A0), outline: 0.7, depth: 0.5)
        cel(disc(crank, 7.8), NSColor(hex: 0x9AA6AB), outline: 0.8, depth: 0.7)
        let length = 0.12 * u
        for side in [-1.0, 1.0] {
            let p = NSPoint(x: crank.x + cos(phase) * length * side, y: crank.y - sin(phase) * length * side)
            celCapsule(crank, p, 1.7, 1.5, NSColor(hex: side < 0 ? 0x56646D : 0xC7CED1), outline: 0.7)
            cel(NSBezierPath(roundedRect: NSRect(x: p.x - 5.5, y: p.y - 1.6, width: 11, height: 3.2), xRadius: 1, yRadius: 1), NSColor(hex: 0x39454D), outline: 0.7, depth: 0.5)
        }
        cel(disc(crank, 2.4), NSColor(hex: 0xD6DCDE), outline: 0.6, depth: 0.4)
    }
}
