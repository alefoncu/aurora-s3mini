import Cocoa

/// The rider, drawn from the solver's exact anchors (hip, knee, foot, shoulder, elbow, hand, head).
/// Bones are never scaled to reach; only the clothing, boots, gloves and helmet are designed here.
extension RideRenderer {
    private func rp(_ v: RideVector, _ u: Double) -> NSPoint { NSPoint(x: v.x * u, y: -v.y * u) }

    /// A limb with a gentle muscle bulge, drawn as one smooth outline.
    private func limb(_ a: NSPoint, _ b: NSPoint, _ ra: Double, _ rb: Double, bulge: Double = 0, at t: Double = 0.35, _ c: NSColor, outline: Double = 0.9) {
        let dx = b.x - a.x, dy = b.y - a.y, l = max(0.001, hypot(dx, dy)), ux = dx / l, uy = dy / l, nx = -uy, ny = ux
        let m = NSPoint(x: a.x + dx * t, y: a.y + dy * t), rm = ra + (rb - ra) * t + bulge
        let pts = [NSPoint(x: a.x + nx * ra, y: a.y + ny * ra), NSPoint(x: m.x + nx * rm, y: m.y + ny * rm), NSPoint(x: b.x + nx * rb, y: b.y + ny * rb),
                   NSPoint(x: b.x + ux * rb, y: b.y + uy * rb),
                   NSPoint(x: b.x - nx * rb, y: b.y - ny * rb), NSPoint(x: m.x - nx * rm, y: m.y - ny * rm), NSPoint(x: a.x - nx * ra, y: a.y - ny * ra),
                   NSPoint(x: a.x - ux * ra, y: a.y - uy * ra)]
        cel(smoothPath(pts), c, outline: outline)
    }

    private func drawBoot(foot: NSPoint, ankle: NSPoint, shinDir: NSPoint, u: Double, style: BikeKind, far: Bool) {
        func P(_ x: Double, _ y: Double) -> NSPoint { NSPoint(x: foot.x + x * u, y: foot.y + y * u) }
        let dim = far ? 0.3 : 0.0
        switch style {
        case .motocross:
            // Tall boot: shin plate with buckles, ribbed toe box.
            let boot = smoothPath([P(-0.075, -0.16), P(-0.07, 0.02), P(-0.06, 0.05), P(0.06, 0.05), P(0.125, 0.03), P(0.12, -0.01), P(0.05, -0.04), P(0.03, -0.09), P(0.035, -0.17)], corners: [0, 3, 8])
            cel(boot, darken(NSColor(hex: 0xE4E6E0), dim), outline: 0.9)
            for k in [-0.085, -0.045] { let l = NSBezierPath(); l.move(to: P(-0.07, k)); l.line(to: P(0.035, k + 0.004)); stroke(l, u * 0.011, darken(NSColor(hex: 0x39454D), dim)) }
            cel(NSBezierPath(rect: NSRect(x: foot.x - 0.075 * u, y: foot.y + 0.033 * u, width: 0.2 * u, height: 0.018 * u)), NSColor(hex: 0x2A333A), outline: 0.5, depth: 0.3)
        case .sport:
            let boot = smoothPath([P(-0.07, -0.13), P(-0.07, 0.02), P(-0.06, 0.048), P(0.06, 0.048), P(0.12, 0.028), P(0.115, -0.012), P(0.05, -0.035), P(0.03, -0.075), P(0.035, -0.135)], corners: [0, 3, 8])
            cel(boot, darken(NSColor(hex: 0x20282F), dim), outline: 0.9)
            let slider = NSBezierPath(roundedRect: NSRect(x: foot.x + 0.04 * u, y: foot.y - 0.025 * u, width: 0.07 * u, height: 0.04 * u), xRadius: 0.012 * u, yRadius: 0.012 * u)
            cel(slider, darken(NSColor(hex: 0xC9CFCF), dim), outline: 0.5, depth: 0.3)
        case .bmx:
            let sh = smoothPath([P(-0.075, -0.09), P(-0.07, 0.02), P(-0.06, 0.045), P(0.06, 0.045), P(0.125, 0.025), P(0.115, -0.015), P(0.05, -0.04), P(0.015, -0.065), P(0.0, -0.1)], corners: [0, 3])
            cel(sh, darken(NSColor(hex: 0x2E353B), dim), outline: 0.9)
            for k in 0..<3 { let l = NSBezierPath(); l.move(to: P(0.025 + Double(k) * 0.025, -0.04 + Double(k) * 0.006)); l.line(to: P(0.04 + Double(k) * 0.025, -0.02 + Double(k) * 0.006)); stroke(l, u * 0.008, NSColor.white.withAlphaComponent(0.8)) }
            cel(NSBezierPath(rect: NSRect(x: foot.x - 0.07 * u, y: foot.y + 0.036 * u, width: 0.2 * u, height: 0.016 * u)), NSColor(hex: 0xE8E4D8), outline: 0.5, depth: 0.3)
        default:
            // Urban sneaker.
            let sh = smoothPath([P(-0.078, -0.1), P(-0.072, 0.02), P(-0.062, 0.045), P(0.06, 0.045), P(0.125, 0.025), P(0.118, -0.012), P(0.055, -0.038), P(0.018, -0.068), P(0.0, -0.105)], corners: [0, 3])
            cel(sh, darken(NSColor(hex: 0x7A5C40), dim), outline: 0.9)
            for k in 0..<3 { let l = NSBezierPath(); l.move(to: P(0.02 + Double(k) * 0.025, -0.05 + Double(k) * 0.005)); l.line(to: P(0.038 + Double(k) * 0.025, -0.028 + Double(k) * 0.005)); stroke(l, u * 0.008, NSColor.white.withAlphaComponent(0.85)) }
            cel(NSBezierPath(rect: NSRect(x: foot.x - 0.068 * u, y: foot.y + 0.034 * u, width: 0.195 * u, height: 0.018 * u)), darken(NSColor(hex: 0xE8E4D8), dim), outline: 0.5, depth: 0.3)
        }
    }

    private func drawLeg(hip: NSPoint, knee: NSPoint, foot: NSPoint, u: Double, style: BikeKind, far: Bool, pants: NSColor) {
        let c = far ? darken(pants, 0.30) : pants
        let ankle = NSPoint(x: foot.x - 0.012 * u, y: foot.y - 0.085 * u)
        let sx = knee.x - ankle.x, sy = knee.y - ankle.y, sl = max(0.001, hypot(sx, sy))
        drawBoot(foot: foot, ankle: ankle, shinDir: NSPoint(x: sx / sl, y: sy / sl), u: u, style: style, far: far)
        limb(knee, ankle, 0.050 * u, 0.034 * u, bulge: 0.012 * u, at: 0.30, c)
        limb(hip, knee, 0.088 * u, 0.054 * u, bulge: 0.010 * u, at: 0.25, c)
        cel(disc(knee, 0.050 * u), c, outline: 0.9, depth: 0.7)
        if !far {
            switch style {
            case .motocross, .sport:
                // Knee guard.
                let guardP = smoothPath([NSPoint(x: knee.x - 0.03 * u, y: knee.y - 0.065 * u), NSPoint(x: knee.x + 0.052 * u, y: knee.y - 0.05 * u), NSPoint(x: knee.x + 0.07 * u, y: knee.y + 0.005 * u), NSPoint(x: knee.x + 0.045 * u, y: knee.y + 0.06 * u), NSPoint(x: knee.x - 0.03 * u, y: knee.y + 0.06 * u), NSPoint(x: knee.x - 0.052 * u, y: knee.y)])
                cel(guardP, style == .motocross ? NSColor(hex: 0xE4E6E0) : NSColor(hex: 0x39424A), outline: 0.8, depth: 0.7)
                if style == .sport { cel(NSBezierPath(roundedRect: NSRect(x: knee.x + 0.032 * u, y: knee.y - 0.026 * u, width: 0.045 * u, height: 0.05 * u), xRadius: 0.012 * u, yRadius: 0.012 * u), NSColor(hex: 0xC9CFCF), outline: 0.5, depth: 0.3) }
            case .bmx:
                let pad = NSBezierPath(roundedRect: NSRect(x: knee.x - 0.04 * u, y: knee.y - 0.058 * u, width: 0.1 * u, height: 0.092 * u), xRadius: 0.03 * u, yRadius: 0.03 * u)
                cel(pad, NSColor(hex: 0x39424A), outline: 0.8, depth: 0.6)
            default:
                // Jeans: fold creases over the knee and an outer seam.
                for k in [-0.026, 0.0, 0.026] { let l = NSBezierPath(); l.move(to: NSPoint(x: knee.x - 0.045 * u, y: knee.y + k * u)); l.line(to: NSPoint(x: knee.x - 0.012 * u, y: knee.y + (k + 0.01) * u)); stroke(l, u * 0.006, NSColor.black.withAlphaComponent(0.25)) }
                let seam = NSBezierPath(); seam.move(to: NSPoint(x: hip.x, y: hip.y - 0.07 * u)); seam.line(to: NSPoint(x: knee.x, y: knee.y - 0.045 * u)); stroke(seam, u * 0.005, lighten(c, 0.3).withAlphaComponent(0.7))
            }
        }
    }

    private func drawHelmet(head h: NSPoint, u: Double, style: BikeKind) {
        func P(_ x: Double, _ y: Double) -> NSPoint { NSPoint(x: h.x + x * u, y: h.y + y * u) }
        if style == .bmx {
            // Open-face: visible face under a half shell.
            let face = smoothPath([P(-0.05, -0.07), P(0.04, -0.085), P(0.098, -0.05), P(0.106, -0.008), P(0.12, 0.022), P(0.098, 0.036), P(0.104, 0.066), P(0.075, 0.1), P(0.02, 0.112), P(-0.05, 0.09), P(-0.07, 0.0)], corners: [4])
            cel(face, skin, outline: 0.9)
            let eye = NSBezierPath(ovalIn: NSRect(x: h.x + 0.05 * u, y: h.y - 0.026 * u, width: 0.018 * u, height: 0.022 * u)); NSColor(hex: 0x141B20).setFill(); eye.fill()
            let shell = smoothPath([P(-0.125, 0.015), P(-0.11, -0.07), P(-0.03, -0.13), P(0.06, -0.118), P(0.112, -0.062), P(0.1, -0.052), P(0.02, -0.07), P(-0.07, -0.04), P(-0.1, 0.05)], corners: [4, 5])
            cel(shell, helmet, outline: 1.0)
            return
        }
        let shell = smoothPath([P(-0.128, 0.01), P(-0.108, -0.085), P(-0.015, -0.135), P(0.085, -0.105), P(0.13, -0.03), P(0.133, 0.035), P(0.118, 0.097), P(0.066, 0.128), P(-0.035, 0.115), P(-0.105, 0.07)])
        cel(shell, helmet, outline: 1.0)
        switch helmetStyle {
        case .stripe:
            let s = NSBezierPath(); s.move(to: P(-0.12, -0.05)); s.curve(to: P(0.1, -0.1), controlPoint1: P(-0.05, -0.14), controlPoint2: P(0.04, -0.13)); stroke(s, u * 0.026, NSColor(hex: 0x2164A7))
        case .flames:
            for k in 0..<3 { let f = smoothPath([P(-0.12, 0.055 - Double(k) * 0.03), P(-0.05, 0.035 - Double(k) * 0.03), P(0.015, 0.045 - Double(k) * 0.032), P(-0.04, 0.062 - Double(k) * 0.03)], corners: [2]); cel(f, NSColor(hex: k == 1 ? 0xFFC23A : 0xFF6B1F), outline: 0.4, depth: 0.2) }
        default: break
        }
        // Visor: a dark glossy port with a bright reflection and a chin vent.
        let visor = smoothPath([P(0.018, -0.062), P(0.108, -0.066), P(0.136, -0.018), P(0.128, 0.042), P(0.07, 0.046), P(0.02, 0.012)], corners: [0])
        cel(visor, helmetStyle == .gold ? NSColor(hex: 0xE0B341) : NSColor(hex: 0x1D2B3A), outline: 0.9, depth: 0.5)
        let glint = NSBezierPath(); glint.move(to: P(0.045, -0.04)); glint.line(to: P(0.105, -0.045)); stroke(glint, u * 0.008, NSColor.white.withAlphaComponent(0.75))
        let chin = NSBezierPath(roundedRect: NSRect(x: h.x + 0.095 * u, y: h.y + 0.07 * u, width: 0.034 * u, height: 0.03 * u), xRadius: 0.008 * u, yRadius: 0.008 * u)
        cel(chin, darken(helmet, 0.4), outline: 0.6, depth: 0.2)
        for k in 0..<3 { let l = NSBezierPath(); l.move(to: P(0.1, 0.076 + Double(k) * 0.009)); l.line(to: P(0.126, 0.076 + Double(k) * 0.009)); stroke(l, u * 0.004, inkColor) }
        // Rear spoiler lip.
        let lip = NSBezierPath(); lip.move(to: P(-0.128, 0.02)); lip.line(to: P(-0.15, 0.03)); stroke(lip, u * 0.012, darken(helmet, 0.25))
    }

    private func drawGlove(hand: NSPoint, u: Double, style: BikeKind, sleeve: NSColor) {
        let leather: NSColor
        switch style { case .sport: leather = NSColor(hex: 0x20282F); case .motocross: leather = NSColor(hex: 0xE4E6E0); case .bmx: leather = NSColor(hex: 0x2A323A); default: leather = NSColor(hex: 0x7A5C40) }
        // Cuff, then a fist closed round the grip with a thumb and finger line.
        let cuff = NSBezierPath(roundedRect: NSRect(x: hand.x - 0.075 * u, y: hand.y - 0.03 * u, width: 0.05 * u, height: 0.06 * u), xRadius: 0.014 * u, yRadius: 0.014 * u)
        cel(cuff, darken(leather, 0.1), outline: 0.8, depth: 0.5)
        let fist = smoothPath([NSPoint(x: hand.x - 0.04 * u, y: hand.y - 0.045 * u), NSPoint(x: hand.x + 0.03 * u, y: hand.y - 0.05 * u), NSPoint(x: hand.x + 0.062 * u, y: hand.y - 0.01 * u), NSPoint(x: hand.x + 0.056 * u, y: hand.y + 0.034 * u), NSPoint(x: hand.x + 0.01 * u, y: hand.y + 0.048 * u), NSPoint(x: hand.x - 0.04 * u, y: hand.y + 0.03 * u)])
        cel(fist, leather, outline: 0.9, depth: 0.7)
        for k in 0..<3 { let l = NSBezierPath(); l.move(to: NSPoint(x: hand.x + 0.015 * u, y: hand.y - 0.03 * u + Double(k) * 0.024 * u)); l.line(to: NSPoint(x: hand.x + 0.056 * u, y: hand.y - 0.026 * u + Double(k) * 0.024 * u)); stroke(l, u * 0.005, darken(leather, 0.45)) }
        if style == .sport { cel(NSBezierPath(roundedRect: NSRect(x: hand.x - 0.01 * u, y: hand.y - 0.05 * u, width: 0.055 * u, height: 0.026 * u), xRadius: 0.01 * u, yRadius: 0.01 * u), NSColor(hex: 0xC9CFCF), outline: 0.5, depth: 0.3) }
    }

    /// `farLeg`: 0 draws the whole rider, 1 only the far-side leg (call before the bike so its bodywork covers it), 2 everything else.
    func drawRider(_ pose: RiderPose, units u: Double, kind: BikeKind, passenger: Bool = false, detached: Bool = false, farLeg: Int = 0) {
        let hip = rp(pose.hip, u), shoulder = rp(pose.shoulder, u), elbow = rp(pose.elbow, u), hand = rp(pose.hand, u)
        let knee = rp(pose.knee, u), foot = rp(pose.foot, u), farKnee = rp(pose.farKnee, u), farFoot = rp(pose.farFoot, u)
        let neck = rp(pose.neck, u), head = rp(pose.head, u)
        let style: BikeKind = passenger ? .commuter : kind.outfitStyle
        let coat = passenger ? NSColor(hex: 0xC76254) : jacket
        let pants: NSColor
        switch style {
        case .motocross: pants = darken(coat, 0.5)
        case .sport: pants = NSColor(hex: 0x242C35)
        case .bmx: pants = NSColor(hex: 0x4A5156)
        default: pants = NSColor(hex: 0x3A5270)
        }
        if farLeg != 2 { drawLeg(hip: hip, knee: farKnee, foot: farFoot, u: u, style: style, far: true, pants: pants) }
        if farLeg == 1 { return }

        // Torso: back, shoulder, chest and belly in one outline along the hip-shoulder axis.
        let dx = shoulder.x - hip.x, dy = shoulder.y - hip.y, l = max(0.001, hypot(dx, dy)), nx = -dy / l, ny = dx / l
        func T(_ s: Double, _ n: Double) -> NSPoint { NSPoint(x: hip.x + dx * s + nx * n * u, y: hip.y + dy * s + ny * n * u) }
        let hunch = style == .sport || style == .motocross
        let torso = smoothPath([T(-0.04, -0.082), T(0.2, -0.086), T(0.46, -0.098), T(0.72, -0.118 - (hunch ? 0.012 : 0)), T(0.93, -0.104), T(1.03, -0.05), T(1.05, 0.03), T(0.96, 0.092), T(0.78, 0.122), T(0.55, 0.108), T(0.32, 0.096), T(0.08, 0.098), T(-0.05, 0.04)])
        cel(torso, coat, outline: 1.0)
        NSGraphicsContext.current?.saveGraphicsState(); torso.addClip()
        func band(_ s: Double, _ w: Double, _ c: NSColor) { let b = NSBezierPath(); b.move(to: T(s, -0.2)); b.line(to: T(s, 0.2)); stroke(b, w, c, cap: .butt) }
        switch style {
        case .sport:
            // Leather suit: contrast shoulder panel, piping and back hump seam.
            cel(smoothPath([T(0.4, -0.2), T(1.0, -0.2), T(1.08, 0.0), T(0.7, 0.04), T(0.42, -0.02)]), darken(coat, 0.18), outline: 0, shine: false)
            let seam = NSBezierPath(); seam.move(to: T(0.06, 0.07)); seam.line(to: T(0.95, 0.09)); stroke(seam, u * 0.012, lighten(coat, 0.55))
        case .motocross:
            for f in [0.5, 0.64, 0.78] { band(f, u * 0.014, darken(coat, 0.45)) }
            let sl = NSBezierPath(); sl.move(to: T(0.02, 0.0)); sl.line(to: T(1.0, 0.0)); stroke(sl, u * 0.016, lighten(coat, 0.5))
        case .bmx:
            let ring = NSBezierPath(ovalIn: NSRect(x: T(0.6, 0.04).x - 0.04 * u, y: T(0.6, 0.04).y - 0.04 * u, width: 0.08 * u, height: 0.08 * u)); NSColor(hex: 0xEDE6D4, alpha: 0.9).setFill(); ring.fill()
        default:
            switch jacketStyle {
            case .reflective: for f in [0.4, 0.74] { band(f, u * 0.024, NSColor(hex: 0xDDE4E6)) }
            case .racing: let s = NSBezierPath(); s.move(to: T(0.02, 0.03)); s.line(to: T(1.0, 0.03)); stroke(s, u * 0.03, NSColor.white.withAlphaComponent(0.9))
            case .twoTone: cel(smoothPath([T(-0.1, -0.2), T(0.44, -0.2), T(0.4, 0.2), T(-0.1, 0.2)], closed: true, corners: [0, 1, 2, 3]), darken(coat, 0.45), outline: 0, shine: false)
            case .standard: break
            }
            for f in [0.56, 0.7, 0.84] { band(f, u * 0.006, darken(coat, 0.3)) }
            let zip = NSBezierPath(); zip.move(to: T(0.12, 0.095)); zip.line(to: T(0.86, 0.118)); stroke(zip, u * 0.008, NSColor(hex: 0xD3DADE))
            band(0.03, u * 0.028, NSColor(hex: 0x2B2F33))
        }
        NSGraphicsContext.current?.restoreGraphicsState()
        // Collar / neck roll and the neck itself.
        limb(neck, NSPoint(x: head.x - 0.02 * u, y: head.y + 0.06 * u), 0.05 * u, 0.044 * u, darken(skin, 0.08), outline: 0.8)
        if style != .sport && style != .bmx {
            let collar = smoothPath([NSPoint(x: neck.x - 0.07 * u, y: neck.y + 0.012 * u), NSPoint(x: neck.x - 0.01 * u, y: neck.y - 0.04 * u), NSPoint(x: neck.x + 0.06 * u, y: neck.y - 0.01 * u), NSPoint(x: neck.x + 0.03 * u, y: neck.y + 0.045 * u), NSPoint(x: neck.x - 0.05 * u, y: neck.y + 0.05 * u)])
            cel(collar, darken(coat, 0.12), outline: 0.8, depth: 0.6)
        }
        drawHelmet(head: head, u: u, style: style)
        drawLeg(hip: hip, knee: knee, foot: foot, u: u, style: style, far: false, pants: pants)
        // Arm: sleeve with a rounded shoulder cap, elbow and a glove closed on the grip.
        let sleeve = style == .bmx ? skin : coat
        limb(elbow, hand, 0.040 * u, 0.030 * u, bulge: 0.008 * u, at: 0.3, sleeve)
        limb(shoulder, elbow, 0.052 * u, 0.040 * u, bulge: 0.008 * u, at: 0.3, sleeve)
        cel(disc(shoulder, 0.054 * u), sleeve, outline: 0.9, depth: 0.7)
        cel(disc(elbow, 0.040 * u), sleeve, outline: 0.9, depth: 0.6)
        drawGlove(hand: hand, u: u, style: style, sleeve: sleeve)
    }
}
