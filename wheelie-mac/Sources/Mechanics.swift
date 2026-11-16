import Cocoa

enum WheelStyle { case wire, cast, knobby, bmx }

extension BikeKind {
    var wheelStyle: WheelStyle {
        switch self {
        case .sport, .hyperbike, .electric, .scooter: return .cast
        case .motocross, .trials, .scrambler: return .knobby
        case .bmx: return .bmx
        default: return .wire
        }
    }
    var invertedFork: Bool { self == .sport || self == .hyperbike }
    var hasRearDrum: Bool { self == .commuter || self == .scooter || self == .cruiser }
}

/// The moving, physics-driven parts of every vehicle: wheels, fork, swingarm, shock, brakes, bars and pegs.
extension RideRenderer {
    // MARK: Wheels
    func drawWheel(at c: NSPoint, r: Double, rotation: Double, kind: BikeKind, front: Bool) {
        let style = kind.wheelStyle, blur = wheelBlur
        let rimOut = r * 0.76, rimIn = r * 0.70
        // Tyre: a dark ring with a lighter sidewall line and tread.
        cel(annulus(c, r, rimOut), NSColor(hex: 0x2A333A), outline: 0.9, depth: 1.5, shine: false)
        stroke(NSBezierPath(ovalIn: NSRect(x: c.x - (r - 2.6), y: c.y - (r - 2.6), width: (r - 2.6) * 2, height: (r - 2.6) * 2)), 0.6, NSColor(hex: 0x5B6870, alpha: 0.7))
        let knobs = style == .knobby ? 34 : 0
        if knobs > 0 {
            for i in 0..<knobs {
                let a = Double(i) * 2 * .pi / Double(knobs) + rotation
                let p0 = NSPoint(x: c.x + cos(a) * (r - 2.2), y: c.y + sin(a) * (r - 2.2)), p1 = NSPoint(x: c.x + cos(a) * (r + 1.1), y: c.y + sin(a) * (r + 1.1))
                let k = NSBezierPath(); k.move(to: p0); k.line(to: p1); stroke(k, 1.7, NSColor(hex: 0x131A1F), cap: .butt)
            }
        } else {
            for i in 0..<30 {
                let a = Double(i) * 2 * .pi / 30 + rotation
                let k = NSBezierPath(); k.move(to: NSPoint(x: c.x + cos(a) * (r - 1.3), y: c.y + sin(a) * (r - 1.3))); k.line(to: NSPoint(x: c.x + cos(a + 0.09) * (r - 1.3), y: c.y + sin(a + 0.09) * (r - 1.3)))
                stroke(k, 0.9, NSColor(hex: 0x56626A, alpha: 0.7))
            }
        }
        // Rim and the dark void behind the spokes.
        cel(disc(c, rimOut), NSColor(hex: 0x1F2A31), outline: 0, shine: false)
        let rim = annulus(c, rimOut, rimIn); cel(rim, NSColor(hex: 0xC9D1D4), outline: 0.7, depth: 0.6)
        let hubR = r * 0.14
        if style == .cast {
            for i in 0..<5 {
                let a = Double(i) * 2 * .pi / 5 + rotation
                func at(_ rad: Double, _ da: Double) -> NSPoint { NSPoint(x: c.x + cos(a + da) * rad, y: c.y + sin(a + da) * rad) }
                let sp = smoothPath([at(hubR, -0.42), at(rimIn * 0.62, -0.20), at(rimIn, -0.115), at(rimIn, 0.115), at(rimIn * 0.62, 0.20), at(hubR, 0.42)], corners: [2, 3])
                cel(sp, NSColor(hex: 0x56646D), outline: 0.7, depth: 0.7)
            }
        } else {
            let n = style == .bmx ? 28 : 20
            let spokes = NSBezierPath()
            for i in 0..<n {
                let a = Double(i) * 2 * .pi / Double(n) + rotation, off = (i % 2 == 0 ? 0.30 : -0.30)
                spokes.move(to: NSPoint(x: c.x + cos(a) * hubR, y: c.y + sin(a) * hubR)); spokes.line(to: NSPoint(x: c.x + cos(a + off) * rimIn, y: c.y + sin(a + off) * rimIn))
            }
            stroke(spokes, 0.55, NSColor(hex: 0xB7C2C7, alpha: blur > 0 ? 1 - blur * 0.8 : 1))
        }
        // Disc rotor (or drum plate on the rear of the simpler bikes), seen on the near side.
        if kind != .bmx {
            let drum = !front && kind.hasRearDrum
            if drum {
                cel(disc(c, rimIn * 0.52), NSColor(hex: 0x6C7A82), outline: 0.7, depth: 0.8)
                stroke(NSBezierPath(ovalIn: NSRect(x: c.x - rimIn * 0.40, y: c.y - rimIn * 0.40, width: rimIn * 0.8, height: rimIn * 0.8)), 0.6, NSColor(hex: 0x2A353C))
            } else {
                let rr = front ? rimIn * 0.66 : rimIn * 0.52
                cel(annulus(c, rr, rr * 0.55), NSColor(hex: 0xB9C3C7), outline: 0.7, depth: 0.6)
                for i in 0..<10 {
                    let a = Double(i) * 2 * .pi / 10 + rotation, rad = rr * 0.78
                    circle(c.x + cos(a) * rad, c.y + sin(a) * rad, max(0.6, rr * 0.055), NSColor(hex: 0x39454D))
                }
            }
        }
        if blur > 0.05 { disc(c, rimIn).fill(with: NSColor(hex: 0x6F7C83, alpha: blur * 0.55)) }
        // Hub with the axle nut.
        cel(disc(c, hubR), NSColor(hex: 0x9AA6AB), outline: 0.7, depth: 0.5)
        circle(c.x, c.y, hubR * 0.45, NSColor(hex: 0x20292F))
    }

    // MARK: Fork
    func drawFork(top: NSPoint, axle: NSPoint, far: Bool, kind: BikeKind) {
        let dx = axle.x - top.x, dy = axle.y - top.y, len = max(1, hypot(dx, dy)), d = NSPoint(x: dx / len, y: dy / len), n = NSPoint(x: -d.y, y: d.x)
        let off = far ? 1.6 : 0.0
        func at(_ t: Double) -> NSPoint { NSPoint(x: top.x + d.x * len * t - (far ? off : 0), y: top.y + d.y * len * t - (far ? off * 0.2 : 0)) }
        let inv = kind.invertedFork, gold = kind == .motocross || kind == .trials || kind == .scrambler, chrome = kind == .cruiser
        let sliderLen = (inv ? 0.50 : 0.42) * 62.0 * (len / 62.0)
        let jt = max(0.18, 1 - sliderLen / len)
        let silver = NSColor(hex: far ? 0x7D8A91 : 0xD6DCDE)
        let lowerC: NSColor = chrome ? NSColor(hex: far ? 0x8C98A0 : 0xE4E8E9) : (gold ? NSColor(hex: far ? 0x9A7A2A : 0xD9A93A) : NSColor(hex: far ? 0x2B353C : 0x46535B))
        let upperC: NSColor = inv ? NSColor(hex: far ? 0x20292F : 0x37444C) : silver
        let lowC: NSColor = inv ? silver : lowerC
        let (r0, r1) = inv ? (3.0, 2.0) : (1.9, 2.5)
        // Upper tube then lower leg; the leg overlaps the tube so travel reads as telescoping.
        celCapsule(at(0.0), at(jt + 0.06), r0, r0, upperC)
        celCapsule(at(jt), at(1.0), r1 * (inv ? 1 : 1.0), r1, lowC)
        if gold || chrome || !inv {
            // Rubber boot hiding the sliding joint.
            let b0 = at(max(0.12, jt - 0.20)), b1 = at(jt + 0.02)
            if !chrome || true {
                celCapsule(b0, b1, (inv ? 3.6 : 3.1), (inv ? 3.6 : 3.1), NSColor(hex: far ? 0x151C21 : 0x20292F), outline: 0.8)
                for k in 1...3 { let t = Double(k) / 4, p = NSPoint(x: b0.x + (b1.x - b0.x) * t, y: b0.y + (b1.y - b0.y) * t); let rib = NSBezierPath(); rib.move(to: NSPoint(x: p.x - n.x * 3.1, y: p.y - n.y * 3.1)); rib.line(to: NSPoint(x: p.x + n.x * 3.1, y: p.y + n.y * 3.1)); stroke(rib, 0.5, NSColor(hex: 0x56626A, alpha: 0.8)) }
            }
        }
        // Axle lug.
        if !far { cel(disc(axle, 3.6), lowC, outline: 0.8, depth: 0.6); circle(axle.x, axle.y, 1.3, NSColor(hex: 0x20292F)) }
    }

    // MARK: Swingarm and shock
    func drawSwingarm(pivot: NSPoint, axle: NSPoint, kind: BikeKind, far: Bool) {
        let dx = axle.x - pivot.x, dy = axle.y - pivot.y, l = max(1, hypot(dx, dy)), nx = -dy / l, ny = dx / l
        func at(_ t: Double, _ k: Double) -> NSPoint { NSPoint(x: pivot.x + dx * t + nx * k, y: pivot.y + dy * t + ny * k) }
        let alu = kind == .sport || kind == .hyperbike || kind == .electric || kind == .motocross || kind == .trials
        let c = alu ? NSColor(hex: far ? 0x4A565D : 0xA7B3B8) : NSColor(hex: far ? 0x1D262C : 0x39444B)
        let w0 = alu ? 4.4 : 3.6, w1 = alu ? 3.0 : 2.4
        let arm = smoothPath([at(-0.06, -w0), at(0.5, -(w0 + w1) / 2), at(1.0, -w1), at(1.05, 0), at(1.0, w1), at(0.5, (w0 + w1) / 2), at(-0.06, w0), at(-0.1, 0)], corners: [0, 2, 4, 6])
        cel(arm, c, outline: 0.8, depth: 0.9)
        if !far {
            // Brace tube under the arm and the axle plate with its adjuster.
            let br = NSBezierPath(); br.move(to: at(0.14, w0 * 0.9)); br.line(to: at(0.62, w1 * 0.95)); stroke(br, 1.2, NSColor(hex: 0x1C252B, alpha: 0.8))
            let plate = NSBezierPath(roundedRect: NSRect(x: axle.x - 4.0, y: axle.y - 3.6, width: 8, height: 7.2), xRadius: 2, yRadius: 2)
            cel(plate, NSColor(hex: alu ? 0xC3CCD0 : 0x58666E), outline: 0.7, depth: 0.5)
        }
    }

    func drawShock(top: NSPoint, bottom: NSPoint, kind: BikeKind) {
        let dx = bottom.x - top.x, dy = bottom.y - top.y, l = max(1, hypot(dx, dy)), d = NSPoint(x: dx / l, y: dy / l), n = NSPoint(x: -d.y, y: d.x)
        func at(_ t: Double, _ k: Double = 0) -> NSPoint { NSPoint(x: top.x + dx * t + n.x * k, y: top.y + dy * t + n.y * k) }
        let off = kind == .motocross || kind == .trials || kind == .scrambler
        let spring: NSColor
        switch kind {
        case .sport, .hyperbike: spring = NSColor(hex: 0xE2543E)
        case .motocross, .trials: spring = NSColor(hex: 0xF0C23A)
        case .electric: spring = NSColor(hex: 0x4FB878)
        default: spring = NSColor(hex: 0xC7CFD2)
        }
        celCapsule(at(0.02), at(0.34), 1.5, 1.5, NSColor(hex: 0xC8D0D3), outline: 0.7)
        celCapsule(at(0.66), at(0.98), 2.3, 2.3, NSColor(hex: 0x2B363D), outline: 0.7)
        if off { celCapsule(at(0.62, 5.5), at(0.92, 5.5), 2.2, 2.2, NSColor(hex: 0x39464E), outline: 0.7); stroke({ let p = NSBezierPath(); p.move(to: at(0.78, 2.3)); p.line(to: at(0.78, 4.6)); return p }(), 1.2, NSColor(hex: 0x1A2126)) }
        // Coil: slanted turns between the damper ends.
        let turns = 8
        let coil = NSBezierPath()
        for i in 0...turns {
            let t = 0.12 + 0.52 * Double(i) / Double(turns)
            let a = at(t, -3.6), b = at(t + 0.02, 3.6)
            coil.move(to: a); coil.line(to: b)
        }
        stroke(coil, 2.1, inkColor); stroke(coil, 1.3, spring)
        cel(disc(top, 2.2), NSColor(hex: 0x9AA6AB), outline: 0.7, depth: 0.4); cel(disc(bottom, 2.0), NSColor(hex: 0x9AA6AB), outline: 0.7, depth: 0.4)
    }

    // MARK: Brakes
    func drawCaliper(axle: NSPoint, discRadius: Double, angle a: Double, mount: NSPoint, sporty: Bool) {
        // Mounting arm from the slider / swingarm to the caliper body.
        let rc = discRadius + 0.2
        let cp = NSPoint(x: axle.x + cos(a) * rc, y: axle.y + sin(a) * rc)
        let arm = capsulePath(mount, cp, 1.9, 2.6); cel(arm, NSColor(hex: 0x4A575F), outline: 0.7, depth: 0.7)
        // Caliper bridge: a rounded block that wraps over the rim of the disc.
        let half = 0.24, r1 = discRadius - 4.4, r2 = discRadius + 3.0
        var pts: [NSPoint] = []
        for i in 0...4 { let t = a - half + 2 * half * Double(i) / 4; pts.append(NSPoint(x: axle.x + cos(t) * r2, y: axle.y + sin(t) * r2)) }
        for i in 0...4 { let t = a + half - 2 * half * Double(i) / 4; pts.append(NSPoint(x: axle.x + cos(t) * r1, y: axle.y + sin(t) * r1)) }
        let body = smoothPath(pts, corners: [0, 4, 5, 9])
        cel(body, sporty ? NSColor(hex: 0xE8B64A) : NSColor(hex: 0x56646D), outline: 0.8, depth: 0.8)
        // Pistons (two visible), the pad seam and the bleed nipple.
        for off in [-half * 0.5, half * 0.5] {
            let pc = NSPoint(x: axle.x + cos(a + off) * (discRadius - 0.6), y: axle.y + sin(a + off) * (discRadius - 0.6))
            circle(pc.x, pc.y, 1.7, NSColor(hex: 0x1D262C)); circle(pc.x - 0.3, pc.y - 0.3, 0.8, NSColor(hex: 0xD6DCDE))
        }
        let nip = NSPoint(x: axle.x + cos(a + half * 0.9) * (r2 + 1.3), y: axle.y + sin(a + half * 0.9) * (r2 + 1.3))
        circle(nip.x, nip.y, 0.9, NSColor(hex: 0xD6DCDE))
    }

    func drawBrakes(front: NSPoint, rear: NSPoint, radius r: Double, kind: BikeKind, forkTop: NSPoint, grip: NSPoint, pivot: NSPoint) {
        guard kind != .bmx else { return }
        let rimIn = r * 0.70, sporty = kind == .sport || kind == .hyperbike
        let fd = rimIn * 0.66, fa = Double.pi * (sporty ? 1.18 : 1.10)
        let dx = front.x - forkTop.x, dy = front.y - forkTop.y, len = max(1, hypot(dx, dy)), d = NSPoint(x: dx / len, y: dy / len), nrm = NSPoint(x: -d.y, y: d.x)
        // Mounting lug on the back of the slider.
        let lug = NSPoint(x: front.x + d.x * -2.0 - 1.2, y: front.y + d.y * -2.0)
        drawCaliper(axle: front, discRadius: fd, angle: fa, mount: lug, sporty: sporty)
        // Rear: caliper on the swingarm for disc-braked bikes; drums get a torque arm instead.
        if kind.hasRearDrum {
            let arm = capsulePath(rear, NSPoint(x: rear.x + 13, y: rear.y - 5.5), 1.2, 1.2); cel(arm, NSColor(hex: 0x4A575F), outline: 0.6, depth: 0.5)
        } else {
            drawCaliper(axle: rear, discRadius: rimIn * 0.52, angle: Double.pi * 1.62, mount: NSPoint(x: rear.x + 2, y: rear.y - 1), sporty: false)
        }
        // Brake line: from the lever down the back of the fork leg to the caliper.
        let a0 = NSPoint(x: forkTop.x + nrm.x * -4.5 + d.x * 6, y: forkTop.y + nrm.y * -4.5 + d.y * 6)
        let cal = NSPoint(x: front.x + cos(fa + 0.2) * (fd + 3), y: front.y + sin(fa + 0.2) * (fd + 3))
        let hose = NSBezierPath(); hose.move(to: NSPoint(x: grip.x + 1, y: grip.y + 2))
        hose.curve(to: a0, controlPoint1: NSPoint(x: grip.x - 6, y: grip.y + 4), controlPoint2: NSPoint(x: a0.x + 4, y: a0.y - 5))
        hose.curve(to: cal, controlPoint1: NSPoint(x: a0.x + d.x * len * 0.30 - nrm.x * 2.5, y: a0.y + d.y * len * 0.30 - nrm.y * 2.5), controlPoint2: NSPoint(x: cal.x - d.x * len * 0.22 - nrm.x * 1.5, y: cal.y - d.y * len * 0.22 - nrm.y * 1.5))
        stroke(hose, 1.7, inkColor); stroke(hose, 0.8, NSColor(hex: 0x6C7A82))
    }

    // MARK: Handlebar, levers, mirror and pegs
    func drawBars(forkTop: NSPoint, axle: NSPoint, grip: NSPoint, kind: BikeKind) {
        let dx = forkTop.x - axle.x, dy = forkTop.y - axle.y, l = max(1, hypot(dx, dy)), up = NSPoint(x: dx / l, y: dy / l)
        let clamp = NSPoint(x: forkTop.x + up.x * 2.5, y: forkTop.y + up.y * 2.5)
        // Triple clamp / yoke block.
        let yoke = capsulePath(NSPoint(x: forkTop.x - up.x * 1, y: forkTop.y - up.y * 1), NSPoint(x: forkTop.x + up.x * 4, y: forkTop.y + up.y * 4), 4.0, 3.4)
        cel(yoke, NSColor(hex: 0x39454D), outline: 0.8, depth: 0.7)
        let bar = NSBezierPath(); bar.move(to: clamp)
        let sporty = kind == .sport || kind == .hyperbike
        switch kind {
        case _ where sporty:
            bar.curve(to: grip, controlPoint1: NSPoint(x: clamp.x + 4, y: clamp.y - 1), controlPoint2: NSPoint(x: grip.x - 5, y: grip.y + 1))
        case .cruiser:
            bar.curve(to: grip, controlPoint1: NSPoint(x: clamp.x - 3, y: grip.y + 8), controlPoint2: NSPoint(x: grip.x - 7, y: grip.y - 2))
        case .motocross, .trials, .scrambler, .bmx:
            bar.curve(to: grip, controlPoint1: NSPoint(x: clamp.x - 2, y: clamp.y - 12), controlPoint2: NSPoint(x: grip.x - 6, y: grip.y + 3))
        default:
            bar.curve(to: grip, controlPoint1: NSPoint(x: clamp.x - 1, y: clamp.y - 7), controlPoint2: NSPoint(x: grip.x - 6, y: grip.y + 2))
        }
        tubeStroke(bar, 2.2, NSColor(hex: kind == .scooter ? 0x39454D : 0xC7CED1))
        if kind == .motocross || kind == .trials || kind == .bmx {
            let cross = NSBezierPath(); cross.move(to: NSPoint(x: clamp.x - 3, y: clamp.y - 9)); cross.line(to: NSPoint(x: grip.x - 3, y: grip.y + 3)); tubeStroke(cross, 1.5, NSColor(hex: 0xC7CED1))
        }
        // Lever (brake) and, for the road bikes, a mirror on a stalk.
        let lever = capsulePath(NSPoint(x: grip.x + 1, y: grip.y + 1.5), NSPoint(x: grip.x + 9, y: grip.y + 2.8), 1.0, 0.6); cel(lever, NSColor(hex: 0xD6DCDE), outline: 0.6, depth: 0.4)
        cel(NSBezierPath(roundedRect: NSRect(x: grip.x - 1.5, y: grip.y - 6.2, width: 4.8, height: 3.4), xRadius: 1.1, yRadius: 1.1), NSColor(hex: 0xC9D0CF), outline: 0.6, depth: 0.4)
        if kind != .motocross && kind != .trials && kind != .bmx && kind != .scrambler && !sporty {
            let stalk = NSBezierPath(); stalk.move(to: NSPoint(x: grip.x - 1, y: grip.y - 1)); stalk.line(to: NSPoint(x: grip.x - 5, y: grip.y - 15)); tubeStroke(stalk, 1.0, NSColor(hex: 0x39454D))
            let mir = NSBezierPath(ovalIn: NSRect(x: grip.x - 12, y: grip.y - 21, width: 12, height: 7.4)); cel(mir, NSColor(hex: 0x39454D), outline: 0.8, depth: 0.7)
            let glass = NSBezierPath(ovalIn: NSRect(x: grip.x - 10.6, y: grip.y - 19.8, width: 9.2, height: 5)); NSColor(hex: 0xB9D4E0).setFill(); glass.fill()
        }
        // Grip end, seen head-on.
        circle(grip.x + 1, grip.y, 3.3, NSColor(hex: 0x141B20)); circle(grip.x + 1, grip.y, 1.9, NSColor(hex: 0x8B979D))
        // Handguard on the dirt bikes.
        if kind == .motocross || kind == .trials || kind == .scrambler {
            let hg = NSBezierPath(); hg.move(to: NSPoint(x: grip.x - 5, y: grip.y - 4)); hg.curve(to: NSPoint(x: grip.x + 10, y: grip.y + 2), controlPoint1: NSPoint(x: grip.x + 2, y: grip.y - 9), controlPoint2: NSPoint(x: grip.x + 11, y: grip.y - 4))
            stroke(hg, 2.4, inkColor); stroke(hg, 1.4, NSColor(hex: 0x39454D))
        }
    }

    func drawPeg(at p: NSPoint) {
        cel(disc(NSPoint(x: p.x - 3, y: p.y), 2.6), NSColor(hex: 0x56646D), outline: 0.7, depth: 0.4)
        celCapsule(NSPoint(x: p.x - 3, y: p.y), NSPoint(x: p.x + 7, y: p.y), 1.5, 1.5, NSColor(hex: 0xA7B3B8), outline: 0.7)
    }
}

extension NSBezierPath {
    func fill(with c: NSColor) { c.setFill(); fill() }
}
