import Cocoa

/// Thumbnails of the real vehicle artwork for the garage list, drawn by the same code as the game.
enum GarageThumbnails {
    private static let renderer = RideRenderer()
    private static var cache: [BikeKind: NSImage] = [:]
    /// A distinct, saturated paint per vehicle so the list is easy to scan.
    static func paint(_ kind: BikeKind) -> NSColor {
        switch kind {
        case .commuter: return NSColor(hex: 0xE8A21F)
        case .motocross: return NSColor(hex: 0xF2631C)
        case .sport: return NSColor(hex: 0xD8352B)
        case .bmx: return NSColor(hex: 0x2FA4D9)
        case .scooter: return NSColor(hex: 0x4CBF9A)
        case .scrambler: return NSColor(hex: 0x8C6B3F)
        case .trials: return NSColor(hex: 0xC8CD2E)
        case .hyperbike: return NSColor(hex: 0x2A62E0)
        case .cruiser: return NSColor(hex: 0x7A1F2B)
        case .electric: return NSColor(hex: 0x35D07F)
        }
    }
    static func image(for kind: BikeKind, size: NSSize = NSSize(width: 70, height: 42)) -> NSImage {
        if let cached = cache[kind] { return cached }
        let paintColor = paint(kind)
        let image = NSImage(size: size, flipped: true) { rect in
            let rig = kind.rig, u = rig.drawingUnitsPerMetre, radius = rig.wheelRadius * u
            let widthUnits = rig.wheelbase * u + radius * 2 + 34, heightUnits = radius + 92
            let scale = min(rect.width / widthUnits, rect.height / heightUnits)
            renderer.body = paintColor; renderer.wheelBlur = 0; renderer.livery = .none
            let ax = (rect.width - rig.wheelbase * u * scale) / 2, ay = rect.height - 2 - radius * scale
            renderer.motorcycle(x: ax, y: ay, scale: scale, angle: 0, kind: kind, rotation: 0, time: 0, showRider: false)
            return true
        }
        cache[kind] = image
        return image
    }
}
