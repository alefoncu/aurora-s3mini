import Cocoa

/// The sky follows the route: a warm dawn, a clear midday, an amber dusk. Night keeps its own look.
enum RideDaylight {
    static func wash(progress: Double, night: Bool) -> (color: NSColor, opacity: Double) {
        guard !night, progress.isFinite else { return (.clear, 0) }
        let p = max(0, min(1, progress))
        let dawn = NSColor(srgbRed: 1.0, green: 0.62, blue: 0.38, alpha: 1), dusk = NSColor(srgbRed: 1.0, green: 0.45, blue: 0.30, alpha: 1)
        if p < 0.3 { return (dawn, 0.20 * (1 - p / 0.3)) }
        if p < 0.6 { return (dawn, 0) }
        return (dusk, 0.24 * (p - 0.6) / 0.4)
    }
}
