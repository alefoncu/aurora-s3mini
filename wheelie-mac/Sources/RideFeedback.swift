import Cocoa
import GameController
import CoreHaptics

/// Player options for accessibility, assists and feedback. System accessibility settings always win over the app's own.
struct RideAccess: Equatable {
    var reduceMotionApp = false, highContrastApp = false, noColorOnlyApp = false
    var textScale = 1.0
    var autoBalance = false
    var haptics = true, gamepad = true
    /// 0 = always, 1 = first rides only, 2 = never
    var hintsMode = 1

    var reduceMotion: Bool { reduceMotionApp || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    var highContrast: Bool { highContrastApp || NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast }
    var noColorOnly: Bool { noColorOnlyApp || NSWorkspace.shared.accessibilityDisplayShouldDifferentiateWithoutColor }

    static let textScales = [1.0, 1.15, 1.3]

    static func load(_ p: UserDefaults) -> RideAccess {
        var a = RideAccess()
        a.reduceMotionApp = p.bool(forKey: "acc.reduceMotion"); a.highContrastApp = p.bool(forKey: "acc.contrast"); a.noColorOnlyApp = p.bool(forKey: "acc.noColor")
        let s = p.double(forKey: "acc.textScale"); a.textScale = textScales.contains(s) ? s : 1
        a.autoBalance = p.bool(forKey: "acc.autoBalance")
        a.haptics = p.object(forKey: "acc.haptics") == nil ? true : p.bool(forKey: "acc.haptics")
        a.gamepad = p.object(forKey: "acc.gamepad") == nil ? true : p.bool(forKey: "acc.gamepad")
        a.hintsMode = p.object(forKey: "acc.hints") == nil ? 1 : max(0, min(2, p.integer(forKey: "acc.hints")))
        return a
    }
    func save(_ p: UserDefaults) {
        p.set(reduceMotionApp, forKey: "acc.reduceMotion"); p.set(highContrastApp, forKey: "acc.contrast"); p.set(noColorOnlyApp, forKey: "acc.noColor")
        p.set(textScale, forKey: "acc.textScale"); p.set(autoBalance, forKey: "acc.autoBalance")
        p.set(haptics, forKey: "acc.haptics"); p.set(gamepad, forKey: "acc.gamepad"); p.set(hintsMode, forKey: "acc.hints")
    }
}

/// Moments worth feeling: the trackpad gives a tap, a controller rumbles.
enum RideFeel {
    case landing(Double), crash, finish, balance, coin, shift, obstacle, secret
}

/// Trackpad haptics plus controller input and rumble. Everything degrades silently on Macs without them.
final class RideFeedback {
    var enabled = true
    var onPad: ((Set<RideAction>) -> Void)?
    var onCommand: ((RideCommand) -> Void)?
    private var lastEvent = [String: Double]()
    private var engines = [ObjectIdentifier: CHHapticEngine]()
    private(set) var controllerName: String?
    private var padEnabled = true
    private var lastShift = (up: false, down: false)

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(connected(_:)), name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(disconnected(_:)), name: .GCControllerDidDisconnect, object: nil)
        GCController.controllers().forEach(attach)
    }
    var padConnected: Bool { controllerName != nil }
    func setPadEnabled(_ on: Bool) { padEnabled = on; if !on { onPad?([]) } }

    @objc private func connected(_ n: Notification) { if let c = n.object as? GCController { attach(c) } }
    @objc private func disconnected(_ n: Notification) {
        if let c = n.object as? GCController { engines[ObjectIdentifier(c)] = nil }
        controllerName = GCController.controllers().first?.vendorName
        onPad?([])
    }
    private func attach(_ controller: GCController) {
        controllerName = controller.vendorName ?? "Mando"
        guard let pad = controller.extendedGamepad else { return }
        pad.valueChangedHandler = { [weak self] pad, _ in self?.read(pad) }
        if let engine = controller.haptics?.createEngine(withLocality: .default) {
            try? engine.start(); engine.resetHandler = { try? engine.start() }
            engines[ObjectIdentifier(controller)] = engine
        }
    }
    private func read(_ pad: GCExtendedGamepad) {
        guard padEnabled else { return }
        var s = RidePadState()
        s.leftX = Double(pad.leftThumbstick.xAxis.value); s.leftY = Double(pad.leftThumbstick.yAxis.value)
        s.leftTrigger = Double(pad.leftTrigger.value); s.rightTrigger = Double(pad.rightTrigger.value)
        s.a = pad.buttonA.isPressed; s.b = pad.buttonB.isPressed; s.x = pad.buttonX.isPressed; s.y = pad.buttonY.isPressed
        s.leftShoulder = pad.leftShoulder.isPressed; s.rightShoulder = pad.rightShoulder.isPressed
        s.dpadUp = pad.dpad.up.isPressed; s.dpadDown = pad.dpad.down.isPressed; s.dpadLeft = pad.dpad.left.isPressed; s.dpadRight = pad.dpad.right.isPressed
        let up = pad.rightThumbstickButton?.isPressed ?? false, down = pad.leftThumbstickButton?.isPressed ?? false
        if up && !lastShift.up { onCommand?(.shiftUp) }
        if down && !lastShift.down { onCommand?(.shiftDown) }
        lastShift = (up, down)
        let menu = pad.buttonMenu.isPressed
        if menu && !menuDown { onCommand?(.pause) }; menuDown = menu
        onPad?(RidePadMap.actions(s))
    }
    private var menuDown = false

    func play(_ feel: RideFeel) {
        guard enabled else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let (key, gap): (String, Double)
        switch feel {
        case .landing: (key, gap) = ("landing", 0.12)
        case .crash: (key, gap) = ("crash", 0.4)
        case .finish: (key, gap) = ("finish", 0.5)
        case .balance: (key, gap) = ("balance", 0.35)
        case .coin, .secret: (key, gap) = ("coin", 0.1)
        case .shift: (key, gap) = ("shift", 0.1)
        case .obstacle: (key, gap) = ("obstacle", 0.15)
        }
        if let last = lastEvent[key], now - last < gap { return }
        lastEvent[key] = now
        let performer = NSHapticFeedbackManager.defaultPerformer
        switch feel {
        case .landing(let impact): performer.perform(impact > 4 ? .levelChange : .generic, performanceTime: .now); rumble(min(1, impact / 8), 0.12)
        case .crash: performer.perform(.levelChange, performanceTime: .now); rumble(1, 0.45)
        case .finish: performer.perform(.levelChange, performanceTime: .now); rumble(0.6, 0.3)
        case .balance: performer.perform(.alignment, performanceTime: .now); rumble(0.2, 0.06)
        case .coin, .secret: performer.perform(.alignment, performanceTime: .now); rumble(0.25, 0.05)
        case .shift: performer.perform(.alignment, performanceTime: .now); rumble(0.3, 0.05)
        case .obstacle: performer.perform(.generic, performanceTime: .now); rumble(0.7, 0.15)
        }
    }
    private func rumble(_ strength: Double, _ duration: Double) {
        guard padEnabled, strength > 0 else { return }
        for engine in engines.values {
            let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(strength)),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)], relativeTime: 0, duration: duration)
            if let pattern = try? CHHapticPattern(events: [event], parameters: []), let player = try? engine.makePlayer(with: pattern) { try? player.start(atTime: 0) }
        }
    }
}
