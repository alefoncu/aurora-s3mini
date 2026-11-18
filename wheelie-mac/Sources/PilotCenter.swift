import Cocoa
import CoreSpotlight

/// "Centro del piloto": diary, workshop puzzles, local leaderboards and secrets in one window.
final class PilotCenter: NSObject {
    private let game: RideView
    let window: NSWindow
    private var boardRoute = 0
    private var boardText: NSTextView!
    private var onStart: () -> Void

    init(game: RideView, onStart: @escaping () -> Void) {
        self.game = game; self.onStart = onStart
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 520), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "Centro del piloto"; window.isReleasedWhenClosed = false; window.minSize = NSSize(width: 480, height: 400)
        super.init()
        let tabs = NSTabView()
        for (title, view) in [("Diario", journalView()), ("Retos de taller", puzzleView()), ("Marcadores", boardView()), ("Secretos", secretsView())] {
            let item = NSTabViewItem(identifier: title); item.label = title; item.view = view; tabs.addTabViewItem(item)
        }
        window.contentView = tabs
        window.center()
    }

    private func textView(_ text: NSAttributedString) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView(); scroll.hasVerticalScroller = true
        guard let tv = scroll.documentView as? NSTextView else { return scroll }
        tv.isEditable = false; tv.textContainerInset = NSSize(width: 14, height: 14); tv.textStorage?.setAttributedString(text)
        tv.setAccessibilityLabel("Contenido")
        return scroll
    }
    private func body(_ s: String, bold: Bool = false, color: NSColor = .labelColor, size: CGFloat = 13) -> NSAttributedString {
        let p = NSMutableParagraphStyle(); p.paragraphSpacing = 4
        return NSAttributedString(string: s, attributes: [.font: bold ? NSFont.systemFont(ofSize: size, weight: .semibold) : NSFont.systemFont(ofSize: size), .foregroundColor: color, .paragraphStyle: p])
    }

    private func journalView() -> NSView {
        let totals = game.stats.totals, found = game.secretsFound
        let out = NSMutableAttributedString()
        let open = RideJournal.unlocked(totals: totals, secrets: found.count).count
        out.append(body("Diario del piloto · \(open)/\(RideJournal.entries.count) páginas\n\n", bold: true, size: 16))
        for e in RideJournal.entries {
            if e.isUnlocked(totals, found.count) { out.append(body(e.title + "\n", bold: true)); out.append(body(e.body + "\n\n")) }
            else { out.append(body("🔒 " + e.title + "\n", bold: true, color: .secondaryLabelColor)); out.append(body(e.unlock + "\n\n", color: .secondaryLabelColor)) }
        }
        let notes = RideSecrets.all().filter { found.contains($0.id) }
        if !notes.isEmpty {
            out.append(body("Notas encontradas\n", bold: true, size: 14))
            for n in notes { out.append(body("★ " + n.note + "\n")) }
        }
        return textView(out)
    }

    private func puzzleView() -> NSView {
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 18, bottom: 16, right: 18)
        let solved = game.solvedPuzzles
        let head = NSTextField(wrappingLabelWithString: "Cada reto fija moto, ruta y ajuste de suspensión. Cumple el objetivo para ganar monedas (\(solved.count)/\(RidePuzzle.all.count) resueltos).")
        head.font = .systemFont(ofSize: 12); head.textColor = .secondaryLabelColor; head.preferredMaxLayoutWidth = 500; stack.addArrangedSubview(head)
        for (i, p) in RidePuzzle.all.enumerated() {
            let title = NSTextField(labelWithString: (solved.contains(p.id) ? "✓ " : "") + p.title + "  ·  +\(p.reward)")
            title.font = .systemFont(ofSize: 13, weight: .semibold)
            let story = NSTextField(wrappingLabelWithString: "\(p.story)\n\(p.vehicle.title) · \(BikePhysics.routeNames[p.route]) · \(p.challenge.title)")
            story.font = .systemFont(ofSize: 11); story.textColor = .secondaryLabelColor; story.preferredMaxLayoutWidth = 380
            let go = NSButton(title: solved.contains(p.id) ? "Repetir" : "Empezar", target: self, action: #selector(startPuzzle(_:))); go.tag = i; go.bezelStyle = .rounded
            go.setAccessibilityLabel("Empezar reto \(p.title)")
            let text = NSStackView(views: [title, story]); text.orientation = .vertical; text.alignment = .leading; text.spacing = 2
            let row = NSStackView(views: [text, go]); row.orientation = .horizontal; row.alignment = .centerY; row.distribution = .fill
            go.setContentHuggingPriority(.required, for: .horizontal)
            stack.addArrangedSubview(row); row.widthAnchor.constraint(equalToConstant: 520).isActive = true
        }
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.documentView = stack; scroll.drawsBackground = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        return scroll
    }
    @objc private func startPuzzle(_ s: NSButton) {
        guard RidePuzzle.all.indices.contains(s.tag) else { return }
        window.orderOut(nil); game.startPuzzle(RidePuzzle.all[s.tag]); onStart()
    }

    private func boardView() -> NSView {
        let box = NSView()
        let popup = NSPopUpButton(frame: .zero, pullsDown: false); popup.addItems(withTitles: BikePhysics.routeNames.map { "Ruta: " + $0 })
        popup.selectItem(at: boardRoute); popup.target = self; popup.action = #selector(boardChanged(_:)); popup.setAccessibilityLabel("Ruta del marcador")
        let scroll = NSTextView.scrollableTextView(); boardText = scroll.documentView as? NSTextView; boardText.isEditable = false; boardText.textContainerInset = NSSize(width: 14, height: 10)
        for v in [popup, scroll] { v.translatesAutoresizingMaskIntoConstraints = false; box.addSubview(v) }
        NSLayoutConstraint.activate([popup.topAnchor.constraint(equalTo: box.topAnchor, constant: 12), popup.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 16),
                                     scroll.topAnchor.constraint(equalTo: popup.bottomAnchor, constant: 8), scroll.leadingAnchor.constraint(equalTo: box.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: box.trailingAnchor), scroll.bottomAnchor.constraint(equalTo: box.bottomAnchor)])
        refreshBoard()
        return box
    }
    @objc private func boardChanged(_ s: NSPopUpButton) { boardRoute = max(0, s.indexOfSelectedItem); refreshBoard() }
    private func refreshBoard() {
        let list = RideLeaderboard.load(game.prefs, route: boardRoute)
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .none
        let out = NSMutableAttributedString(attributedString: body("Mejores partidas · \(BikePhysics.routeNames[boardRoute])\n\n", bold: true, size: 15))
        if list.isEmpty { out.append(body("Todavía no hay partidas en esta ruta. Completa una o cáete con puntos para entrar.", color: .secondaryLabelColor)) }
        for (i, e) in list.enumerated() {
            out.append(body(String(format: "%2d.  %6d puntos   %5d m   %@   %@\n", i + 1, e.score, e.distance, e.vehicle, df.string(from: e.date)), bold: i == 0))
        }
        boardText.textStorage?.setAttributedString(out)
    }

    private func secretsView() -> NSView {
        let found = game.secretsFound, out = NSMutableAttributedString()
        out.append(body("Estrellas ocultas · \(found.count)/\(RideSecrets.all().count)\n\n", bold: true, size: 16))
        out.append(body("Cada ruta esconde tres estrellas sobre la carretera. Salta para alcanzarlas: dan 15 monedas y una página de notas.\n\n", color: .secondaryLabelColor, size: 12))
        for route in 0..<BikePhysics.routeCount {
            let n = RideSecrets.forRoute(route).filter { found.contains($0.id) }.count
            out.append(body("\(BikePhysics.routeNames[route]): \(String(repeating: "★", count: n))\(String(repeating: "☆", count: 3 - n))\n"))
        }
        return textView(out)
    }
}

/// Spotlight entries for every vehicle and route, opened through wheelieride:// links.
enum RideSpotlight {
    static func index() {
        guard !CommandLine.arguments.contains(where: { $0.hasPrefix("--") }) else { return }
        var items = [CSSearchableItem]()
        for kind in BikeKind.allCases {
            let a = CSSearchableItemAttributeSet(contentType: .content); a.title = "\(kind.title) · Wheelie Ride"; a.contentDescription = "Sal a rodar con la \(kind.title)."
            items.append(CSSearchableItem(uniqueIdentifier: "wheelieride://start?vehicle=\(kind.rawValue)", domainIdentifier: "vehicles", attributeSet: a))
        }
        for (i, name) in BikePhysics.routeNames.enumerated() {
            let a = CSSearchableItemAttributeSet(contentType: .content); a.title = "Ruta \(name) · Wheelie Ride"; a.contentDescription = "Rueda por la ruta \(name)."
            items.append(CSSearchableItem(uniqueIdentifier: "wheelieride://start?route=\(i)", domainIdentifier: "routes", attributeSet: a))
        }
        CSSearchableIndex.default().indexSearchableItems(items) { _ in }
    }
}
