import Foundation

/// Standings, overtakes and prize coins for races against several rivals. Pure logic, no game state.
struct RaceEntry: Equatable {
    var distance: Double
    var finishTime: Double?
    var crashed = false
}

enum RideRace {
    /// Finishers beat everybody still riding (earlier time wins); otherwise the one further along is ahead.
    static func isAhead(_ a: RaceEntry, of b: RaceEntry) -> Bool {
        switch (a.finishTime, b.finishTime) {
        case let (x?, y?): return x < y
        case (_?, nil): return true
        case (nil, _?): return false
        case (nil, nil): return a.distance > b.distance
        }
    }
    /// 1 = leading. A rival that has crashed keeps its distance and simply stops.
    static func position(player: RaceEntry, rivals: [RaceEntry]) -> Int {
        1 + rivals.filter { isAhead($0, of: player) }.count
    }
    /// Prize coins by finishing place: a duel pays 25 for the win; a field of three or more pays 40 / 20 / 8.
    static func prize(position: Int, fieldSize: Int) -> Int {
        guard fieldSize >= 2, position >= 1 else { return 0 }
        if fieldSize == 2 { return position == 1 ? 25 : 0 }
        switch position { case 1: return 40; case 2: return 20; case 3: return 8; default: return 0 }
    }

    /// Detects passes with a little hysteresis so wobbling side by side does not spam events.
    struct OvertakeTracker {
        struct Event: Equatable { let rival: Int; let playerPassed: Bool }
        private var ahead: [Bool?] = []
        static let margin = 2.0
        mutating func reset() { ahead = [] }
        mutating func update(player: Double, rivals: [RaceEntry]) -> [Event] {
            if ahead.count != rivals.count { ahead = Array(repeating: nil, count: rivals.count) }
            var events: [Event] = []
            guard player.isFinite else { return events }
            for (i, rival) in rivals.enumerated() where rival.distance.isFinite && !rival.crashed {
                let gap = player - rival.distance
                if abs(gap) < Self.margin { continue }
                let nowAhead = gap > 0
                if let before = ahead[i], before != nowAhead { events.append(Event(rival: i, playerPassed: nowAhead)) }
                ahead[i] = nowAhead
            }
            return events
        }
    }
}
