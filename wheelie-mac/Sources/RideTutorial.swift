import Foundation

/// A guided first ride: accelerate, lift the front, correct, brake, jump and flip.
/// Pure state machine; the game feeds it one observation per frame.
struct TutorialObservation {
    var speed = 0.0, wheelieDistance = 0.0
    var rearContact = true, frontContact = true
    var brakeHeld = false, crashed = false
    var landingSerial = 0, lastAirTime = 0.0, lastFlips = 0
    var dt = 1.0 / 60
}

struct RideTutorial {
    enum Step: Int, CaseIterable { case accelerate, wheelie, correct, brake, jump, flip, done }
    private(set) var step = Step.accelerate
    private(set) var progress = 0.0
    private var settled = 0.0, armed = false
    private var serial: Int?
    var finished: Bool { step == .done }
    var stepNumber: Int { min(step.rawValue + 1, Step.allCases.count - 1) }
    static var stepCount: Int { Step.allCases.count - 1 }

    var title: String {
        switch step {
        case .accelerate: return "Acelera"
        case .wheelie: return "Levanta la rueda"
        case .correct: return "Corrige el caballito"
        case .brake: return "Frena"
        case .jump: return "Salta"
        case .flip: return "Voltereta"
        case .done: return "Tutorial completado"
        }
    }
    var instruction: String {
        switch step {
        case .accelerate: return "Mantén ↑ (o W) hasta superar 20 km/h."
        case .wheelie: return "Acelera y mantén ← (o A) para levantar la rueda delantera: 4 m de caballito."
        case .correct: return "Suelta ← y pulsa → (o D) para apoyar la rueda delantera. Mantén ambas ruedas en el suelo."
        case .brake: return "Llega a 20 km/h y frena con ↓ (o S) hasta casi parar."
        case .jump: return "Pulsa Espacio para saltar y aterriza sin caer."
        case .flip: return "Mantén T al saltar y ← o → en el aire. Suelta T pasada la media vuelta y aterriza."
        case .done: return "Ya dominas los controles. Prueba combos, rutas nuevas y carreras."
        }
    }

    /// Returns true when the observation completed a step.
    @discardableResult mutating func update(_ o: TutorialObservation) -> Bool {
        guard !finished, !o.crashed else { return false }
        let previousSerial = serial ?? o.landingSerial
        serial = o.landingSerial
        let landed = o.landingSerial != previousSerial
        switch step {
        case .accelerate:
            progress = min(1, o.speed / 5.6)
            if o.speed >= 5.6 { return advance() }
        case .wheelie:
            progress = min(1, o.wheelieDistance / 4)
            if o.wheelieDistance >= 4 { return advance() }
        case .correct:
            // Both wheels down for a second while moving.
            if o.rearContact && o.frontContact && o.speed > 2 { settled += o.dt } else { settled = 0 }
            progress = min(1, settled / 1.0)
            if settled >= 1 { return advance() }
        case .brake:
            if o.speed >= 5.6 { armed = true }
            progress = armed ? min(1, max(0, (5.6 - o.speed) / 4.2)) : min(1, o.speed / 5.6) * 0.3
            if armed && o.brakeHeld && o.speed <= 1.4 { return advance() }
        case .jump:
            progress = 0
            if landed && o.lastAirTime >= 0.3 { progress = 1; return advance() }
        case .flip:
            progress = 0
            if landed && o.lastFlips >= 1 { progress = 1; return advance() }
        case .done: break
        }
        return false
    }
    private mutating func advance() -> Bool {
        step = Step(rawValue: step.rawValue + 1) ?? .done
        progress = 0; settled = 0; armed = false
        return true
    }
}
