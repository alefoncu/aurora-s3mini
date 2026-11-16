import Cocoa

/// Drawing toolkit shared by the vehicle and rider artwork: smooth outlines, cel shading and tapered limbs.
/// Everything is drawn in the renderer's y-down space with the rear axle at the origin; `y-up` helpers say so.
extension RideRenderer {
    var inkColor: NSColor { NSColor(hex: 0x141B20) }

    func lighten(_ c: NSColor, _ t: Double) -> NSColor { c.blended(withFraction: CGFloat(t), of: .white) ?? c }
    func darken(_ c: NSColor, _ t: Double) -> NSColor { c.blended(withFraction: CGFloat(t), of: NSColor(hex: 0x0A1014)) ?? c }
    func mixColor(_ a: NSColor, _ b: NSColor, _ t: Double) -> NSColor { a.blended(withFraction: CGFloat(t), of: b) ?? a }

    /// Catmull-Rom spline through screen-space points. `corners` lists indices that keep a sharp tangent break.
    func smoothPath(_ p: [NSPoint], closed: Bool = true, corners: Set<Int> = []) -> NSBezierPath {
        let path = NSBezierPath(), n = p.count
        guard n > 1 else { return path }
        func tangent(_ i: Int) -> NSPoint {
            if corners.contains(i) { return .zero }
            let a = closed ? p[(i + n - 1) % n] : p[max(0, i - 1)], b = closed ? p[(i + 1) % n] : p[min(n - 1, i + 1)]
            return NSPoint(x: (b.x - a.x) / 2, y: (b.y - a.y) / 2)
        }
        path.move(to: p[0])
        for i in 0..<(closed ? n : n - 1) {
            let j = (i + 1) % n, t0 = tangent(i), t1 = tangent(j)
            path.curve(to: p[j], controlPoint1: NSPoint(x: p[i].x + t0.x / 3, y: p[i].y + t0.y / 3), controlPoint2: NSPoint(x: p[j].x - t1.x / 3, y: p[j].y - t1.y / 3))
        }
        if closed { path.close() }
        return path
    }

    /// Cel-shaded fill: a flat base, a hard shadow along the lower-right edge, a thin rim light on the upper-left
    /// edge and a firm ink outline. The shading follows the shape's own contour, so every part reads as volume.
    func cel(_ path: NSBezierPath, _ base: NSColor, outline: Double = 0.9, depth: Double = 1.0, shine: Bool = true) {
        // Vector-illustration shading: light top edge, flat base, then a hard step to a darker lower half.
        let stops: [NSColor] = [lighten(base, 0.45), lighten(base, 0.12), base, darken(base, 0.28), darken(base, 0.5)]
        let at: [CGFloat] = [0, 0.26, 0.58, 0.60, 1]
        if let g = NSGradient(colors: stops, atLocations: at, colorSpace: .sRGB) { g.draw(in: path, angle: 90) } else { base.setFill(); path.fill() }
        if outline > 0 { inkColor.setStroke(); path.lineWidth = outline; path.lineJoinStyle = .round; path.stroke() }
    }

    /// A tapered capsule between two points (limbs, silencers, tubes with real thickness).
    func capsulePath(_ a: NSPoint, _ b: NSPoint, _ r0: Double, _ r1: Double) -> NSBezierPath {
        let dx = b.x - a.x, dy = b.y - a.y, l = max(0.001, hypot(dx, dy)), ux = dx / l, uy = dy / l, nx = -uy, ny = ux
        let m = NSPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2), rm = (r0 + r1) / 2
        let pts = [NSPoint(x: a.x + nx * r0, y: a.y + ny * r0), NSPoint(x: m.x + nx * rm, y: m.y + ny * rm), NSPoint(x: b.x + nx * r1, y: b.y + ny * r1),
                   NSPoint(x: b.x + ux * r1, y: b.y + uy * r1),
                   NSPoint(x: b.x - nx * r1, y: b.y - ny * r1), NSPoint(x: m.x - nx * rm, y: m.y - ny * rm), NSPoint(x: a.x - nx * r0, y: a.y - ny * r0),
                   NSPoint(x: a.x - ux * r0, y: a.y - uy * r0)]
        return smoothPath(pts)
    }
    func celCapsule(_ a: NSPoint, _ b: NSPoint, _ r0: Double, _ r1: Double, _ c: NSColor, outline: Double = 0.9) { cel(capsulePath(a, b, r0, r1), c, outline: outline) }

    /// A ring (tyre, rim, disc rotor) between two radii.
    func annulus(_ c: NSPoint, _ rOut: Double, _ rIn: Double) -> NSBezierPath {
        let p = NSBezierPath(ovalIn: NSRect(x: c.x - rOut, y: c.y - rOut, width: rOut * 2, height: rOut * 2))
        p.append(NSBezierPath(ovalIn: NSRect(x: c.x - rIn, y: c.y - rIn, width: rIn * 2, height: rIn * 2)))
        p.windingRule = .evenOdd
        return p
    }
    func disc(_ c: NSPoint, _ r: Double) -> NSBezierPath { NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)) }

    func stroke(_ path: NSBezierPath, _ w: Double, _ c: NSColor, cap: NSBezierPath.LineCapStyle = .round) {
        path.lineWidth = w; path.lineCapStyle = cap; path.lineJoinStyle = .round; c.setStroke(); path.stroke()
    }
    /// A tube with an ink edge, body colour and a highlight streak.
    func tubeStroke(_ path: NSBezierPath, _ w: Double, _ c: NSColor) {
        stroke(path, w + 1.7, inkColor)
        stroke(path, w, darken(c, 0.12))
        let hi = path.copy() as! NSBezierPath
        hi.transform(using: AffineTransform(translationByX: -w * 0.14, byY: -w * 0.2))
        stroke(hi, max(0.5, w * 0.5), c)
        stroke(hi, max(0.4, w * 0.18), lighten(c, 0.55).withAlphaComponent(0.85))
    }

    // MARK: Baked path data (Design/bikes.js → BikeShapes.swift): absolute M/L/C/Z in the game's y-down units.
    func bakedPath(_ d: String) -> NSBezierPath {
        let path = NSBezierPath()
        var nums: [Double] = [], cmd: Character = " ", token = ""
        func flush() { if !token.isEmpty { nums.append(Double(token) ?? 0); token = "" } }
        func apply() {
            switch cmd {
            case "M": if nums.count >= 2 { path.move(to: NSPoint(x: nums[0], y: nums[1])) }
            case "L": var i = 0; while i + 1 < nums.count { path.line(to: NSPoint(x: nums[i], y: nums[i + 1])); i += 2 }
            case "C": var i = 0; while i + 5 < nums.count { path.curve(to: NSPoint(x: nums[i + 4], y: nums[i + 5]), controlPoint1: NSPoint(x: nums[i], y: nums[i + 1]), controlPoint2: NSPoint(x: nums[i + 2], y: nums[i + 3])); i += 6 }
            case "Z": path.close()
            default: break
            }
            nums.removeAll()
        }
        for ch in d {
            if ch.isLetter { flush(); apply(); cmd = ch; if ch == "Z" { apply(); cmd = " " } }
            else if ch == " " { flush() }
            else { token.append(ch) }
        }
        flush(); apply()
        return path
    }
}
