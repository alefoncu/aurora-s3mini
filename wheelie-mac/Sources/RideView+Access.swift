import Cocoa

/// Assists, feedback events and VoiceOver announcements during a ride.
extension RideView {
    /// Throttle and weight after the player's assists: relaxed mode keeps the gas open, auto-balance
    /// pushes the weight back before a wheelie or a stoppie tips over.
    func effectiveInputs()->(throttle:Bool,back:Bool,forward:Bool) {
        var throttle=held(.throttle),back=held(.leanBack),forward=held(.leanForward)
        if difficulty == .relaxed && !held(.brake) { throttle=true }
        if access.autoBalance {
            if bike.rearContact && !bike.frontContact && bike.angle>1.4 { forward=true; back=false }
            else if bike.isStoppie && bike.angle < -0.85 { back=true; forward=false }
        }
        return (throttle,back,forward)
    }
    func announce(_ text:String) {
        guard NSWorkspace.shared.isVoiceOverEnabled else { return }
        NSAccessibility.post(element:self,notification:.announcementRequested,userInfo:[.announcement:text,.priority:NSAccessibilityPriorityLevel.high.rawValue])
    }
    func announceLanding() { if bike.landingImpact>4 { announce("Aterrizaje fuerte") } else if bike.landingImpact>1.5 { announce("Aterrizaje") } }
    func updateFeedback(_ dt:Double) {
        let wheelie=bike.rearContact && !bike.frontContact && bike.angle>0.2
        let zone=wheelie && bike.angle>1.05 && bike.angle<1.4
        if zone && !inBalanceZone { feedback.play(.balance) }
        inBalanceZone=zone
        if wheelie {
            let metres=Int(bike.wheelieDistance/25)*25
            if metres>0 && metres != lastAnnouncedWheelie { lastAnnouncedWheelie=metres; announce("Caballito, \(metres) metros") }
        } else { lastAnnouncedWheelie=0 }
        announceClock+=dt
        if announceClock>1 {
            announceClock=0
            setAccessibilityValue("\(Int(bike.speed*3.6)) kilómetros por hora, \(Int(bike.distance)) metros recorridos"+(wheelie ? ", caballito de \(Int(bike.wheelieDistance)) metros" : ""))
        }
        if challengeKind == .tutorial && !tutorial.finished && tutorial.stepNumber != lastTutorialStep {
            lastTutorialStep=tutorial.stepNumber; announce("Paso \(tutorial.stepNumber). \(tutorial.title). \(tutorial.instruction)")
        }
    }
    func applyAccess() {
        feedback.enabled=access.haptics; feedback.setPadEnabled(access.gamepad); access.save(prefs); needsDisplay=true
    }
}

extension RideView {
    /// How far along the route the bike is, 0...1 (endless runs cycle every 3.000 m).
    var routeProgress: Double {
        if bike.endless { return bike.x.truncatingRemainder(dividingBy: 3000) / 3000 }
        return max(0, min(1, bike.x / max(1, BikePhysics.finish)))
    }
}
