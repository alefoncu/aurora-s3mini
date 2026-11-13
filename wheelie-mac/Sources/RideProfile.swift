import Foundation

/// Developer aid for `--bench`: accumulates wall time per named section of a frame.
/// Disabled by default, so the game pays only a boolean check per section.
enum RideProfile {
    static var enabled = false
    private(set) static var totals: [String: Double] = [:]
    static func reset() { totals.removeAll() }
    @inline(__always) static func section<T>(_ name: String, _ body: () -> T) -> T {
        guard enabled else { return body() }
        let start = ProcessInfo.processInfo.systemUptime
        let result = body()
        totals[name, default: 0] += ProcessInfo.processInfo.systemUptime - start
        return result
    }
}
