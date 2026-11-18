import Foundation

@main
struct ContentTests {
    static func check(_ c: Bool, _ m: String) { if !c { FileHandle.standardError.write(Data("FAIL: \(m)\n".utf8)); exit(1) } }
    static func main() {
        let all = RideSecrets.all()
        check(all.count == 15 && Set(all.map(\.id)).count == 15, "15 unique secrets")
        check((0..<5).allSatisfy { RideSecrets.forRoute($0).count == 3 }, "three per route")
        check(all.allSatisfy { $0.x > 200 && $0.x < 1100 && !$0.note.isEmpty }, "secrets inside the 1.200 m route")
        let s = all[0]
        check(RideSecrets.isCollected(s, bikeX: s.x + 1, bikeHeight: 0.6, airborne: true), "caught in the air")
        check(!RideSecrets.isCollected(s, bikeX: s.x + 1, bikeHeight: 0.6, airborne: false), "not on the ground")
        check(!RideSecrets.isCollected(s, bikeX: s.x + 9, bikeHeight: 0.6, airborne: true), "not far away")
        check(!RideSecrets.isCollected(s, bikeX: s.x, bikeHeight: 0.1, airborne: true), "not a tiny hop")

        var t = RideTotals()
        check(RideJournal.unlocked(totals: t, secrets: 0).isEmpty, "new player has no pages")
        t.runs = 5; t.finishes = 1
        check(RideJournal.unlocked(totals: t, secrets: 0).count == 3, "pages unlock with progress")
        check(RideJournal.unlocked(totals: t, secrets: 15).count == 4, "all secrets unlock the last page")
        check(Set(RideJournal.entries.map(\.id)).count == RideJournal.entries.count, "unique page ids")

        check(RidePuzzle.all.count == 6 && Set(RidePuzzle.all.map(\.id)).count == 6, "six puzzles")
        check(RidePuzzle.all.allSatisfy { (0.65...1.45).contains($0.stiffness) && (0..<5).contains($0.route) && $0.reward > 0 }, "puzzle set-ups are valid")

        let p = UserDefaults(suiteName: "wr.test.\(UUID().uuidString)")!
        check(RideLeaderboard.submit(p, route: 0, RideBoardEntry(score: 0, distance: 1, time: 1, vehicle: "x", date: Date())) == nil, "zero score never ranks")
        var ranks = [Int?]()
        for score in [500, 900, 100, 700] { ranks.append(RideLeaderboard.submit(p, route: 0, RideBoardEntry(score: score, distance: 100, time: 10, vehicle: "x", date: Date()))) }
        check(ranks == [1, 1, 3, 2], "ranks \(ranks)")
        for i in 0..<20 { RideLeaderboard.submit(p, route: 1, RideBoardEntry(score: 100 + i, distance: 1, time: 1, vehicle: "x", date: Date())) }
        check(RideLeaderboard.load(p, route: 1).count == 10 && RideLeaderboard.load(p, route: 1).first?.score == 119, "top ten kept")
        check(RideLeaderboard.submit(p, route: 1, RideBoardEntry(score: 5, distance: 1, time: 1, vehicle: "x", date: Date())) == nil, "low score off the board")
        print("Content tests passed.")
    }
}
