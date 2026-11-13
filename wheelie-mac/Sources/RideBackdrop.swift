import Cocoa
import QuartzCore

/// The scrolling backdrop as Core Animation layers. Photographs, skies, mountains, city strips and the
/// colour veils are built once; each frame only moves a handful of layers, and the GPU does the compositing.
/// Content is in logical scene units (1280 wide, `height` tall), origin bottom-left, unscaled; the host
/// view scales `root` to the window.
final class RideBackdrop {
    let root = CALayer()
    private(set) var route = -1, night = false, height = 0.0, width = 1280.0, backing: CGFloat = 0
    private let art: RideRenderer
    private var photoTiles: [CALayer] = []
    private var photoNormal: CGImage?, photoMirrored: CGImage?
    private var strips: [(layers: [CALayer], width: Double, factor: Double)] = []
    private var mountains: [(layer: CALayer, period: Double, factor: Double)] = []
    private var fogLayer: CALayer?
    static let tileWidth = 1880.0

    init(art: RideRenderer) {
        self.art = art
        root.anchorPoint = .zero; root.position = .zero; root.masksToBounds = true
    }

    // MARK: Geometry helpers (scene units are y-down in the renderer, layers are y-up)
    private func up(_ y: Double, _ h: Double) -> Double { height - y - h }
    private func frame(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGRect { CGRect(x: x, y: up(y, h), width: w, height: h) }
    private func colorLayer(_ rect: CGRect, _ color: NSColor) -> CALayer {
        let l = CALayer(); l.frame = rect; l.backgroundColor = color.cgColor; l.actions = RideBackdrop.noActions; return l
    }
    /// A vertical gradient: `top` at the top of the rect, `bottom` at the bottom.
    private func gradientLayer(_ rect: CGRect, top: NSColor, bottom: NSColor) -> CAGradientLayer {
        let l = CAGradientLayer(); l.frame = rect; l.colors = [top.cgColor, bottom.cgColor]
        l.startPoint = CGPoint(x: 0.5, y: 1); l.endPoint = CGPoint(x: 0.5, y: 0); l.actions = RideBackdrop.noActions; return l
    }
    static let noActions: [String: CAAction] = ["position": NSNull(), "bounds": NSNull(), "contents": NSNull(), "frame": NSNull(), "hidden": NSNull(), "opacity": NSNull(), "transform": NSNull()]

    /// Render a drawing made with the renderer's y-down helpers into a bitmap, at the screen's pixel density.
    private func bake(width: Double, height h: Double, _ draw: () -> Void) -> CGImage? {
        let scale = max(1, backing), pw = Int((width * Double(scale)).rounded(.up)), ph = Int((h * Double(scale)).rounded(.up))
        guard pw > 0, ph > 0, pw < 20_000, let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: 0, y: h); ctx.scaleBy(x: 1, y: -1)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
        draw()
        NSGraphicsContext.restoreGraphicsState()
        return ctx.makeImage()
    }
    private func scaledPhoto(_ source: NSImage, width: Double, height h: Double, mirror: Bool) -> CGImage? {
        guard let cg = source.cgImage(forProposedRect: nil, context: nil, hints: nil), let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let scale = max(1, backing)
        guard let ctx = CGContext(data: nil, width: Int(width * Double(scale)), height: Int(h * Double(scale)), bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        if mirror { ctx.translateBy(x: CGFloat(width * Double(scale)), y: 0); ctx.scaleBy(x: -1, y: 1) }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width * Double(scale), height: h * Double(scale)))
        return ctx.makeImage()
    }

    // MARK: Building
    /// Rebuild the layer tree when the route, the time of day, the window height or the screen density change.
    func configure(route: Int, night: Bool, width: Double = 1280, height: Double, backing: CGFloat) {
        let h = height.rounded()
        guard route != self.route || night != self.night || h != self.height || width != self.width || backing != self.backing else { return }
        self.route = route; self.night = night; self.height = h; self.width = width; self.backing = backing
        CATransaction.begin(); CATransaction.setDisableActions(true)
        root.sublayers = nil; photoTiles = []; strips = []; mountains = []; fogLayer = nil
        root.bounds = CGRect(x: 0, y: 0, width: width, height: h)
        if h > 700 { root.addSublayer(colorLayer(frame(0, 700, width, h - 700), NSColor(hex: RideBackdrop.earthColor(route)))) }
        switch route {
        case 3: buildSnow()
        case 4: buildCity()
        default: buildPhotos()
        }
        buildVeils()
        // Fog thickens the distance: a mist-coloured sheet whose opacity follows the weather.
        let mist = colorLayer(frame(0, 0, width, h), NSColor(hex: night ? 0x59627A : 0xD5DCE0)); mist.opacity = Float(lastFog)
        root.addSublayer(mist); fogLayer = mist
        for layer in root.sublayers ?? [] { layer.contentsScale = backing }
        CATransaction.commit()
        update(camera: lastCamera)
    }
    static func earthColor(_ route: Int) -> Int { route == 0 ? 0x7A725E : route == 3 ? 0xB7C3CB : route == 4 ? 0x3A3F47 : 0x8F694B }

    private func buildPhotos() {
        let source = route == 2 ? art.desert : art.landscape
        let w = Self.tileWidth + 0.5
        if let source {
            photoNormal = scaledPhoto(source, width: w, height: 590, mirror: false)
            photoMirrored = scaledPhoto(source, width: w, height: 590, mirror: true)
        } else {
            // Without the bundled photograph (tests, bare binary) fall back to a plain sky and hills.
            photoNormal = bake(width: w, height: 590) { art.gradient(NSRect(x: 0, y: 0, width: w, height: 590), NSColor(hex: 0xADD0E4), NSColor(hex: 0xD6DBB8)) }
            photoMirrored = photoNormal
        }
        for _ in 0..<2 {
            let tile = CALayer(); tile.anchorPoint = .zero; tile.bounds = CGRect(x: 0, y: 0, width: w, height: 590)
            tile.contentsGravity = .resize; tile.magnificationFilter = .nearest; tile.actions = Self.noActions
            photoTiles.append(tile); root.addSublayer(tile)
        }
    }

    private func buildSnow() {
        root.addSublayer(gradientLayer(frame(0, 0, width, 560), top: NSColor(hex: 0xBFD3E2), bottom: NSColor(hex: 0xF0F4F6)))
        let colors = [0xDDE7EE, 0xC6D4E0, 0xAEC1D2, 0x8FA6BB]
        for layerIndex in 0..<4 {
            let period = Double(150 + layerIndex * 40), span = Double.pi * period      // |sin| repeats every pi * period
            let layer = CAShapeLayer(), width = 1320 + span
            layer.anchorPoint = .zero; layer.bounds = CGRect(x: 0, y: 0, width: width, height: height); layer.actions = Self.noActions
            let path = CGMutablePath(); path.move(to: CGPoint(x: 0, y: up(600, 0)))
            for x in stride(from: 0.0, through: width, by: 14) {
                let y = 215 + Double(layerIndex) * 58 - abs(sin((x - 20) / period)) * 92 * (1 - Double(layerIndex) * 0.18) + cos((x - 20) / 57) * 9
                path.addLine(to: CGPoint(x: x, y: up(y, 0)))
            }
            path.addLine(to: CGPoint(x: width, y: up(600, 0))); path.closeSubpath()
            layer.path = path; layer.fillColor = NSColor(hex: colors[layerIndex]).cgColor
            mountains.append((layer, period, 0.05 * Double(layerIndex + 1))); root.addSublayer(layer)
        }
    }

    private func buildCity() {
        let night = self.night
        root.addSublayer(gradientLayer(frame(0, 0, width, 560), top: NSColor(hex: night ? 0x10172A : 0x39425A), bottom: NSColor(hex: night ? 0x2B3550 : 0x7B8498)))
        let count = 24
        for layerIndex in 0..<3 {
            let width = 95.0 + Double(layerIndex) * 15, stripWidth = Double(count) * width
            let image = bake(width: stripWidth, height: 620) { art.cityStrip(layer: layerIndex, count: count, width: width, night: night) }
            var layers: [CALayer] = []
            for _ in 0..<2 {
                let l = CALayer(); l.anchorPoint = .zero; l.bounds = CGRect(x: 0, y: 0, width: stripWidth, height: 620)
                l.contents = image; l.contentsGravity = .resize; l.actions = Self.noActions
                layers.append(l); root.addSublayer(l)
            }
            strips.append((layers, stripWidth, 0.03 + Double(layerIndex) * 0.025))
        }
        root.addSublayer(colorLayer(frame(0, 0, width, 600), NSColor(hex: 0x0B1626, alpha: night ? 0.35 : 0.18)))
    }

    /// Tints, the night sky and the haze: static, so they cost nothing per frame.
    private func buildVeils() {
        if route == 2 {
            root.addSublayer(colorLayer(frame(0, 0, width, 570), NSColor(hex: 0xEEB06A, alpha: 0.23)))
            root.addSublayer(gradientLayer(frame(0, 0, width, 320), top: NSColor(hex: 0x5C4165, alpha: 0.22), bottom: .clear))
        }
        if night {
            root.addSublayer(colorLayer(frame(0, 0, width, 600), NSColor(hex: 0x101F3F, alpha: 0.66)))
            let moon = CAShapeLayer(); moon.frame = CGRect(x: 0, y: 0, width: width, height: height); moon.actions = Self.noActions
            moon.path = CGPath(ellipseIn: CGRect(x: 1090 - 29, y: up(85, 0) - 29, width: 58, height: 58), transform: nil)
            moon.fillColor = NSColor(hex: 0xFFF0CB, alpha: 0.8).cgColor; root.addSublayer(moon)
            let stars = CAShapeLayer(); stars.frame = moon.frame; stars.actions = Self.noActions
            let starPath = CGMutablePath()
            let spread = Int(width)
            for i in 0..<38 {
                let sx = Double((i * 137 + 53) % spread) - 1, sy = up(Double((i * 41 + 17) % 220), 0) - 1
                starPath.addEllipse(in: CGRect(x: sx, y: sy, width: 2, height: 2))
            }
            stars.path = starPath; stars.fillColor = NSColor.white.withAlphaComponent(0.58).cgColor; root.addSublayer(stars)
        }
        let haze = NSColor(hex: night ? 0x324A47 : 0xC1B58A, alpha: 0.25)
        root.addSublayer(gradientLayer(frame(0, 270, width, 290), top: .clear, bottom: haze))
    }

    // MARK: Per-frame update
    private var lastCamera = 0.0, lastFog = 0.0
    func setFog(_ opacity: Double) {
        lastFog = max(0, min(1, opacity.isFinite ? opacity : 0))
        CATransaction.begin(); CATransaction.setDisableActions(true); fogLayer?.opacity = Float(lastFog); CATransaction.commit()
    }
    /// Slide the layers for a camera position in backdrop pixels (metres x 108).
    func update(camera: Double) {
        lastCamera = camera
        guard camera.isFinite, height > 0 else { return }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        switch route {
        case 3:
            for m in mountains {
                let span = Double.pi * m.period, off = camera * m.factor
                m.layer.position = CGPoint(x: -20 - off.truncatingRemainder(dividingBy: span), y: 0)
            }
        case 4:
            for s in strips {
                var x0 = -(camera * s.factor).truncatingRemainder(dividingBy: s.width)
                if x0 > 0 { x0 -= s.width }
                s.layers[0].position = CGPoint(x: x0, y: up(0, 620)); s.layers[1].position = CGPoint(x: x0 + s.width, y: up(0, 620))
            }
        default:
            let w = Self.tileWidth, scroll = camera * 0.045, first = Int(floor(scroll / w))
            for k in 0..<2 where k < photoTiles.count {
                let n = first + k
                photoTiles[k].position = CGPoint(x: Double(n) * w - scroll, y: up(-30, 590))
                photoTiles[k].contents = n % 2 == 0 ? photoNormal : photoMirrored   // alternate tiles mirror so seams match
            }
        }
        CATransaction.commit()
    }

    /// Horizontal extents of the scrolling pieces (photo tiles or city strips), for coverage tests.
    var scrollingSpans: [ClosedRange<Double>] {
        let layers: [CALayer] = route == 4 ? strips.flatMap(\.layers) : photoTiles
        return layers.map { Double($0.position.x)...Double($0.position.x + $0.bounds.width) }
    }
    var mountainSpans: [ClosedRange<Double>] { mountains.map { Double($0.layer.position.x)...Double($0.layer.position.x + $0.layer.bounds.width) } }
    var stripSpans: [[ClosedRange<Double>]] {
        strips.map { s in s.layers.map { Double($0.position.x)...Double($0.position.x + $0.bounds.width) } }
    }
}

/// The darkening at the top and bottom of the screen, as two static gradient layers drawn above the world.
final class RideOverlay {
    let root = CALayer()
    private var height = 0.0, width = 1280.0
    private var mist: CALayer?, flash: CALayer?
    init() { root.anchorPoint = .zero; root.position = .zero; root.masksToBounds = true }
    func configure(width: Double = 1280, height: Double) {
        let h = height.rounded(); guard h != self.height || width != self.width else { return }
        self.height = h; self.width = width
        CATransaction.begin(); CATransaction.setDisableActions(true)
        root.sublayers = nil; root.bounds = CGRect(x: 0, y: 0, width: width, height: h)
        func gradient(_ rect: CGRect, _ top: NSColor, _ bottom: NSColor) {
            let l = CAGradientLayer(); l.frame = rect; l.colors = [top.cgColor, bottom.cgColor]
            l.startPoint = CGPoint(x: 0.5, y: 1); l.endPoint = CGPoint(x: 0.5, y: 0); l.actions = RideBackdrop.noActions; root.addSublayer(l)
        }
        gradient(CGRect(x: 0, y: h - 165, width: width, height: 165), NSColor.black.withAlphaComponent(0.32), .clear)
        gradient(CGRect(x: 0, y: 0, width: width, height: 130), .clear, NSColor.black.withAlphaComponent(0.50))
        let mist = CALayer(); mist.frame = CGRect(x: 0, y: 0, width: width, height: h); mist.backgroundColor = NSColor(hex: 0xD5DCE0).cgColor; mist.opacity = 0; mist.actions = RideBackdrop.noActions
        let flash = CALayer(); flash.frame = mist.frame; flash.backgroundColor = NSColor(hex: 0xF4F8FF).cgColor; flash.opacity = 0; flash.actions = RideBackdrop.noActions
        root.addSublayer(mist); root.addSublayer(flash); self.mist = mist; self.flash = flash
        CATransaction.commit()
    }
    /// Fog over the world (a light veil) and the lightning flash, both as opacities of static layers.
    func setWeather(fog: Double, flash level: Double) {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        mist?.opacity = Float(max(0, min(1, fog.isFinite ? fog : 0))); flash?.opacity = Float(max(0, min(1, level.isFinite ? level : 0)))
        CATransaction.commit()
    }
}
