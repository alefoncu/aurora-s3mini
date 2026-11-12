import Foundation

/// Offline test harness. EngineRenderState deliberately stays private in the
/// production file. Compile a temporary copy of that actual file together with
/// the assertions below so its private renderer can be exercised directly,
/// without constructing AVAudioEngine, opening an output device or a window.
///
/// From wheelie-mac:
///   xcrun swiftc -parse-as-library Tests/AudioTests.swift -o build/AudioTests
///   ./build/AudioTests
/// Optionally supply a path to Sources/EngineAudio.swift as the first argument.
@main
struct AudioTests {
    static func main() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let source = CommandLine.arguments.count > 1
            ? URL(fileURLWithPath: CommandLine.arguments[1])
            : root.appendingPathComponent("Sources/EngineAudio.swift")
        let original = try String(contentsOf: source, encoding: .utf8)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("wheelie-audio-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let combined = directory.appendingPathComponent("AudioRenderCheck.swift")
        let executable = directory.appendingPathComponent("AudioRenderCheck")
        try (original + assertions).write(to: combined, atomically: true, encoding: .utf8)
        #if arch(arm64)
        let target = "arm64-apple-macos13.0"
        #else
        let target = "x86_64-apple-macos13.0"
        #endif
        try run("/usr/bin/xcrun", ["swiftc", "-parse-as-library", "-target", target,
                                   "-framework", "AVFoundation", combined.path, "-o", executable.path])
        try run(executable.path, [])
    }

    private static func run(_ path: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "AudioTests", code: Int(process.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "Audio check subprocess failed: \(path)"])
        }
    }

    private static let assertions = #"""

@main struct AudioRenderCheck {
    static func main() {
        let render = EngineRenderState()
        let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48_000)!
        buffer.frameLength = 48_000
        let channels = buffer.floatChannelData!

        // Engine at 15 m/s under load: it must produce bounded, finite sound,
        // and write both output channels rather than leaving an uninitialised one.
        render.store(Int64(15 * 256 | (1 << 16) | (1 << 18) | (1 << 19)))
        render.render(frameCount: 48_000, buffers: buffer.mutableAudioBufferList)
        var peak: Float = 0
        for i in 0..<48_000 {
            precondition(channels[0][i].isFinite, "Engine produced a non-finite sample")
            precondition(channels[0][i] == channels[1][i], "Stereo channels differ")
            peak = max(peak, abs(channels[0][i]))
        }
        precondition(peak > 0.01 && peak < 0.2, "Engine output is silent or too loud: \(peak)")

        // A mute must settle to silence, including after the motor was audible.
        render.store(0)
        render.render(frameCount: 48_000, buffers: buffer.mutableAudioBufferList)
        for i in 47_000..<48_000 {
            precondition(abs(channels[0][i]) < 0.000001, "Mute leaked engine sound")
        }

        // A crash can sound after riding has ended, then decay without sustained noise.
        render.store(Int64((1 << 19) | (1 << 32)))
        render.render(frameCount: 48_000, buffers: buffer.mutableAudioBufferList)
        var impactPeak: Float = 0
        for i in 0..<4_800 {
            precondition(channels[0][i].isFinite)
            impactPeak = max(impactPeak, abs(channels[0][i]))
        }
        precondition(impactPeak > 0.005 && impactPeak < 0.6, "Impact output is silent or too loud")
        for i in 47_000..<48_000 {
            precondition(abs(channels[0][i]) < 0.000001, "Impact did not decay")
        }

        // A stationary bicycle must not idle like a combustion engine.
        render.store(Int64((3 << 20) | (1 << 18) | (1 << 19)))
        render.render(frameCount: 48_000, buffers: buffer.mutableAudioBufferList)
        for i in 47_000..<48_000 {
            precondition(abs(channels[0][i]) < 0.000001, "Stationary BMX has engine sound")
        }

        // A moving bicycle should have quiet wheel noise, and muting must stop it too.
        render.store(Int64(10 * 256 | (3 << 20) | (1 << 18) | (1 << 19)))
        render.render(frameCount: 48_000, buffers: buffer.mutableAudioBufferList)
        var wheelPeak: Float = 0
        for i in 0..<48_000 {
            precondition(channels[0][i].isFinite && channels[0][i] == channels[1][i])
            wheelPeak = max(wheelPeak, abs(channels[0][i]))
        }
        precondition(wheelPeak > 0.001 && wheelPeak < 0.04, "Bicycle wheel noise is missing or too loud")
        render.store(Int64(10 * 256 | (3 << 20) | (1 << 18)))
        render.render(frameCount: 48_000, buffers: buffer.mutableAudioBufferList)
        for i in 47_000..<48_000 {
            precondition(abs(channels[0][i]) < 0.000001, "Mute leaked bicycle wheel noise")
        }
        // Exercise the actual packed RPM/load/shift protocol without an audio
        // device. Settled windows distinguish firing rate from loudness.
        func voiceStats(rpm: Int, voice: Int, load: Int, shifting: Bool = false) -> (Double,Int) {
            let state=EngineRenderState()
            let profile=voice == 3 ? 3 : voice == 1 || voice == 6 ? 1 : voice == 2 || voice == 7 ? 2 : 0
            var word=UInt64((1 << 18) | (1 << 19)) | (UInt64(profile) << 20)
            word |= UInt64(rpm/16) << 22
            word |= UInt64(load) << 48
            word |= UInt64(voice) << 61
            if shifting {word |= 1 << 56}
            state.store(Int64(bitPattern:word))
            state.render(frameCount:48_000,buffers:buffer.mutableAudioBufferList)
            var squares=0.0, crossings=0
            for i in 24_001..<48_000 {
                let value=channels[0][i]
                precondition(value.isFinite && abs(value)<0.2)
                precondition(value==channels[1][i])
                squares += Double(value*value)
                if value>0 && channels[0][i-1]<=0 {crossings+=1}
            }
            return (sqrt(squares/23_999),crossings)
        }
        let idle=voiceStats(rpm:1_280,voice:0,load:0)
        let revved=voiceStats(rpm:6_400,voice:0,load:0)
        precondition(revved.1>idle.1*3,"Engine firing rate must follow RPM at unchanged road speed")
        let loaded=voiceStats(rpm:6_400,voice:0,load:255)
        let shifted=voiceStats(rpm:6_400,voice:0,load:255,shifting:true)
        precondition(loaded.0>revved.0*1.8 && shifted.0<loaded.0*0.4,"Load and clutch cut must change combustion intensity")
        for voice in 0...7 {
            let stats=voiceStats(rpm:6_400,voice:voice,load:255)
            precondition(voice == 3 ? stats.0==0 : stats.0>0.005,"Each motor voice must sound; BMX must remain silent")
        }
        // Ambient beds: rain is hissy, wind is a low rumble, the city hums; all bounded, and
        // none of them can leak when sound is muted or no ride is active.
        func ambientStats(flags: Int64, level: Int64 = 255, main: UInt64 = UInt64((3 << 20) | (1 << 18) | (1 << 19))) -> (peak: Float, crossings: Int) {   // stationary BMX: no engine, only ambience
            let state = EngineRenderState()
            state.store(Int64(bitPattern: main)); state.storeAmbient(flags | (level << 8))
            state.render(frameCount: 48_000, buffers: buffer.mutableAudioBufferList)
            state.render(frameCount: 48_000, buffers: buffer.mutableAudioBufferList)
            var peak: Float = 0, crossings = 0
            for i in 1..<48_000 {
                precondition(channels[0][i].isFinite && channels[0][i] == channels[1][i], "Ambient produced a bad sample")
                peak = max(peak, abs(channels[0][i]))
                if (channels[0][i] > 0) != (channels[0][i - 1] > 0) { crossings += 1 }
            }
            return (peak, crossings)
        }
        let rain = ambientStats(flags: 1), wind = ambientStats(flags: 2), city = ambientStats(flags: 4), all = ambientStats(flags: 7)
        for sound in [rain, wind, city, all] { precondition(sound.peak > 0.002 && sound.peak < 0.25, "Ambient is silent or too loud: \(sound.peak)") }
        precondition(rain.crossings > wind.crossings * 3, "Rain must be brighter than wind (\(rain.crossings) vs \(wind.crossings))")
        let calm = ambientStats(flags: 2, level: 0), gale = ambientStats(flags: 2, level: 255)
        precondition(gale.peak > calm.peak * 1.3, "Wind must grow with speed")
        precondition(ambientStats(flags: 7, main: UInt64((3 << 20) | (1 << 18))).peak < 0.000001, "Muted ambient leaked")
        precondition(ambientStats(flags: 7, main: UInt64((3 << 20) | (1 << 19))).peak < 0.000001, "Ambient played without an active ride")
        precondition(ambientStats(flags: 0).peak < 0.000001, "No ambient flag, no ambient sound")
        print("AudioTests passed: finite bounded stereo motor, mute, impact decay, BMX idle/rolling, eight voices, RPM firing rate, load and clutch cut, rain/wind/city ambience. No audio device opened.")
    }
}
"""#
}
