import Cocoa

/// Shared input vocabulary. A held action stays active until its matching release.
enum RideAction: String, CaseIterable {
    case throttle, brake, frontBrake, rearBrake, leanBack, leanForward, jump, stunt, stoppie, noHands, spin, superman
}

enum RideCommand {
    case pause, restart, garage, shiftUp, shiftDown
}

private extension NSTouchBarItem.Identifier {
    static let rideThrottle = Self("com.scratch.wheelieride.touchbar.throttle")
    static let rideBrake = Self("com.scratch.wheelieride.touchbar.brake")
    static let rideFrontBrake = Self("com.scratch.wheelieride.touchbar.frontBrake")
    static let rideRearBrake = Self("com.scratch.wheelieride.touchbar.rearBrake")
    static let rideShiftUp = Self("com.scratch.wheelieride.touchbar.shiftUp")
    static let rideShiftDown = Self("com.scratch.wheelieride.touchbar.shiftDown")
    static let rideLeanBack = Self("com.scratch.wheelieride.touchbar.leanBack")
    static let rideLeanForward = Self("com.scratch.wheelieride.touchbar.leanForward")
    static let rideJump = Self("com.scratch.wheelieride.touchbar.jump")
    static let rideStunt = Self("com.scratch.wheelieride.touchbar.stunt")
    static let rideStoppie = Self("com.scratch.wheelieride.touchbar.stoppie")
    static let rideNoHands = Self("com.scratch.wheelieride.touchbar.noHands")
    static let rideSpin = Self("com.scratch.wheelieride.touchbar.spin")
    static let rideSuperman = Self("com.scratch.wheelieride.touchbar.superman")
    static let rideStatus = Self("com.scratch.wheelieride.touchbar.status")
    static let ridePause = Self("com.scratch.wheelieride.touchbar.pause")
    static let rideRestart = Self("com.scratch.wheelieride.touchbar.restart")
    static let rideGarage = Self("com.scratch.wheelieride.touchbar.garage")
}

/// Direct-touch view rather than a button action on release: gas and balance can
/// be held together, including by different fingers on separate Touch Bar items.
private final class RideTouchKey: NSView {
    let symbol: String
    let title: String
    let accent: NSColor
    var onHold: ((Bool) -> Void)?
    var enabled = true {
        didSet {
            if !enabled { cancel() }
            needsDisplay = true
            setAccessibilityEnabled(enabled)
        }
    }
    private var pressed = false
    private var mouseTracking = false
    private var hasDirectTouches = false
    private var accessibilityRelease: DispatchWorkItem?

    init(symbol: String, title: String, accent: NSColor, width: CGFloat = 79) {
        self.symbol = symbol
        self.title = title
        self.accent = accent
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 30))
        allowedTouchTypes = [.direct]
        wantsRestingTouches = false
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: width),
            heightAnchor.constraint(equalToConstant: 30)
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(title)
        setAccessibilityHelp("Mantén pulsado para \(title.lowercased())")
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        let background: NSColor
        if !enabled {
            background = NSColor(white: 0.10, alpha: 1)
        } else if pressed {
            background = accent
        } else {
            background = NSColor(white: 0.20, alpha: 1)
        }
        background.setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6).fill()
        let color = !enabled ? NSColor(white: 0.42, alpha: 1) : NSColor.white
        let value = NSAttributedString(string: "\(symbol)  \(title)", attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: color
        ])
        let size = value.size()
        value.draw(at: NSPoint(x: (bounds.width - size.width) / 2,
                               y: (bounds.height - size.height) / 2))
    }

    private func setHeld(_ value: Bool) {
        let next = value && enabled
        guard next != pressed else { return }
        pressed = next
        setAccessibilityValue(next ? 1 : 0)
        needsDisplay = true
        onHold?(next)
    }

    func cancel() {
        accessibilityRelease?.cancel()
        accessibilityRelease = nil
        mouseTracking = false
        hasDirectTouches = false
        setHeld(false)
    }

    override func touchesBegan(with event: NSEvent) {
        guard enabled else { return }
        hasDirectTouches = event.touches(matching: .touching, in: self).contains { bounds.contains($0.location(in: self)) }
        setHeld(hasDirectTouches || mouseTracking)
    }

    override func touchesMoved(with event: NSEvent) {
        guard enabled else { return }
        hasDirectTouches = event.touches(matching: .touching, in: self).contains { bounds.contains($0.location(in: self)) }
        setHeld(hasDirectTouches || mouseTracking)
    }

    override func touchesEnded(with event: NSEvent) {
        hasDirectTouches = event.touches(matching: .touching, in: self).contains { bounds.contains($0.location(in: self)) }
        setHeld(hasDirectTouches || mouseTracking)
    }

    override func touchesCancelled(with event: NSEvent) { cancel() }

    override func mouseDown(with event: NSEvent) {
        guard enabled else { return }
        mouseTracking = true
        setHeld(true)
    }

    override func mouseDragged(with event: NSEvent) {
        guard mouseTracking else { return }
        let inside = bounds.contains(convert(event.locationInWindow, from: nil))
        setHeld(inside || hasDirectTouches)
    }

    override func mouseUp(with event: NSEvent) {
        mouseTracking = false
        setHeld(hasDirectTouches)
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil { cancel() }
        super.viewWillMove(toWindow: newWindow)
    }

    override func accessibilityPerformPress() -> Bool {
        guard enabled else { return false }
        accessibilityRelease?.cancel()
        setHeld(true)
        let release = DispatchWorkItem { [weak self] in
            self?.setHeld(false)
            self?.accessibilityRelease = nil
        }
        accessibilityRelease = release
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: release)
        return true
    }
}

/// A separate, stable bar for each UI context prevents a saved gameplay
/// customization (or a disabled driving control) from hiding pause actions.
enum RideTouchBarMode: CaseIterable {
    case garage, riding, paused, result, blocked
}

final class TouchBarController: NSObject, NSTouchBarDelegate {
    private(set) var mode: RideTouchBarMode = .garage
    var touchBar: NSTouchBar { bars[mode]! }
    private var bars: [RideTouchBarMode: NSTouchBar] = [:]
    private let onHold: (RideAction, Bool) -> Void
    private let onCommand: (RideCommand) -> Void
    private var keyViews: [RideAction: RideTouchKey] = [:]
    private var statusFields: [(RideTouchBarMode, NSTextField)] = []
    private var commandButtons: [(RideTouchBarMode, RideCommand, NSButton)] = []
    private var speed = 0.0
    private var wheelie = 0.0
    private var stoppie = 0.0
    private var gear = 0
    private var rpm = 0.0
    private var automatic = true
    private var observers: [NSObjectProtocol] = []

    init(onHold: @escaping (RideAction, Bool) -> Void,
         onCommand: @escaping (RideCommand) -> Void) {
        self.onHold = onHold
        self.onCommand = onCommand
        super.init()
        for context in RideTouchBarMode.allCases {
            let bar = NSTouchBar()
            bar.delegate = self
            if context == .riding {
                // Retain existing user gameplay customization only for driving.
                bar.customizationIdentifier = NSTouchBar.CustomizationIdentifier("com.scratch.wheelieride.touchbar")
                bar.defaultItemIdentifiers = [.rideThrottle, .rideLeanBack, .rideLeanForward, .rideBrake,
                                              .flexibleSpace, .rideStatus, .ridePause, .rideRestart]
                bar.customizationAllowedItemIdentifiers = [.rideThrottle, .rideLeanBack, .rideLeanForward,
                    .rideBrake, .rideFrontBrake, .rideRearBrake, .rideShiftUp, .rideShiftDown, .rideJump, .rideStunt, .rideStoppie, .rideNoHands, .rideSpin, .rideSuperman, .rideStatus, .ridePause, .rideRestart,
                    .rideGarage, .flexibleSpace, .fixedSpaceSmall]
                bar.customizationRequiredItemIdentifiers = [.ridePause]
            } else {
                // Context actions are fixed: old saved layouts cannot remove them.
                switch context {
                case .paused:
                    bar.defaultItemIdentifiers = [.rideStatus, .flexibleSpace, .ridePause, .rideRestart, .rideGarage]
                    bar.principalItemIdentifier = .ridePause
                case .garage:
                    bar.defaultItemIdentifiers = [.rideStatus, .flexibleSpace, .rideRestart]
                    bar.principalItemIdentifier = .rideRestart
                case .result:
                    bar.defaultItemIdentifiers = [.rideStatus, .flexibleSpace, .rideRestart, .rideGarage]
                    bar.principalItemIdentifier = .rideRestart
                case .blocked:
                    bar.defaultItemIdentifiers = [.rideStatus]
                case .riding: break
                }
            }
            bars[context] = bar
        }
        for name in [NSApplication.didResignActiveNotification, NSWindow.didResignKeyNotification,
                     NSApplication.willTerminateNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.releaseAll()
            })
        }
    }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }

    /// Telemetry updates preserve the selected NSTouchBar and held controls.
    func update(mode: RideTouchBarMode, speed: Double, wheelie: Double, stoppie: Double = 0, gear: Int = 0, rpm: Double = 0, automatic: Bool = true) {
        if self.mode != mode { releaseAll() }
        self.mode = mode
        self.speed = speed.isFinite ? max(0, speed) : 0
        self.wheelie = wheelie.isFinite ? max(0, wheelie) : 0
        self.stoppie = stoppie.isFinite ? max(0, stoppie) : 0
        self.gear = max(0, min(6, gear))
        self.rpm = rpm.isFinite ? max(0, min(20000, rpm)) : 0
        self.automatic = automatic
        for view in keyViews.values where view.enabled != (mode == .riding) {
            view.enabled = mode == .riding
        }
        refreshStatus()
    }

    /// Compatibility for callers that have not yet supplied a full UI context.
    func update(riding: Bool, paused: Bool, speed: Double, wheelie: Double) {
        update(mode: paused ? .paused : riding ? .riding : .garage, speed: speed, wheelie: wheelie)
    }

    func releaseAll() { keyViews.values.forEach { $0.cancel() } }

    private func status(for context: RideTouchBarMode) -> String {
        switch context {
        case .garage: return "WHEELIE RIDE"
        case .paused: return "EN PAUSA"
        case .result: return "FIN DE RUTA"
        case .blocked: return "NO DISPONIBLE"
        case .riding:
            let engine = gear > 0 ? " · \(automatic ? "A" : "M")\(gear) · \(Int(rpm)) rpm" : ""
            if stoppie>0.2 { return "\(Int(speed*3.6)) · INV \(String(format:"%.1f",stoppie))m" + engine }
            return (wheelie >= 1 ? "\(Int(speed * 3.6)) km/h · \(Int(wheelie)) m" : "\(Int(speed * 3.6)) km/h") + engine
        }
    }

    private func refreshStatus() {
        statusFields.forEach { context, field in field.stringValue = status(for: context) }
        commandButtons.forEach { context, command, button in
            button.isEnabled = mode == context && permits(command)
        }
    }

    private func permits(_ command: RideCommand) -> Bool {
        switch command {
        case .pause: return mode == .riding || mode == .paused
        case .restart, .garage: return mode != .blocked
        case .shiftUp, .shiftDown: return mode == .riding && !automatic && gear > 0
        }
    }

    func touchBar(_ touchBar: NSTouchBar,
                  makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        guard let context = bars.first(where: { $0.value === touchBar })?.key else { return nil }
        let allowed = context == .riding ? touchBar.customizationAllowedItemIdentifiers : touchBar.defaultItemIdentifiers
        guard allowed.contains(identifier) else { return nil }
        let specifications: [NSTouchBarItem.Identifier: (RideAction, String, String, NSColor)] = [
            .rideThrottle: (.throttle, "↑", "GAS", .systemGreen),
            .rideBrake: (.brake, "↓", "FRENO", .systemRed),
            .rideFrontBrake: (.frontBrake, "↓", "DELANTE", .systemRed),
            .rideRearBrake: (.rearBrake, "↓", "DETRÁS", .systemRed),
            .rideLeanBack: (.leanBack, "←", "LEVANTAR", .systemBlue),
            .rideLeanForward: (.leanForward, "→", "BAJAR", .systemBlue),
            .rideJump: (.jump, "↥", "SALTO", .systemOrange),
            .rideStunt: (.stunt, "✦", "TRUCO", .systemPurple),
            .rideStoppie: (.stoppie, "↘", "INVERTIDO", .systemOrange),
            .rideNoHands: (.noHands, "✋", "SIN MANOS", .systemTeal),
            .rideSpin: (.spin, "⟳", "GIRO 360", .systemPink),
            .rideSuperman: (.superman, "✈︎", "SUPERMAN", .systemIndigo)
        ]
        if context == .riding, let (action, symbol, title, accent) = specifications[identifier] {
            let item = NSCustomTouchBarItem(identifier: identifier)
            let view = RideTouchKey(symbol: symbol, title: title, accent: accent,
                                    width: action == .leanBack || action == .stoppie || action == .noHands || action == .superman ? 95 : 79)
            view.enabled = mode == .riding
            view.onHold = { [weak self] held in self?.onHold(action, held) }
            keyViews[action]?.enabled = false
            keyViews[action] = view
            item.view = view
            item.customizationLabel = title.capitalized
            return item
        }
        switch identifier {
        case .rideStatus:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let field = NSTextField(labelWithString: status(for: context))
            field.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            field.alignment = .center
            field.textColor = .white
            field.widthAnchor.constraint(equalToConstant: 210).isActive = true
            statusFields.append((context, field))
            item.view = field
            item.customizationLabel = "Estado"
            return item
        case .ridePause:
            return commandItem(identifier, context: context, command: .pause,
                               symbol: context == .paused ? "play.fill" : "pause.fill",
                               title: context == .paused ? "Continuar" : "Pausa", selector: #selector(pausePressed))
        case .rideRestart:
            let title = context == .garage ? "Rodar" : context == .result ? "Otra vuelta" : "Reiniciar"
            return commandItem(identifier, context: context, command: .restart,
                               symbol: context == .garage ? "play.fill" : "arrow.counterclockwise",
                               title: title, selector: #selector(restartPressed))
        case .rideShiftUp:
            return commandItem(identifier, context: context, command: .shiftUp,
                               symbol: "plus", title: "Subir marcha", selector: #selector(shiftUpPressed))
        case .rideShiftDown:
            return commandItem(identifier, context: context, command: .shiftDown,
                               symbol: "minus", title: "Bajar marcha", selector: #selector(shiftDownPressed))
        case .rideGarage:
            return commandItem(identifier, context: context, command: .garage,
                               symbol: "house.fill", title: "Taller", selector: #selector(garagePressed))
        default: return nil
        }
    }

    private func commandItem(_ identifier: NSTouchBarItem.Identifier, context: RideTouchBarMode,
                             command: RideCommand, symbol: String, title: String,
                             selector: Selector) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)!
        let button: NSButton
        if context == .riding {
            button = NSButton(image: image, target: self, action: selector)
            button.widthAnchor.constraint(equalToConstant: 44).isActive = true
        } else {
            button = NSButton(title: title, image: image, target: self, action: selector)
            button.imagePosition = .imageLeading
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: command == .garage ? 85 : 110).isActive = true
            if command == .pause || context == .garage { button.bezelColor = .systemBlue }
        }
        button.setAccessibilityLabel(title)
        button.isEnabled = mode == context && permits(command)
        commandButtons.append((context, command, button))
        item.view = button
        item.customizationLabel = title
        return item
    }

    @objc private func pausePressed() { send(.pause) }
    @objc private func restartPressed() { send(.restart) }
    @objc private func garagePressed() { send(.garage) }
    @objc private func shiftUpPressed() { send(.shiftUp) }
    @objc private func shiftDownPressed() { send(.shiftDown) }
    private func send(_ command: RideCommand) {
        guard permits(command) else { return }
        // Changing gear must preserve the rider's held gas and balance inputs.
        if command != .shiftUp && command != .shiftDown { releaseAll() }
        onCommand(command)
    }
}
