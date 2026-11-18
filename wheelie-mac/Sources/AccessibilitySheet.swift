import Cocoa

/// A button that records the next key pressed, for remapping controls.
final class KeyCaptureButton: NSButton {
    var onKey: ((UInt16) -> Bool)?
    var idle = ""
    override var acceptsFirstResponder: Bool { true }
    override func keyDown(with event: NSEvent) {
        guard window?.firstResponder === self else { return }
        if event.keyCode == 53 { title = idle; window?.makeFirstResponder(nil); return }
        if onKey?(event.keyCode) == false { NSSound.beep(); title = "Reservada"; return }
        window?.makeFirstResponder(nil)
    }
    override func resignFirstResponder() -> Bool { if title == "Pulsa una tecla…" { title = idle }; return super.resignFirstResponder() }
}

/// "Accesibilidad y controles": system-aware accessibility options, assists, feedback and key remapping.
final class AccessibilitySheet {
    private let game: RideView, done: () -> Void
    let panel: NSPanel
    private var captureButtons = [RideAction: KeyCaptureButton]()
    private let labels: [(RideAction, String)] = [(.throttle, "Acelerar"), (.brake, "Frenos"), (.leanBack, "Levantar (caballito)"), (.leanForward, "Peso delante"), (.jump, "Saltar"),
                                                  (.stunt, "Voltereta"), (.stoppie, "Invertido"), (.frontBrake, "Freno delantero"), (.rearBrake, "Freno trasero"), (.noHands, "Sin manos"), (.spin, "Giro 360°"), (.superman, "Superman")]

    init(game: RideView, done: @escaping () -> Void) {
        self.game = game; self.done = done
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 520, height: 500), styleMask: [.titled], backing: .buffered, defer: false)
        panel.title = "Accesibilidad y controles"
        build()
    }
    private func check(_ title: String, _ on: Bool, _ help: String, _ action: @escaping (Bool) -> Void) -> NSView {
        let b = ClosureButton(checkboxWithTitle: title, target: nil, action: nil)
        b.state = on ? .on : .off; b.handler = { action($0.state == .on) }; b.setAccessibilityHelp(help); b.toolTip = help
        return b
    }
    private func heading(_ t: String) -> NSTextField { let l = NSTextField(labelWithString: t); l.font = .systemFont(ofSize: 13, weight: .semibold); return l }
    private func build() {
        let content = NSView(); panel.contentView = content
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 8
        let title = NSTextField(labelWithString: "Accesibilidad y controles"); title.font = .systemFont(ofSize: 20, weight: .bold)
        stack.addArrangedSubview(title)
        let note = NSTextField(wrappingLabelWithString: "Los ajustes del sistema (Reducir movimiento, Aumentar contraste, Diferenciar sin color) se respetan siempre; aquí puedes activarlos solo para el juego.")
        note.font = .systemFont(ofSize: 11); note.textColor = .secondaryLabelColor; note.preferredMaxLayoutWidth = 460; stack.addArrangedSubview(note)
        stack.addArrangedSubview(heading("Vista"))
        stack.addArrangedSubview(check("Reducir movimiento (sin zoom de cámara, menos polvo, sin relámpagos)", game.access.reduceMotionApp, "Menos movimiento en pantalla.") { [game] in game.access.reduceMotionApp = $0; game.applyAccess() })
        stack.addArrangedSubview(check("Aumentar contraste del marcador", game.access.highContrastApp, "Placas oscuras tras los textos.") { [game] in game.access.highContrastApp = $0; game.applyAccess() })
        stack.addArrangedSubview(check("No depender solo del color (símbolos ▲ ▼ ★ ⚠)", game.access.noColorOnlyApp, "Añade símbolos a los estados que usan color.") { [game] in game.access.noColorOnlyApp = $0; game.applyAccess() })
        let size = NSPopUpButton(frame: .zero, pullsDown: false); size.addItems(withTitles: ["Texto del marcador: normal", "Texto del marcador: grande", "Texto del marcador: muy grande"])
        size.selectItem(at: RideAccess.textScales.firstIndex(of: game.access.textScale) ?? 0); size.setAccessibilityLabel("Tamaño del texto del marcador")
        size.target = self; size.action = #selector(sizeChanged(_:)); stack.addArrangedSubview(size); sizePopup = size
        let hints = NSPopUpButton(frame: .zero, pullsDown: false); hints.addItems(withTitles: ["Ayudas de teclas: siempre", "Ayudas de teclas: solo las primeras salidas", "Ayudas de teclas: nunca"])
        hints.selectItem(at: game.access.hintsMode); hints.setAccessibilityLabel("Ayudas de teclas"); hints.target = self; hints.action = #selector(hintsChanged(_:)); stack.addArrangedSubview(hints); hintsPopup = hints
        stack.addArrangedSubview(heading("Ayudas y sensaciones"))
        stack.addArrangedSubview(check("Equilibrio asistido (corrige caballito e invertido antes de caer)", game.access.autoBalance, "Empuja el peso del piloto para no volcar.") { [game] in game.access.autoBalance = $0; game.applyAccess() })
        stack.addArrangedSubview(check("Háptica del trackpad", game.access.haptics, "Pulso al aterrizar, en el punto de equilibrio y al caer.") { [game] in game.access.haptics = $0; game.applyAccess() })
        let padName = game.feedback.controllerName.map { "Mando de juego (\($0) conectado)" } ?? "Mando de juego (ninguno conectado)"
        stack.addArrangedSubview(check(padName, game.access.gamepad, "RT acelera, LT/B frenan, stick o cruceta inclinan, X salta, Y voltereta, LB invertido, RB sin manos, Menú pausa.") { [game] in game.access.gamepad = $0; game.applyAccess() })
        stack.addArrangedSubview(heading("Teclas"))
        let rows = NSStackView(); rows.orientation = .vertical; rows.alignment = .leading; rows.spacing = 4
        for (action, name) in labels {
            let label = NSTextField(labelWithString: name); label.font = .systemFont(ofSize: 12); label.widthAnchor.constraint(equalToConstant: 200).isActive = true
            let b = KeyCaptureButton(title: game.keyMap.label(action), target: self, action: #selector(capture(_:)))
            b.bezelStyle = .rounded; b.controlSize = .small; b.idle = b.title; b.identifier = NSUserInterfaceItemIdentifier(action.rawValue); b.setAccessibilityLabel("Tecla de \(name)")
            b.widthAnchor.constraint(equalToConstant: 150).isActive = true
            b.onKey = { [weak self] code in
                guard let self else { return true }
                guard self.game.keyMap.assign(action, key: code) else { return false }
                self.game.keyMap.save(self.game.prefs); self.refreshKeys(); return true
            }
            captureButtons[action] = b
            let row = NSStackView(views: [label, b]); row.orientation = .horizontal; row.spacing = 10
            rows.addArrangedSubview(row)
        }
        // The key list scrolls, so the sheet fits the smallest game window.
        let fit = rows.fittingSize
        let holder = FlippedView(frame: NSRect(x: 0, y: 0, width: 440, height: fit.height + 12))
        rows.frame = NSRect(x: 8, y: 6, width: fit.width, height: fit.height); holder.addSubview(rows)
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.drawsBackground = false; scroll.borderType = .bezelBorder
        scroll.documentView = holder; scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(scroll)
        NSLayoutConstraint.activate([scroll.heightAnchor.constraint(equalToConstant: 120), scroll.widthAnchor.constraint(equalToConstant: 460)])
        let reset = NSButton(title: "Restaurar teclas", target: self, action: #selector(resetKeys)); reset.controlSize = .small
        stack.addArrangedSubview(reset)
        let ok = NSButton(title: "Listo", target: self, action: #selector(close)); ok.bezelStyle = .rounded; ok.keyEquivalent = "\r"; ok.bezelColor = .controlAccentColor
        content.addSubview(stack); content.addSubview(ok)
        stack.translatesAutoresizingMaskIntoConstraints = false; ok.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28), stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 22), stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28),
                                     ok.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -26), ok.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -18), ok.widthAnchor.constraint(equalToConstant: 96),
                                     stack.bottomAnchor.constraint(lessThanOrEqualTo: ok.topAnchor, constant: -10)])
    }
    private var sizePopup: NSPopUpButton!, hintsPopup: NSPopUpButton!
    @objc private func sizeChanged(_ s: NSPopUpButton) { game.access.textScale = RideAccess.textScales[max(0, s.indexOfSelectedItem)]; game.applyAccess() }
    @objc private func hintsChanged(_ s: NSPopUpButton) { game.access.hintsMode = s.indexOfSelectedItem; game.applyAccess() }
    @objc private func capture(_ s: KeyCaptureButton) { s.title = "Pulsa una tecla…"; panel.makeFirstResponder(s) }
    private func refreshKeys() { for (a, b) in captureButtons { b.title = game.keyMap.label(a); b.idle = b.title } }
    @objc private func resetKeys() { game.keyMap.reset(); game.keyMap.save(game.prefs); refreshKeys() }
    @objc private func close() { done() }
}

/// Top-left origin, so a scroll view starts at the first row.
final class FlippedView: NSView { override var isFlipped: Bool { true } }

/// A checkbox that reports its own state to a closure.
final class ClosureButton: NSButton {
    var handler: ((NSButton) -> Void)?
    override init(frame: NSRect) { super.init(frame: frame); wire() }
    required init?(coder: NSCoder) { super.init(coder: coder); wire() }
    convenience init(checkboxWithTitle t: String, target: AnyObject?, action: Selector?) { self.init(frame: .zero); setButtonType(.switch); title = t }
    private func wire() { target = self; action = #selector(fire) }
    @objc private func fire() { handler?(self) }
}
