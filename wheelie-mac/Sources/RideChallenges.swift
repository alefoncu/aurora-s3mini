import Foundation

/// Goals use physical contact measurements from the current run, never key presses.
enum RideChallengeKind: String, CaseIterable {
    case free, wheelie, stoppie, jump, timeTrial
    var title: String {
        switch self {
        case .free: return "Rodar libre"
        case .wheelie: return "Caballito · 15 m"
        case .stoppie: return "Invertido · 3 m"
        case .jump: return "Salto y aterrizaje"
        case .timeTrial: return "Contrarreloj · 4 min"
        }
    }
    var detail: String {
        switch self {
        case .free: return "Recorre la ruta y compite con tu mejor fantasma."
        case .wheelie: return "Mantén un caballito continuo durante 15 metros."
        case .stoppie: return "Recorre 3 metros seguidos sobre la rueda delantera."
        case .jump: return "Supera 0,25 m de altura y aterriza sin caer."
        case .timeTrial: return "Completa los 1.200 metros en 4 minutos o menos."
        }
    }
}

/// Compact world-space recording: the renderer can use the same real axle
/// positions as the live motorcycle instead of deriving cosmetic suspension.
struct RideGhostFrame: Codable, Equatable {
    let time: Double
    let x: Double
    let y: Double
    let pitch: Double
    let rearWheelX: Double
    let rearWheelY: Double
    let frontWheelX: Double
    let frontWheelY: Double
    let wheelRotation: Double
    let speed: Double

    fileprivate var valid: Bool {
        let values = [time, x, y, pitch, rearWheelX, rearWheelY, frontWheelX, frontWheelY, wheelRotation, speed]
        return values.allSatisfy { $0.isFinite } && time >= 0 && time <= 36_000
            && abs(x) <= 10_000 && abs(y) <= 1_000 && abs(pitch) <= 100
            && abs(rearWheelX) <= 10_000 && abs(frontWheelX) <= 10_000
            && abs(rearWheelY) <= 1_000 && abs(frontWheelY) <= 1_000
            && abs(wheelRotation) <= 1_000_000 && speed >= 0 && speed <= 200
    }
    fileprivate func interpolated(to other: Self, fraction: Double, time: Double) -> Self {
        func mix(_ a: Double, _ b: Double) -> Double { a + (b - a) * fraction }
        return Self(time: time, x: mix(x, other.x), y: mix(y, other.y), pitch: mix(pitch, other.pitch),
            rearWheelX: mix(rearWheelX, other.rearWheelX), rearWheelY: mix(rearWheelY, other.rearWheelY),
            frontWheelX: mix(frontWheelX, other.frontWheelX), frontWheelY: mix(frontWheelY, other.frontWheelY),
            wheelRotation: mix(wheelRotation, other.wheelRotation), speed: mix(speed, other.speed))
    }
}

struct RideGhostRun: Codable {
    static let maximumDuration = 600.0
    static let maximumFrames = 6_002
    static let maximumDataBytes = 2_500_000
    let version: Int
    let contextKey: String
    let duration: Double
    let frames: [RideGhostFrame]

    fileprivate var valid: Bool {
        guard version == 1, !contextKey.isEmpty, contextKey.count <= 512,
              duration.isFinite, duration > 0, duration <= Self.maximumDuration,
              frames.count >= 2, frames.count <= Self.maximumFrames,
              let first = frames.first, let last = frames.last,
              first.time == 0, abs(last.time - duration) < 0.001,
              frames.allSatisfy(\.valid) else { return false }
        return zip(frames, frames.dropFirst()).allSatisfy { $0.time < $1.time }
    }

    func frame(at time: Double) -> RideGhostFrame? {
        guard time.isFinite, time >= 0, time <= duration, !frames.isEmpty else { return nil }
        if time == duration { return frames.last }
        var lower = 0, upper = frames.count - 1
        while upper - lower > 1 {
            let middle = (lower + upper) / 2
            if frames[middle].time <= time { lower = middle } else { upper = middle }
        }
        let a = frames[lower], b = frames[upper]
        return a.interpolated(to: b, fraction: (time - a.time) / (b.time - a.time), time: time)
    }
}

/// One run at a time. The caller supplies a versioned context including vehicle,
/// route, obstacles and handling settings, so incompatible ghosts never compete.
final class RideChallengeSession {
    private let preferences: UserDefaults
    var selected: RideChallengeKind = .free
    private(set) var progress = 0.0
    private(set) var completed = false
    private(set) var previouslyCompleted = false
    private(set) var ghost: RideGhostRun?
    private(set) var savedNewGhost = false
    private var active = false
    private var contextKey = ""
    private var runChallenge: RideChallengeKind = .free
    private var frames: [RideGhostFrame] = []
    private var lastFrame: RideGhostFrame?
    private var lastSampleTime = 0.0
    private var hasJumped = false
    private var jumpPeak = 0.0
    private var wasAirborne = false
    private var recordingValid = true
    private var observedTime = 0.0
    private var observedDistance = 0.0
    private var ghostStorageKey: String { "v6.ghost." + contextKey }
    private var challengeStorageKey: String { "v6.challenge." + contextKey + "." + runChallenge.rawValue }

    init(preferences: UserDefaults = .standard) { self.preferences = preferences }

    var progressText: String {
        if completed { return "Reto conseguido" }
        switch runChallenge {
        case .free: return ghost == nil ? "Completa la ruta para guardar tu fantasma" : "Compite con tu mejor vuelta"
        case .wheelie: return String(format: "Caballito %.1f / 15 m", progress * 15)
        case .stoppie: return String(format: "Invertido %.1f / 3 m", progress * 3)
        case .jump: return hasJumped ? "Salto: aterriza sin caer" : "Salto: supera 0,25 m"
        case .timeTrial: return String(format: "Contrarreloj %.0f / 240 s · %.0f m", observedTime, observedDistance)
        }
    }

    func start(contextKey: String, initialFrame: RideGhostFrame) {
        abandon()
        self.contextKey = String(contextKey.prefix(512))
        runChallenge = selected
        active = !contextKey.isEmpty && contextKey.count <= 512
        previouslyCompleted = active && preferences.bool(forKey: challengeStorageKey)
        loadGhost()
        guard initialFrame.valid, initialFrame.time == 0 else { recordingValid = false; return }
        frames = [initialFrame]
        lastFrame = initialFrame
    }

    /// Read saved goal and ghost while in the workshop, without starting a run.
    func load(contextKey: String) {
        abandon()
        self.contextKey = String(contextKey.prefix(512))
        runChallenge = selected
        previouslyCompleted = preferences.bool(forKey: challengeStorageKey)
        loadGhost()
    }

    func update(frame: RideGhostFrame, distance: Double, wheelie: Double, stoppie: Double,
                airborne: Bool, height: Double, crashed: Bool) {
        guard active, frame.valid, distance.isFinite, wheelie.isFinite, stoppie.isFinite,
              height.isFinite else { return }
        if let previous = lastFrame, frame.time <= previous.time { return }
        observedTime = frame.time
        observedDistance = max(0, distance)
        lastFrame = frame
        if frame.time <= RideGhostRun.maximumDuration && frame.time - lastSampleTime >= 0.1 - 1e-7 {
            if frames.count < RideGhostRun.maximumFrames { frames.append(frame); lastSampleTime = frame.time }
            else { recordingValid = false }
        }
        if frame.time > RideGhostRun.maximumDuration { recordingValid = false }
        if !crashed {
            if airborne { jumpPeak = max(jumpPeak, height); if jumpPeak >= 0.25 { hasJumped = true } }
            switch runChallenge {
            case .free: break
            case .wheelie: progress = max(progress, max(0, min(1, wheelie / 15))); completed = progress >= 1
            case .stoppie: progress = max(progress, max(0, min(1, stoppie / 3))); completed = progress >= 1
            case .jump:
                progress = max(progress, min(0.9, max(0, jumpPeak / 0.25) * 0.9))
                if wasAirborne && !airborne && hasJumped { progress = 1; completed = true }
            case .timeTrial: progress = max(0, min(1, distance / 1_200))
            }
        } else if !completed { hasJumped = false; jumpPeak = 0 }
        wasAirborne = airborne
    }

    /// Call once at a natural result (crash or finish). Restart/back-to-workshop
    /// uses abandon(), so discarding a run cannot award a challenge or a ghost.
    func finish(routeCompleted: Bool, elapsed: Double) {
        guard active, elapsed.isFinite, elapsed > 0, abs(elapsed - observedTime) < 0.001 else { return }
        active = false
        if runChallenge == .timeTrial {
            completed = routeCompleted && elapsed.isFinite && elapsed > 0 && elapsed <= 240
            if completed { progress = 1 }
        }
        if completed && runChallenge != .free {
            preferences.set(true, forKey: challengeStorageKey)
            previouslyCompleted = true
        }
        guard routeCompleted, recordingValid, elapsed.isFinite, elapsed > 0,
              elapsed <= RideGhostRun.maximumDuration,
              let last = lastFrame, abs(last.time - elapsed) < 0.001,
              ghost == nil || elapsed < ghost!.duration else { return }
        if frames.last?.time != last.time {
            guard frames.count < RideGhostRun.maximumFrames else { return }
            frames.append(last)
        }
        let run = RideGhostRun(version: 1, contextKey: contextKey, duration: elapsed, frames: frames)
        guard run.valid, let data = try? JSONEncoder().encode(run), data.count <= RideGhostRun.maximumDataBytes else { return }
        preferences.set(data, forKey: ghostStorageKey)
        ghost = run
        savedNewGhost = true
    }

    func abandon() {
        active = false; frames.removeAll(keepingCapacity: true); lastFrame = nil
        progress = 0; completed = false; previouslyCompleted = false; savedNewGhost = false
        hasJumped = false; jumpPeak = 0; wasAirborne = false
        lastSampleTime = 0; recordingValid = true; observedTime = 0; observedDistance = 0
    }

    func ghostFrame(at time: Double) -> RideGhostFrame? { ghost?.frame(at: time) }

    private func loadGhost() {
        ghost = nil
        guard let data = preferences.data(forKey: ghostStorageKey), data.count <= RideGhostRun.maximumDataBytes,
              let decoded = try? JSONDecoder().decode(RideGhostRun.self, from: data), decoded.valid,
              decoded.contextKey == contextKey else { return }
        ghost = decoded
    }
}
