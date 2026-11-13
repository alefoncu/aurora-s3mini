import Cocoa

/// Heads-up display and on-screen hints.
extension RideView {
    func hud() {
        let W=sceneWidth,cx=W/2
        art.text("\(Int(bike.distance)) m",28,24,23,.white,.semibold,mono:true)
        art.text(bike.endless ? "Vuelta \(Int(bike.x/1200)+1) · infinito" : BikePhysics.circuit ? "de \(Int(bike.finishDistance)) m" : "de 1.200 m",29,54,11,NSColor.white.withAlphaComponent(0.72))
        art.box(29,75,145,2,NSColor.white.withAlphaComponent(0.22),1)
        art.box(29,75,145*((bike.endless || BikePhysics.circuit) ? bike.x.truncatingRemainder(dividingBy:1200) : bike.x)/1200,2,.white,1)
        art.text(String(format:"%02d:%04.1f",Int(elapsed)/60,elapsed.truncatingRemainder(dividingBy:60)),(W-92),28,18,.white,.medium,center:true,mono:true)
        if bike.rearContact && !bike.frontContact && bike.wheelieDistance>0.2 {
            art.text("Caballito",cx,27,11,NSColor.white.withAlphaComponent(0.75),.medium,center:true)
            art.text("\(Int(bike.wheelieDistance)) m",cx,45,25,.white,.semibold,center:true,mono:true)
            art.box(cx-56,83,112,2,NSColor.white.withAlphaComponent(0.25),1)
            art.box(cx-56,83,112*min(1,bike.angle/1.72),2,bike.angle>1.4 ? .systemOrange : .white,1)
        }
        if bike.isStoppie && bike.stoppieDistance>0.2 {
            art.text("Invertido",cx,27,11,NSColor.white.withAlphaComponent(0.75),.medium,center:true)
            art.text(String(format:"%.1f m",bike.stoppieDistance),cx,45,25,.white,.semibold,center:true,mono:true)
            art.box(cx-56,83,112,2,NSColor.white.withAlphaComponent(0.25),1)
            art.box(cx-56,83,112*min(1,-bike.angle/1.1),2,bike.angle < -0.85 ? .systemOrange : .white,1)
        }
        if challengeKind != .free && challengeKind != .tutorial && challengeKind != .circuit { art.text(challenges.progressText,28,117,12,.white,.medium) }
        if ghostEnabled,let ghost=challenges.ghostFrame(at:elapsed) {
            if let delta=challenges.timeDelta(elapsed:elapsed,atDistance:bike.x) {
                art.text(String(format:"Fantasma %+.1f s",delta),(W-95),62,11,delta<=0 ? NSColor.systemGreen : NSColor.systemOrange,.semibold,center:true,mono:true)
            } else { art.text(String(format:"Fantasma %+.0f m",ghost.x-bike.x),(W-95),62,11,NSColor.white.withAlphaComponent(0.8),center:true,mono:true) }
        }
        if !rivalRuns.isEmpty {
            // Position, and the gap to the nearest rival still racing ahead (or behind when leading).
            let field=rivalRuns.count+1
            art.text("POSICIÓN \(racePosition)/\(field)",(W-95),76,12,racePosition == 1 ? NSColor.systemGreen : .white,.bold,center:true,mono:true)
            let racing=rivalRuns.filter { !$0.crashed && !$0.finished }
            if let nearest=racing.min(by:{ abs($0.bike.x-bike.x)<abs($1.bike.x-bike.x) }) {
                let gap=bike.x-nearest.bike.x
                art.text(String(format:gap>=0 ? "a %.0f m del siguiente" : "a %.0f m del de delante",abs(gap)),(W-95),91,10,gap>=0 ? NSColor.systemGreen : NSColor.systemOrange,.medium,center:true,mono:true)
            } else if rivalRuns.allSatisfy({ $0.crashed }) { art.text("Rivales caídos",(W-95),91,10,NSColor.systemGreen,.medium,center:true) }
        }
        let sy:Double = rivalRuns.isEmpty ? 0 : 26   // the race position lines sit above the score box
        art.box(W-168,94+sy,152,(score.pending>0 || !score.popups.isEmpty) ? 128 : 52,NSColor.black.withAlphaComponent(0.22),8)
        art.text("PUNTOS",(W-92),100+sy,10,NSColor.white.withAlphaComponent(0.7),.semibold,center:true)
        art.text("\(score.total)",(W-92),114+sy,23,.white,.semibold,center:true,mono:true)
        if score.chainActive || score.pending>0 {
            art.text(String(format:"x%.1f · cadena %d",score.multiplier,score.chainPoints),(W-92),144+sy,11,.systemYellow,.semibold,center:true,mono:true)
            art.box(W-150,162+sy,116,2,NSColor.white.withAlphaComponent(0.25),1)
            art.box(W-150,162+sy,116*max(0,min(1,score.chainTimer/RideScore.chainWindow)),2,.systemYellow,1)
        }
        for (i,popup) in score.popups.enumerated() {
            art.text("+\(popup.points) \(popup.text)",(W-92),174+sy+Double(i)*17,11,NSColor.white.withAlphaComponent(max(0.2,1-popup.age/2.2)),.medium,center:true)
        }
        if splitAge<4 { art.text(splitText,cx,150,13,.white,.semibold,center:true) }
        if challengeKind == .tutorial {
            art.box(cx-300,128,600,tutorial.finished ? 56 : 72,NSColor.black.withAlphaComponent(0.42),10)
            art.text(tutorial.finished ? tutorial.title : "Tutorial \(tutorial.stepNumber)/\(RideTutorial.stepCount) · \(tutorial.title)",cx,136,14,.systemYellow,.semibold,center:true)
            art.text(tutorial.instruction,cx,158,12,.white,.medium,center:true)
            if !tutorial.finished { art.box(cx-280,184,560,3,NSColor.white.withAlphaComponent(0.25),1); art.box(cx-280,184,560*tutorial.progress,3,.systemYellow,1) }
        }
        for (i,toast) in toasts.enumerated() {
            let alpha=max(0,min(1,(4-toast.age)/1.2)),y=228+Double(i)*30
            art.box(cx-200,y-4,400,26,NSColor.black.withAlphaComponent(0.45*alpha),8)
            art.text("★ "+toast.text,cx,y,13,NSColor.systemYellow.withAlphaComponent(alpha),.semibold,center:true)
        }
        if tutorialToastAge<2.5 { art.text(tutorialToast,cx,206,16,.systemGreen,.bold,center:true) }
        if bike.tyreWear>0.08 || bike.suspensionHeat>0.3 {
            art.text(String(format:"Neumáticos %d %%",Int((1-bike.tyreWear*0.3)*100)),28,sceneHeight-58,11,bike.tyreWear>0.6 ? .systemOrange : NSColor.white.withAlphaComponent(0.8),.medium,mono:true)
            art.text(String(format:"Amortiguadores %d %%",Int((1-bike.suspensionHeat*0.35)*100)),28,sceneHeight-40,11,bike.suspensionHeat>0.6 ? .systemOrange : NSColor.white.withAlphaComponent(0.8),.medium,mono:true)
        }
        if let label=weather.label { art.text(label.uppercased(),28,104,11,weather.storm ? NSColor.systemYellow : NSColor(hex:0xBFD4EA),.bold) }
        let stage=BikePhysics.difficultyStage(at:bike.x)
        if BikePhysics.circuit {
            art.text("CIRCUITO · VUELTA \(min(bike.laps,Int(bike.x/1200)+1))/\(bike.laps)",28,90,11,.white,.semibold)
            for (i,time) in lapTimes.enumerated() { art.text(String(format:"V%d %d:%04.1f",i+1,Int(time)/60,time.truncatingRemainder(dividingBy:60)),28,132+Double(i)*15,11,NSColor.white.withAlphaComponent(0.8),.medium,mono:true) }
        } else {
        art.text("TRAMO \(stage+1)/4 · \(BikePhysics.stageTitle(at:bike.x))",28,90,11,.white,.semibold)
        for marker in 1...3 { art.box(29+145*Double(marker)/4,72,1,8,NSColor.white.withAlphaComponent(0.6)) }
        }
        let toNext=Double((stage+1)*300)-bike.x
        if BikePhysics.circuit || bike.endless { }
        else if stage<3 && toNext<65 {
            art.text("Próximo tramo: \(BikePhysics.stageTitle(at:Double((stage+1)*300))) · \(max(0,Int(toNext))) m",cx,101,12,.white,.medium,center:true)
        } else if stage>0 && bike.x-Double(stage*300)<35 {
            art.text(stage == 3 ? "Anticipa los cambios de pendiente y dosifica el gas" : "Terreno más irregular · controla los aterrizajes",cx,101,12,.white,.medium,center:true)
        }
        if obstaclesOn, let next=obstacleList.first(where:{Double($0)>bike.x && !knockedCones.contains($0)}), Double(next)-bike.x<max(10,bike.speed*0.7) {
            let name=BikePhysics.obstacleKind(at:next) == .cone ? "Cono" : BikePhysics.obstacleKind(at:next) == .barrel ? "Barril" : "Tronco"
            art.text("\(name) a \(max(1,Int(Double(next)-bike.x))) m",cx,124,12,.white,.medium,center:true)
        }
    }
    func drawControls() {
        let cx=sceneWidth/2
        art.text("\(Int(bike.speed*3.6))",cx,sceneHeight-76,32,.white,.medium,center:true,mono:true)
        art.text("km/h",cx,sceneHeight-37,10,NSColor.white.withAlphaComponent(0.6),center:true)
        if bike.kind != .bmx {
            let gear=bike.transmission.gear == 0 ? "CVT" : "\(bike.transmission.automatic ? "A" : "M")\(bike.transmission.gear)"
            art.text("\(gear) · \(Int(bike.transmission.rpm)) rpm",cx,sceneHeight-18,11,.white,.medium,center:true,mono:true)
        }
        if max(abs(bike.frontSlip),abs(bike.rearSlip))>0.25 && (bike.frontContact || bike.rearContact) {
            let message=bike.rearSlip>0.25 ? "Pérdida de tracción" : "Rueda deslizando"
            art.text(message,cx,sceneHeight-98,11,.systemOrange,.semibold,center:true)
        }
        if elapsed<7 {
            art.text("H sin manos   G giro 360° (en el aire)   V superman (en el aire)   T + ←/→ voltereta",cx,sceneHeight-134,12,NSColor.white.withAlphaComponent(0.7),.medium,center:true)
            art.text("↑ acelerar   ← levantar   → peso delante   ↓ frenos   Z delante   X detrás   Q/F marchas   E invertido   Espacio saltar",cx,sceneHeight-116,12,NSColor.white.withAlphaComponent(0.78),.medium,center:true)
        }
    }
}
