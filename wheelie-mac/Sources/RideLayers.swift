import Cocoa
import QuartzCore

/// Hosts a Core Animation layer tree (the backdrop or the screen-edge shading) and scales it to the window.
/// Layers are composited by the GPU; this view never draws anything itself and never takes mouse events.
final class RideLayerHost: NSView {
    private let content: CALayer
    init(content: CALayer) {
        self.content = content
        super.init(frame: .zero)
        wantsLayer = true
        autoresizingMask = [.width, .height]
        layer?.addSublayer(content)
    }
    required init?(coder: NSCoder) { nil }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    /// Scale the 1280-unit-wide scene content to the view's width.
    func fit(scale: Double) {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        content.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        CATransaction.commit()
    }
}

/// A transparent view whose drawing is supplied by the game: the world (`.scene`) or the HUD (`.hud`).
/// Only these two views are rasterised by the CPU; everything behind them is layers.
final class RideDrawView: NSView {
    enum Role { case scene, hud }
    private let role: Role
    weak var game: RideView?
    /// Frames actually rasterised, for `--fps`.
    private(set) var drawCount = 0
    init(role: Role) {
        self.role = role
        super.init(frame: .zero)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        autoresizingMask = [.width, .height]
    }
    required init?(coder: NSCoder) { nil }
    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) {
        drawCount += 1
        switch role { case .scene: game?.drawScene(); case .hud: game?.drawHUDLayer() }
    }
}

extension RideView {
    /// A composite of the whole scene for screenshots and tests: the backdrop and shading layers are rendered
    /// in software (the screen uses the GPU), the world and HUD are drawn by the same code as on screen.
    func snapshotRep(scale: CGFloat = 2) -> NSBitmapImageRep? {
        window?.contentView?.layoutSubtreeIfNeeded()        // let the split view settle (collapsed side panels) before measuring
        let size = bounds.size
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale), bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let graphics = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        rep.size = size
        let cg = graphics.cgContext
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        cg.scaleBy(x: scale, y: scale)                       // points, origin bottom-left
        if mode == .garage {
            cg.translateBy(x: 0, y: size.height); cg.scaleBy(x: 1, y: -1)
            NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
            drawGarage()
            return rep
        }
        updateGeometry()
        invalidateLayers()
        func renderLayers(_ root: CALayer) {
            cg.saveGState(); cg.scaleBy(x: CGFloat(viewportScale), y: CGFloat(viewportScale)); root.render(in: cg); cg.restoreGState()
        }
        func drawFlipped(_ body: () -> Void) {
            cg.saveGState(); cg.translateBy(x: 0, y: size.height); cg.scaleBy(x: 1, y: -1)
            NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
            body()
            cg.restoreGState()
        }
        renderLayers(backdrop.root)
        drawFlipped { drawScene() }
        renderLayers(overlay.root)
        drawFlipped { drawHUDLayer() }
        return rep
    }
}
