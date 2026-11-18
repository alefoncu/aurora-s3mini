import Cocoa

/// One reading of the run, taken a few times per second for the post-ride chart.
struct RunSample: Equatable { var distance: Double, speed: Double, trick: Int }   // trick: 0 none, 1 wheelie, 2 stoppie, 3 air

/// Speed along the route with bands for wheelies, stoppies and jumps. Reads the samples the ride recorded.
final class RideRunChart: NSView {
    var samples: [RunSample] = [] { didSet { needsDisplay = true; refreshAccessibility() } }
    override var isFlipped: Bool { true }
    override init(frame: NSRect) { super.init(frame: frame); setAccessibilityElement(true); setAccessibilityRole(.image) }
    required init?(coder: NSCoder) { nil }
    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: 84) }

    /// Plain-language summary, also used by VoiceOver.
    static func summary(_ s: [RunSample]) -> String {
        guard let top = s.map(\.speed).max(), let end = s.last else { return "Sin datos" }
        func share(_ t: Int) -> Int { Int((Double(s.filter { $0.trick == t }.count) / Double(s.count) * 100).rounded()) }
        return "Velocidad máxima \(Int(top * 3.6)) km/h en \(Int(end.distance)) m. Caballito \(share(1)) % del tiempo, invertido \(share(2)) %, en el aire \(share(3)) %."
    }
    private func refreshAccessibility() { setAccessibilityLabel("Gráfica de la ruta"); setAccessibilityValue(Self.summary(samples)) }

    override func draw(_ dirtyRect: NSRect) {
        guard samples.count > 1 else { return }
        let r = bounds.insetBy(dx: 2, dy: 6).offsetBy(dx: 0, dy: -4), top = max(samples.map(\.speed).max() ?? 1, 1)
        let step = r.width / CGFloat(samples.count - 1)
        func x(_ i: Int) -> CGFloat { r.minX + CGFloat(i) * step }
        func y(_ v: Double) -> CGFloat { r.maxY - CGFloat(v / top) * (r.height - 14) }
        let colors: [Int: NSColor] = [1: .systemGreen, 2: .systemPurple, 3: .systemOrange]
        for (i, s) in samples.enumerated() where s.trick > 0 {
            (colors[s.trick] ?? .clear).withAlphaComponent(0.28).setFill()
            NSRect(x: x(i) - step / 2, y: r.minY + 8, width: max(step, 1), height: r.height - 8).fill()
        }
        let area = NSBezierPath(); area.move(to: NSPoint(x: x(0), y: r.maxY))
        for (i, s) in samples.enumerated() { area.line(to: NSPoint(x: x(i), y: y(s.speed))) }
        area.line(to: NSPoint(x: x(samples.count - 1), y: r.maxY)); area.close()
        NSColor.white.withAlphaComponent(0.14).setFill(); area.fill()
        let line = NSBezierPath()
        for (i, s) in samples.enumerated() { let p = NSPoint(x: x(i), y: y(s.speed)); i == 0 ? line.move(to: p) : line.line(to: p) }
        NSColor.white.withAlphaComponent(0.92).setStroke(); line.lineWidth = 1.6; line.lineJoinStyle = .round; line.stroke()
        let font = NSFont.systemFont(ofSize: 9.5)
        let legend = NSMutableAttributedString(string: "Velocidad máx. \(Int(top * 3.6)) km/h    ", attributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor])
        for (name, color) in [("caballito", NSColor.systemGreen), ("invertido", .systemPurple), ("aire", .systemOrange)] {
            legend.append(NSAttributedString(string: "▮ ", attributes: [.font: font, .foregroundColor: color]))
            legend.append(NSAttributedString(string: name + "   ", attributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor]))
        }
        legend.draw(at: NSPoint(x: r.minX, y: r.minY - 4))
    }
}
