import Cocoa

/// Assembles a vehicle: physics-driven mechanics from Mechanics.swift plus the designed bodywork baked from Design/bikes.js.
extension RideRenderer {
    private static let roles: [String: [Int]] = [
        "metal": [0xC9D1D3, 0x7C8A91, 0x34414A], "metalLt": [0xEDF0EC, 0xA3AFB3, 0x5A6870], "metalDk": [0x8E9BA1, 0x4A585F, 0x1E282D],
        "steel": [0x4A565D], "dark": [0x59666E, 0x1B242A], "black": [0x363E44, 0x0E1316], "chrome": [0xF3F5EF, 0xA3AFB3, 0x5A6870],
        "seat": [0x5A666F, 0x1B242A], "tan": [0xB08A5F, 0x4A3D2E], "lamp": [0xFFF7D6, 0xE8D79A], "white": [0xFFFFFF, 0xD7DDE0], "cream": [0xF4F1DE, 0xCFC7A6],
        "red": [0xFF6A55, 0xB2271B], "green": [0x7FF29B, 0x2E9E52], "orange": [0xFFB04A, 0xE0742A], "glass": [0xDDF2FA, 0x7FB5CC]]
    /// The colour a role is drawn with (index 1 when there is a mid tone, else the only one).
    func roleColor(_ role: String) -> NSColor {
        if role == "paint" { return body }
        if role == "paintDk" { return darken(body, 0.45) }
        let c = RideRenderer.roles[role] ?? [0x888888]
        return NSColor(hex: c[min(1, c.count - 1)])
    }
    private func drawLayers(_ layers: [ShapeLayer], z: Int) {
        for l in layers where l.z == z {
            switch l.t {
            case "f": cel(bakedPath(l.d), roleColor(l.role), outline: l.w)
            case "s": tubeStroke(bakedPath(l.d), l.w, roleColor(l.role))
            case "c": cel(disc(NSPoint(x: l.x, y: -l.y), l.r), roleColor(l.role), outline: 0.7, depth: 0.6)
            case "l": let p = bakedPath(l.d); stroke(p, l.w, (l.role == "paintDk" ? darken(body, 0.4) : lighten(roleColor(l.role), 0.2)).withAlphaComponent(l.a))
            case "x": text(l.str, l.x, -l.y - l.r * 0.62, l.r, roleColor(l.role), .bold, center: true)
            default: break
            }
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
