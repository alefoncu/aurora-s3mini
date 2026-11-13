import AVFoundation
import Foundation
import Darwin

/// Small, entirely local sound engine. Call its public methods from the UI thread.
/// No input device is opened and no microphone entitlement is needed.
final class EngineAudio {
    var enabled = true {
        didSet { publish() }
    }

    private let engine = AVAudioEngine()
    private let state = EngineRenderState()
    private var source: AVAudioSourceNode?
    private var speed = 0.0
    private var throttle = false
    private var vehicle = 0
    private var active = false
    private var rpm = 0.0, load = 0.0, slip = 0.0
    private var shifting = false
    private var timbre = 0
    private var impactSerial: UInt64 = 0
    private var hasGraph = false
    private var lastStartAttempt = -Double.infinity

    init() {}

    /// Vehicle order: commuter, motocross, sport, bicycle.
    func update(speed: Double, throttle: Bool, vehicle: Int, active: Bool,
                rpm: Double = 0, load: Double = 0, shifting: Bool = false,
                slip: Double = 0, timbre: Int? = nil) {
        self.speed = speed.isFinite ? max(0, min(120, speed)) : 0
        self.throttle = throttle
        self.vehicle = max(0, min(3, vehicle))
        self.active = active
        self.rpm = rpm.isFinite ? max(0,min(16_368,rpm)) : 0
        self.load = load.isFinite ? max(0,min(1,load)) : 0
        self.slip = slip.isFinite ? max(0,min(1,slip)) : 0
        self.shifting = shifting
        self.timbre = max(0,min(7,timbre ?? self.vehicle))
        publish()
        if enabled && active { startIfNeeded() }
    }

    /// Ambient bed for the current route: rain, wind (grows with speed) and a distant city hum.
    /// `windLevel` is 0...1. Nothing plays unless sound is enabled and a ride is active.
    func setAmbient(route: Int, speed: Double) {
        var flags: Int64 = 0
        switch route { case 2: flags = 2; case 3: flags = 2; case 4: flags = 1 | 4; default: flags = 0 }
        let level = Int64(max(0, min(255, ((speed.isFinite ? max(0, speed) : 0) / 40 * 255).rounded())))
        state.storeAmbient(flags | (level << 8) | (route == 3 ? 1 << 16 : 0))
    }
    /// Short synthesised effects for the interface and tricks. They play whenever sound is enabled,
    /// in the garage as well as while riding. `intensity` (0...1) shifts pitch or loudness.
    enum SFX: Int { case chime = 1, coin, flip, landing, whoosh, combo, denied }
    private var sfxSerial: UInt64 = 0
    func play(_ effect: SFX, intensity: Double = 0) {
        guard enabled else { return }
        sfxSerial = (sfxSerial &+ 1) & 0xFFFF
        let level = UInt64(max(0, min(255, (intensity.isFinite ? intensity : 0) * 255)).rounded())
        state.storeSFX(Int64(bitPattern: UInt64(effect.rawValue) | (sfxSerial << 8) | (level << 24)))
        startIfNeeded()
    }
    func impact() {
        guard enabled else { return }
        impactSerial = (impactSerial &+ 1) & 0xFFFF
        publish()
        startIfNeeded()
    }

    func stop() {
        active = false
        publish()
        engine.stop()
        lastStartAttempt = -Double.infinity
    }

    private func publish() {
        let quantizedSpeed = UInt64((max(0, min(120, speed)) * 256).rounded())
        var word = quantizedSpeed | (UInt64(vehicle) << 20) | (impactSerial << 32)
        if throttle { word |= 1 << 16 }
        if active { word |= 1 << 18 }
        if enabled { word |= 1 << 19 }
        word |= UInt64((rpm/16).rounded()) << 22
        word |= UInt64((load*255).rounded()) << 48
        if shifting { word |= 1 << 56 }
        word |= UInt64((slip*15).rounded()) << 57
        word |= UInt64(timbre) << 61
        state.store(Int64(bitPattern:word))
    }

    private func startIfNeeded() {
        guard !engine.isRunning else { return }
        // Retry if macOS has changed the output device, without retrying at frame rate.
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastStartAttempt > 2 else { return }
        lastStartAttempt = now
        if !hasGraph {
            let renderState = state
            let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
            let node = AVAudioSourceNode(format: format) { _, _, frameCount, buffers -> OSStatus in
                renderState.render(frameCount: frameCount, buffers: buffers)
                return noErr
            }
            source = node
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            engine.mainMixerNode.outputVolume = 0.7
            hasGraph = true
        }
        do {
            engine.prepare()
            try engine.start()
        } catch {
            // An unavailable audio output must never prevent riding. A later active
            // update will retry (for example after connecting headphones).
            engine.stop()
        }
    }

    deinit { engine.stop() }
}

/// The render callback owns all synthesis variables. The UI exchanges one packed
/// 64-bit control word with it atomically, rather than sharing mutable Doubles.
/// OSAtomic is intentionally used for the macOS 13 deployment target: these
/// lock-free 64-bit primitives are available without an external Atomics package.
/// The callback performs one atomic read per buffer; it takes no locks, allocates
/// nothing, logs nothing, and never calls back into AppKit or AVAudioEngine.
private final class EngineRenderState {
    private let controls: UnsafeMutablePointer<Int64>
    private let ambientControls: UnsafeMutablePointer<Int64>
    private let sfxControls: UnsafeMutablePointer<Int64>
    private var voiceKind = [Int](repeating: 0, count: 6), voiceAge = [Double](repeating: 0, count: 6), voiceLevel = [Double](repeating: 0, count: 6)
    private var previousSFX: UInt64 = 0
    private var sfxNoiseLow = 0.0
    private var rainGain = 0.0, windGain = 0.0, cityGain = 0.0
    private var windLow = 0.0, hiLow = 0.0, cityLow = 0.0, gustPhase = 0.0, cityPhase = 0.0
    private var phase = 0.0
    private var frequency = 38.0
    private var gain = 0.0
    private var roadGain = 0.0
    private var slipGain = 0.0, slipPhase = 0.0
    private var noiseLow = 0.0
    private var rng: UInt32 = 0x7A91B32D
    private var impactEnvelope = 0.0
    private var previousImpact: UInt64 = 0

    init() {
        controls = .allocate(capacity: 1)
        controls.initialize(to: 0)
        ambientControls = .allocate(capacity: 1)
        ambientControls.initialize(to: 0)
        sfxControls = .allocate(capacity: 1)
        sfxControls.initialize(to: 0)
    }

    func storeSFX(_ value: Int64) {
        var old = OSAtomicAdd64Barrier(0, sfxControls)
        while !OSAtomicCompareAndSwap64Barrier(old, value, sfxControls) { old = OSAtomicAdd64Barrier(0, sfxControls) }
    }

    func storeAmbient(_ value: Int64) {
        var old = OSAtomicAdd64Barrier(0, ambientControls)
        while !OSAtomicCompareAndSwap64Barrier(old, value, ambientControls) { old = OSAtomicAdd64Barrier(0, ambientControls) }
    }

    func store(_ value: Int64) {
        var old = OSAtomicAdd64Barrier(0, controls)
        while !OSAtomicCompareAndSwap64Barrier(old, value, controls) {
            old = OSAtomicAdd64Barrier(0, controls)
        }
    }

    /// One sample of an effect at `t` seconds. Every effect is a few decaying partials plus a touch of noise.
    static func effectSample(kind: Int, t: Double, level: Double, noise: Double, low: Double) -> Double {
        let tau = Double.pi * 2
        func ping(_ f: Double, _ start: Double, decay: Double, gain: Double) -> Double {
            guard t >= start else { return 0 }
            let d = t - start
            return (sin(tau * f * d) + 0.3 * sin(tau * 2 * f * d)) * exp(-d * decay) * min(1, d * 500) * gain
        }
        switch kind {
        case 1:  // chime: rising arpeggio
            return ping(1046.5, 0, decay: 9, gain: 0.16) + ping(1318.5, 0.09, decay: 9, gain: 0.16) + ping(1568, 0.18, decay: 9, gain: 0.16) + ping(2093, 0.27, decay: 7, gain: 0.18)
        case 2:  // coin: two quick pings
            return ping(1318.5, 0, decay: 14, gain: 0.18) + ping(1760, 0.07, decay: 8, gain: 0.2)
        case 3:  // flip landed: thump with a rising sparkle
            let thump = t < 0.4 ? sin(tau * 90 * t) * exp(-t * 18) * 0.5 + noise * exp(-t * 30) * 0.12 : 0
            let sparkle = t < 0.6 ? sin(tau * (600 * t + 1800 * t * t)) * exp(-t * 6) * 0.1 : 0
            return thump + sparkle
        case 4:  // landing: soft thud
            return t < 0.4 ? sin(tau * 68 * t) * exp(-t * 22) * 0.55 + low * exp(-t * 35) * 0.5 : 0
        case 5:  // spin: a short whoosh
            return t < 0.35 ? low * 3 * sin(Double.pi * t / 0.35) * 0.35 * (0.6 + 0.4 * sin(tau * (4 + 12 * t) * t)) : 0
        case 6:  // combo tick, higher with the multiplier
            return t < 0.12 ? sin(tau * 660 * (1 + level * 0.9) * t) * exp(-t * 40) * 0.16 * min(1, t * 800) : 0
        default: // denied: two low buzzes
            let buzz = t < 0.28 ? ((sin(tau * 150 * t) > 0 ? 1.0 : -1.0) * 0.07 + sin(tau * 110 * t) * 0.05) * (t < 0.12 || t > 0.16 ? 1 : 0) * exp(-t * 6) : 0
            return buzz
        }
    }

    func render(frameCount: AVAudioFrameCount, buffers: UnsafeMutablePointer<AudioBufferList>) {
        let word = UInt64(bitPattern: OSAtomicAdd64Barrier(0, controls))
        let speed = Double(word & 0xFFFF) / 256
        let throttle = word & (1 << 16) != 0
        let active = word & (1 << 18) != 0
        let enabled = word & (1 << 19) != 0
        let kind = Int((word >> 20) & 3)
        let serial = (word >> 32) & 0xFFFF
        if serial != previousImpact {
            previousImpact = serial
            if enabled { impactEnvelope = 0.22 }
        }
        if !enabled { impactEnvelope = 0 }

        let suppliedRPM = Double((word >> 22) & 0x3FF)*16
        let load = Double((word >> 48) & 0xFF)/255
        let shifting = word & (1 << 56) != 0
        let slip = Double((word >> 57) & 15)/15
        // Explicit RPM selects the detailed eight-vehicle voice. Legacy callers
        // retain their four audio profiles and a speed-derived RPM fallback.
        let voice = suppliedRPM > 0 ? Int((word >> 61) & 7) : kind
        let cylinderFactor: Double, idle: Double, harmonic2: Double, harmonic3: Double
        switch voice {
        case 1: cylinderFactor=0.5; idle=1_650; harmonic2=0.38; harmonic3=0.23
        case 2: cylinderFactor=2; idle=1_500; harmonic2=0.17; harmonic3=0.09
        case 4: cylinderFactor=0.5; idle=1_250; harmonic2=0.21; harmonic3=0.12
        case 5: cylinderFactor=1; idle=1_250; harmonic2=0.32; harmonic3=0.18
        case 6: cylinderFactor=0.5; idle=1_650; harmonic2=0.40; harmonic3=0.28
        case 7: cylinderFactor=2; idle=1_500; harmonic2=0.25; harmonic3=0.14
        default: cylinderFactor=0.5; idle=1_250; harmonic2=0.28; harmonic3=0.16
        }
        let engineRPM = suppliedRPM > 0 ? suppliedRPM : idle + speed*180 + (throttle ? 900:0)
        let targetFrequency = min(560,max(10,engineRPM/60*cylinderFactor))
        let engineLoad = suppliedRPM > 0 ? load : (throttle ? 1:0)
        // Closed-throttle overrun keeps combustion audible, while a gear change
        // briefly cuts firing intensity. Smoothing avoids control-rate clicks.
        let targetGain = enabled && active && kind != 3 ? (0.026+engineLoad*0.044)*(shifting ? 0.25:1) : 0
        let targetRoad = enabled && active ? min(0.022,speed*0.0007) : 0
        let targetSlip = enabled && active && speed>1 ? slip*0.025 : 0
        let ambientWord = UInt64(bitPattern: OSAtomicAdd64Barrier(0, ambientControls))
        let rainOn = ambientWord & 1 != 0, windOn = ambientWord & 2 != 0, cityOn = ambientWord & 4 != 0
        let windLevel = Double((ambientWord >> 8) & 0xFF) / 255
        let heavyWind = ambientWord & (1 << 16) != 0
        let live = enabled && active
        let targetRain = live && rainOn ? 0.040 : 0
        let targetWind = live && windOn ? (heavyWind ? 0.05 : 0.025) + windLevel * 0.05 : 0
        let targetCity = live && cityOn ? 0.016 : 0
        let sfxWord = UInt64(bitPattern: OSAtomicAdd64Barrier(0, sfxControls))
        if sfxWord != previousSFX {
            previousSFX = sfxWord
            let kind = Int(sfxWord & 0xFF)
            if enabled && kind > 0 && kind <= 7 {
                // Reuse a finished voice, otherwise steal the oldest one.
                var slot = 0, oldest = -1.0
                for i in 0..<6 { let free = voiceKind[i] == 0; if free { slot = i; oldest = .infinity; break }; if voiceAge[i] > oldest { oldest = voiceAge[i]; slot = i } }
                voiceKind[slot] = kind; voiceAge[slot] = 0; voiceLevel[slot] = Double((sfxWord >> 24) & 0xFF) / 255
            }
        }
        if !enabled { for i in 0..<6 { voiceKind[i] = 0 } }
        let list = UnsafeMutableAudioBufferListPointer(buffers)
        let tau = Double.pi * 2
        for frame in 0..<Int(frameCount) {
            frequency += (targetFrequency - frequency) * 0.00035
            gain += (targetGain - gain) * 0.0014
            roadGain += (targetRoad - roadGain) * 0.0014
            slipGain += (targetSlip-slipGain)*0.0014
            slipPhase += (650+speed*5)*tau/48_000
            if slipPhase >= tau { slipPhase -= tau }
            phase += frequency * tau / 48_000
            if phase >= tau { phase -= tau }
            rng = rng &* 1_664_525 &+ 1_013_904_223
            let noise = Double(rng >> 8) / 8_388_607.5 - 1
            noiseLow += (noise - noiseLow) * 0.055
            let fundamental=sin(phase)
            let combustion=fundamental*0.64+sin(phase*2)*harmonic2+sin(phase*3)*harmonic3
            let motor=combustion/(0.64+harmonic2+harmonic3)
                + noiseLow*engineLoad*(voice == 1 || voice == 6 ? 0.30:0.10)
            let impact = impactEnvelope * (noiseLow * 1.8 + sin(phase * 0.53) * 0.35)
            impactEnvelope *= 0.9993
            rainGain += (targetRain-rainGain)*0.0004; windGain += (targetWind-windGain)*0.0004; cityGain += (targetCity-cityGain)*0.0004
            hiLow += (noise-hiLow)*0.35; windLow += (noise-windLow)*0.0035; cityLow += (noise-cityLow)*0.012
            gustPhase += 0.12*tau/48_000; if gustPhase >= tau { gustPhase -= tau }
            cityPhase += 55*tau/48_000; if cityPhase >= tau { cityPhase -= tau }
            let rain=(noise-hiLow)*rainGain*(0.85+0.15*sin(gustPhase*3))
            let wind=windLow*5.5*windGain*(0.65+0.35*sin(gustPhase))
            let city=(sin(cityPhase)*0.55+sin(cityPhase*2.01)*0.25+cityLow*6)*cityGain
            var effects = 0.0
            for v in 0..<6 where voiceKind[v] != 0 {
                let t = voiceAge[v]; voiceAge[v] += 1 / 48_000
                effects += Self.effectSample(kind: voiceKind[v], t: t, level: voiceLevel[v], noise: noise, low: noiseLow)
                if t > 1.6 { voiceKind[v] = 0 }
            }
            let ambient=rain+wind+city+effects
            let sample = Float(motor*gain+(noise-noiseLow)*roadGain+sin(slipPhase)*slipGain+impact+ambient)
            for buffer in list {
                guard let data = buffer.mData else { continue }
                let samples = data.assumingMemoryBound(to: Float.self)
                // The connected format is non-interleaved Float32. Supporting an
                // interleaved buffer here too costs nothing and avoids assumptions.
                let channels = Int(buffer.mNumberChannels)
                for channel in 0..<channels { samples[frame * channels + channel] = sample }
            }
        }
    }

    deinit {
        controls.deinitialize(count: 1)
        controls.deallocate()
        ambientControls.deinitialize(count: 1)
        ambientControls.deallocate()
        sfxControls.deinitialize(count: 1)
        sfxControls.deallocate()
    }
}
