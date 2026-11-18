import Foundation

/// Keyboard layout: the defaults of the game plus the player's own remaps. Pure, so tests can pin it down.
struct RideKeyMap: Codable, Equatable {
    static let defaults: [RideAction: [UInt16]] = [
        .throttle: [13, 126], .brake: [1, 125], .leanBack: [0, 123], .leanForward: [2, 124], .jump: [49], .stunt: [17],
        .stoppie: [14], .frontBrake: [6], .rearBrake: [7], .noHands: [4], .spin: [5], .superman: [9],
    ]
    /// Keys the game itself uses (Return, Esc, P, R, Q, F, C): never remappable.
    static let reserved: Set<UInt16> = [36, 53, 35, 15, 12, 3, 8]
    private(set) var overrides: [String: [UInt16]] = [:]

    func codes(_ action: RideAction) -> [UInt16] { overrides[action.rawValue] ?? Self.defaults[action] ?? [] }
    var isCustom: Bool { !overrides.isEmpty }

    /// Give `action` exactly this key. Any other action that used it loses it. False when the key is reserved.
    @discardableResult
    mutating func assign(_ action: RideAction, key: UInt16) -> Bool {
        guard !Self.reserved.contains(key) else { return false }
        for other in RideAction.allCases where other != action {
            let current = codes(other)
            if current.contains(key) { overrides[other.rawValue] = current.filter { $0 != key } }
        }
        overrides[action.rawValue] = [key]
        return true
    }
    mutating func reset() { overrides = [:] }

    static func load(_ prefs: UserDefaults) -> RideKeyMap {
        guard let data = prefs.data(forKey: "keymap"), let map = try? JSONDecoder().decode(RideKeyMap.self, from: data) else { return RideKeyMap() }
        return map
    }
    func save(_ prefs: UserDefaults) {
        if overrides.isEmpty { prefs.removeObject(forKey: "keymap") } else if let data = try? JSONEncoder().encode(self) { prefs.set(data, forKey: "keymap") }
    }

    static func name(for code: UInt16) -> String {
        let names: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            31: "O", 32: "U", 34: "I", 35: "P", 37: "L", 38: "J", 40: "K", 41: "Ñ", 43: ",", 44: "-", 45: "N", 46: "M", 47: ".",
            49: "Espacio", 48: "Tab", 51: "Borrar", 56: "⇧", 123: "←", 124: "→", 125: "↓", 126: "↑",
        ]
        return names[code] ?? "tecla \(code)"
    }
    func label(_ action: RideAction) -> String { codes(action).map(Self.name(for:)).joined(separator: " / ") }
}

/// What a game controller reports, reduced to the values the game reads. Pure.
struct RidePadState: Equatable {
    var leftX = 0.0, leftY = 0.0, leftTrigger = 0.0, rightTrigger = 0.0
    var a = false, b = false, x = false, y = false, leftShoulder = false, rightShoulder = false
    var dpadUp = false, dpadDown = false, dpadLeft = false, dpadRight = false
}

enum RidePadMap {
    static let deadzone = 0.30, trigger = 0.12
    /// Throttle on the right trigger or A, brakes on the left trigger or B, weight on the left stick or D-pad,
    /// X jump, Y trick, LB stoppie, RB hands-off, D-pad up superman, D-pad down 360.
    static func actions(_ s: RidePadState) -> Set<RideAction> {
        var set = Set<RideAction>()
        if s.rightTrigger > trigger || s.a { set.insert(.throttle) }
        if s.leftTrigger > trigger { set.insert(.frontBrake) }
        if s.b { set.insert(.rearBrake) }
        if s.leftTrigger > trigger || s.b { set.insert(.brake) }
        if s.leftX < -deadzone || s.dpadLeft { set.insert(.leanBack) }
        if s.leftX > deadzone || s.dpadRight { set.insert(.leanForward) }
        if s.x { set.insert(.jump) }
        if s.y { set.insert(.stunt) }
        if s.leftShoulder { set.insert(.stoppie) }
        if s.rightShoulder { set.insert(.noHands) }
        if s.dpadUp { set.insert(.superman) }
        if s.dpadDown { set.insert(.spin) }
        return set
    }
}
