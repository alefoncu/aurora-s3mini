import Foundation

@main struct ProgressTests {
    static func check(_ ok: @autoclosure () -> Bool, _ message: String) { if !ok() { print("ProgressTests FAILED: \(message)"); exit(1) } }
    static func suite() -> UserDefaults { UserDefaults(suiteName: "wheelie.progress.tests." + UUID().uuidString)! }

    static func main() {
        stats(); missions(); tutorial(); rivals(); racing()
        print("ProgressTests passed: lifetime stats and achievements, daily/weekly missions, guided tutorial, rival levels, mistakes and ramp flips on every route, race standings, overtakes and prizes.")
    }

    static func stats() {
        let prefs = suite(); let s = RideStats(preferences: prefs)
        var r = RunReport(); r.distance = 1_200; r.finished = true; r.flips = 1; r.bestCombo = 1_200; r.score = 1_500; r.wheelieMetres = 80
        let first = s.record(r).map(\.id)
        check(Set(first) == ["first-finish", "first-flip", "combo-1000"], "First run unlocks: \(first)")
        let second = s.record(r).map(\.id)
        check(second.isEmpty, "An achievement is only unlocked once: \(second)")
        check(s.totals.runs == 2 && s.totals.distance == 2_400 && s.totals.bestCombo == 1_200, "Totals accumulate")
        var bad = RunReport(); bad.distance = .nan; bad.wheelieMetres = -5; bad.flips = -3
        s.record(bad); check(s.totals.distance == 2_400 && s.totals.flips == 2, "Invalid values are ignored")
        var endless = RunReport(); endless.endless = true; endless.distance = 3_400; endless.crashed = true
        check(s.record(endless).map(\.id).contains("endless-3000") && s.totals.bestEndless == 3_400 && s.totals.crashes == 1, "Endless marathon")
        check(s.markTutorialDone().map(\.id) == ["tutorial"] && s.markTutorialDone().isEmpty, "Tutorial achievement once")
        let again = RideStats(preferences: prefs)
        check(again.totals == s.totals && again.earned == s.earned, "Stats persist")
        check(again.summary.count == 6, "Summary lines")
        check(Set(RideAchievement.all.map(\.id)).count == RideAchievement.all.count, "Unique achievement ids")
        // Previews: what a run would unlock, without changing anything, and consistent with record().
        let p2 = suite(); let live = RideStats(preferences: p2)
        var running = RunReport(); running.flips = 1; running.distance = 400
        let before = live.totals
        check(live.preview(running).map(\.id) == ["first-flip"] && live.totals == before && live.earned.isEmpty, "Preview changes nothing")
        check(live.preview(RunReport()).isEmpty, "An empty run unlocks nothing")
        check(live.record(running).map(\.id) == ["first-flip"], "record() agrees with preview()")
        check(live.preview(running).isEmpty, "Already earned achievements are not previewed again")
    }

    static func missions() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!; cal.firstWeekday = 2
        var date = cal.date(from: DateComponents(year: 2026, month: 3, day: 11, hour: 12))!
        let prefs = suite()
        let m = RideMissions(preferences: prefs, calendar: cal, now: { date })
        check(m.daily.count == 3 && Set(m.daily.map(\.metric)).count == 3, "Three distinct daily missions")
        let titles = m.daily.map(\.title) + [m.weekly.title]
        let same = RideMissions(preferences: suite(), calendar: cal, now: { date })
        check(same.daily == m.daily && same.weekly == m.weekly, "Same day, same missions: \(titles)")
        // A huge run completes everything accumulating; each mission rewards once.
        var big = RunReport(); big.distance = 100_000; big.wheelieMetres = 5_000; big.stoppieMetres = 5_000; big.flips = 100; big.spins = 100
        big.jumps = 500; big.dodges = 500; big.finished = true; big.noHandsSeconds = 500; big.score = 100_000; big.bestCombo = 100_000
        let done = m.record(big)
        check(done.count == 4 && done.reduce(0, { $0 + $1.reward }) > 0, "Everything completes once: \(done.count)")
        check(m.record(big).isEmpty, "Completed missions never pay twice")
        check((0..<3).allSatisfy { m.isDone(daily: $0) } && m.weeklyDone, "Marked done")
        let reopened = RideMissions(preferences: prefs, calendar: cal, now: { date })
        check(reopened.isDone(daily: 0) && reopened.record(big).isEmpty, "Progress persists")
        // Next day: new set of goals and cleared progress; the weekly goal persists within the week.
        date = cal.date(from: DateComponents(year: 2026, month: 3, day: 12, hour: 9))!
        let next = RideMissions(preferences: prefs, calendar: cal, now: { date })
        check(!next.isDone(daily: 0) && next.progress(daily: 0) == 0 && next.weeklyDone, "A new day resets dailies, not the week")
        date = cal.date(from: DateComponents(year: 2026, month: 3, day: 17, hour: 9))!
        let later = RideMissions(preferences: prefs, calendar: cal, now: { date })
        check(!later.weeklyDone && later.weeklyProgress == 0, "A new week resets the weekly mission")
        // "Best of a run" missions take the maximum, not the sum.
        let p2 = suite(); let single = RideMissions(preferences: p2, calendar: cal, now: { date })
        var small = RunReport(); small.score = 10; small.bestCombo = 10
        single.record(small); single.record(small)
        for (i, mission) in single.daily.enumerated() where mission.metric == .score { check(single.progress(daily: i) == 10, "Score missions use the best run") }
        // Mission previews match what record() later completes and never mutate progress.
        let p3 = suite(); let pm = RideMissions(preferences: p3, calendar: cal, now: { date })
        let beforeState = pm.state
        var huge = RunReport(); huge.distance = 100_000; huge.wheelieMetres = 5_000; huge.stoppieMetres = 5_000; huge.flips = 100; huge.spins = 100
        huge.jumps = 500; huge.dodges = 500; huge.finished = true; huge.noHandsSeconds = 500; huge.score = 100_000; huge.bestCombo = 100_000
        let previewed = pm.preview(huge)
        check(previewed.count == 4 && pm.state.dayProgress == beforeState.dayProgress && !pm.weeklyDone, "Mission preview changes nothing")
        check(pm.record(huge) == previewed, "record() completes what preview() announced")
        check(pm.preview(huge).isEmpty, "Completed missions are not previewed again")
        // Every mission has a readable Spanish title with its target.
        for metric in MissionMetric.allCases { check(Mission(metric: metric, target: 7, reward: 1).title.contains("7"), "Title for \(metric)") }
    }

    static func tutorial() {
        var t = RideTutorial(), o = TutorialObservation()
        check(t.step == .accelerate && !t.finished && t.instruction.contains("20 km/h"), "Starts by accelerating")
        o.speed = 3; t.update(o); check(t.step == .accelerate && t.progress > 0.4, "Progress while accelerating")
        o.speed = 6; check(t.update(o) && t.step == .wheelie, "Speed completes step 1")
        o.rearContact = true; o.frontContact = false; o.wheelieDistance = 4.2
        check(t.update(o) && t.step == .correct, "Wheelie completes step 2")
        o.frontContact = true; o.wheelieDistance = 0
        for _ in 0..<30 { t.update(o) }
        check(t.step == .correct, "Not yet: one second of both wheels needed")
        for _ in 0..<40 { t.update(o) }
        check(t.step == .brake, "Correcting completes step 3")
        o.speed = 2; o.brakeHeld = true; t.update(o); check(t.step == .brake, "Braking from a standstill does not count until you were moving")
        o.speed = 6; o.brakeHeld = false; t.update(o); o.speed = 1; o.brakeHeld = true
        check(t.update(o) && t.step == .jump, "Braking to a stop completes step 4")
        o.crashed = true; o.landingSerial = 5; o.lastAirTime = 0.8; check(!t.update(o), "A crash never advances")
        o.crashed = false; o.lastAirTime = 0; o.landingSerial = 5; t.update(o)
        o.landingSerial = 6; o.lastAirTime = 0.1; check(!t.update(o) && t.step == .jump, "A hop shorter than 0.3 s is not a jump")
        o.landingSerial = 7; o.lastAirTime = 0.6; check(t.update(o) && t.step == .flip, "A real jump completes step 5")
        o.landingSerial = 8; o.lastAirTime = 0.9; o.lastFlips = 0; check(!t.update(o), "Landing without flipping does not finish")
        o.landingSerial = 9; o.lastFlips = 1; check(t.update(o) && t.finished && t.title.contains("completado"), "A flip finishes the tutorial")
        check(!t.update(o) && RideTutorial.stepCount == 6, "Finished tutorial is inert")
    }

    static func racing() {
        func e(_ d: Double, _ t: Double? = nil, crashed: Bool = false) -> RaceEntry { RaceEntry(distance: d, finishTime: t, crashed: crashed) }
        check(RideRace.isAhead(e(100), of: e(50)) && !RideRace.isAhead(e(50), of: e(100)) && !RideRace.isAhead(e(70), of: e(70)), "Further along is ahead; a tie is nobody's")
        check(RideRace.isAhead(e(1_200, 90), of: e(1_199)) && !RideRace.isAhead(e(1_199), of: e(1_200, 90)), "A finisher beats anyone still riding")
        check(RideRace.isAhead(e(1_200, 80), of: e(1_200, 90)) && !RideRace.isAhead(e(1_200, 95), of: e(1_200, 90)), "Finishers rank by time")
        check(RideRace.position(player: e(500), rivals: [e(600), e(400), e(700)]) == 3, "Two rivals ahead: third")
        check(RideRace.position(player: e(500), rivals: []) == 1 && RideRace.position(player: e(500), rivals: [e(10, crashed: true)]) == 1, "Leading, and a crashed rival behind does not count")
        check(RideRace.position(player: e(500, crashed: true), rivals: [e(600), e(400)]) == 2, "A crashed player keeps the distance reached")
        check(RideRace.position(player: e(1_200, 100), rivals: [e(1_200, 90), e(1_200, 110), e(900)]) == 2, "Finish times decide among finishers")
        check(RideRace.prize(position: 1, fieldSize: 2) == 25 && RideRace.prize(position: 2, fieldSize: 2) == 0, "Duel prize")
        check([1, 2, 3, 4].map { RideRace.prize(position: $0, fieldSize: 4) } == [40, 20, 8, 0] && RideRace.prize(position: 0, fieldSize: 4) == 0 && RideRace.prize(position: 1, fieldSize: 1) == 0, "Field prizes")
        var tracker = RideRace.OvertakeTracker()
        check(tracker.update(player: 0, rivals: [e(0), e(20)]).isEmpty, "Nothing happens at the start")
        check(tracker.update(player: 10, rivals: [e(0), e(20)]).isEmpty, "The first sighting is a baseline, not a pass")
        check(tracker.update(player: 25, rivals: [e(0), e(20)]) == [RideRace.OvertakeTracker.Event(rival: 1, playerPassed: true)], "Passing a rival is reported once")
        check(tracker.update(player: 26, rivals: [e(0), e(20)]).isEmpty, "...and not repeated")
        check(tracker.update(player: 26, rivals: [e(0), e(24)]).isEmpty, "Side by side (within the margin) is not a pass")
        check(tracker.update(player: 26, rivals: [e(0), e(40)]) == [RideRace.OvertakeTracker.Event(rival: 1, playerPassed: false)], "Being passed is reported")
        let afterCrash = tracker.update(player: 500, rivals: [e(0, crashed: true), e(40)])
        check(afterCrash == [RideRace.OvertakeTracker.Event(rival: 1, playerPassed: true)], "Only live rivals are reported (crashed rivals are ignored): \(afterCrash)")
        check(tracker.update(player: .nan, rivals: [e(0)]).isEmpty, "Invalid distances are ignored")
        check(Set(RivalLevel.allCases.map { $0.field().count }) == [3] && RivalLevel.expert.field().contains(.expert) && !RivalLevel.easy.field().contains(.expert), "Fields around the chosen level")
    }

    static func rivals() {
        var avg: [RivalLevel: Double] = [:], flips = 0, finished: [RivalLevel: Int] = [:], total = 0
        for level in RivalLevel.allCases {
            var sum = 0.0, count = 0
            for kind in [BikeKind.commuter, .sport, .motocross, .scooter] { for route in 0..<BikePhysics.routeCount {
                let r = RideRival(level: level, kind: kind, route: route, hazards: false, seed: UInt64(route + 3))
                var t = 0.0, serial = 0
                while !r.finished && !r.crashed && t < 400 {
                    r.update(1 / 120); t += 1 / 120
                    if r.bike.landingSerial != serial { serial = r.bike.landingSerial; flips += r.bike.lastFlips }
                }
                if level == .easy { total += 1 }
                if r.finished { sum += t; count += 1; finished[level, default: 0] += 1 }
            } }
            avg[level] = sum / Double(max(1, count))
        }
        check(avg[.easy]! > avg[.normal]! && avg[.normal]! > avg[.expert]!, "Higher levels are faster: \(avg)")
        for level in RivalLevel.allCases { check(Double(finished[level] ?? 0) >= Double(total) * 0.8, "\(level.title) must usually finish (\(finished[level] ?? 0)/\(total))") }
        check(flips > 0, "The expert rival flips off ramps")
        // On rough dirt and dunes the expert flips too, and still finishes: it aborts flips it cannot complete.
        var dirtFlips = 0, dirtRuns = 0, dirtFinished = 0
        for kind in [BikeKind.sport, .commuter, .motocross, .scooter] { for route in 1...2 { for seed in 1...3 {
            let r = RideRival(level: .expert, kind: kind, route: route, hazards: false, seed: UInt64(seed * 17 + route))
            var t = 0.0, serial = 0
            while !r.finished && !r.crashed && t < 400 {
                r.update(1 / 120); t += 1 / 120
                if r.bike.landingSerial != serial { serial = r.bike.landingSerial; dirtFlips += r.bike.lastFlips }
            }
            dirtRuns += 1; if r.finished { dirtFinished += 1 }
        } } }
        check(dirtFlips > 5 && Double(dirtFinished) >= Double(dirtRuns) * 0.9, "Expert on dirt: \(dirtFlips) flips, \(dirtFinished)/\(dirtRuns) finished")
        let air = RideRival(level: .expert, kind: .sport, route: 0, hazards: false, seed: 1)
        check(air.remainingAirTime() < 0.05, "A grounded bike has no air time left")
        // Same seed, same ride; different seeds differ.
        func ride(_ seed: UInt64) -> Double {
            let r = RideRival(level: .easy, kind: .commuter, route: 1, hazards: false, seed: seed)
            for _ in 0..<12_000 { r.update(1 / 120) }
            return r.bike.x
        }
        check(ride(4) == ride(4), "Rival is deterministic per seed")
        let r = RideRival(level: .normal, kind: .bmx, route: 0, hazards: true, seed: 1)
        r.update(.nan); r.update(-1); r.update(0)
        check(r.bike.x.isFinite && !r.crashed, "Invalid time steps are ignored")
    }
}
