import Cocoa

/// Pause and result overlay: native panel, buttons and the result text.
extension RideView {
    func buildStateOverlay() {
        let dim=RideDimView(frame:bounds); dim.autoresizingMask=[.width,.height]; stateOverlay=dim; addSubview(dim)
        // Liquid Glass where the system has it; the classic HUD material otherwise.
        let inner=NSView()
        if #available(macOS 26.0, *) {
            let glass=NSGlassEffectView(); glass.cornerRadius=22; glass.contentView=inner; statePanel=glass
        } else {
            let effect=NSVisualEffectView(); effect.material = .hudWindow; effect.blendingMode = .withinWindow; effect.state = .active
            effect.wantsLayer=true; effect.layer?.cornerRadius=18; effect.addSubview(inner); statePanel=effect
            inner.translatesAutoresizingMaskIntoConstraints=false
            NSLayoutConstraint.activate([inner.leadingAnchor.constraint(equalTo:effect.leadingAnchor),inner.trailingAnchor.constraint(equalTo:effect.trailingAnchor),inner.topAnchor.constraint(equalTo:effect.topAnchor),inner.bottomAnchor.constraint(equalTo:effect.bottomAnchor)])
        }
        statePanel.translatesAutoresizingMaskIntoConstraints=false; dim.addSubview(statePanel)
        chartView=RideRunChart(); chartView.isHidden=true
        stateTitle=NSTextField(labelWithString:""); stateTitle.font = .systemFont(ofSize:27,weight:.bold); stateTitle.alignment = .center
        stateDetail=NSTextField(wrappingLabelWithString:""); stateDetail.font = .systemFont(ofSize:13); stateDetail.textColor = .secondaryLabelColor; stateDetail.alignment = .center
        continueButton=NSButton(title:"Continuar",target:self,action:#selector(resumeAction)); continueButton.bezelStyle = .rounded; continueButton.controlSize = .large; continueButton.keyEquivalent="\r"; continueButton.bezelColor = .controlAccentColor
        retryButton=NSButton(title:"Reiniciar ruta",target:self,action:#selector(retryAction)); retryButton.bezelStyle = .rounded; retryButton.controlSize = .large
        let home=NSButton(title:"Volver al taller",target:self,action:#selector(garageAction)); home.bezelStyle = .rounded; home.controlSize = .large
        let stack=NSStackView(views:[stateTitle,stateDetail,chartView,continueButton,retryButton,home]); stack.orientation = .vertical; stack.spacing=18; stack.alignment = .centerX; inner.addSubview(stack); stack.translatesAutoresizingMaskIntoConstraints=false
        NSLayoutConstraint.activate([statePanel.centerXAnchor.constraint(equalTo:dim.centerXAnchor),statePanel.centerYAnchor.constraint(equalTo:dim.centerYAnchor),statePanel.widthAnchor.constraint(equalToConstant:350),stack.leadingAnchor.constraint(equalTo:inner.leadingAnchor,constant:30),stack.trailingAnchor.constraint(equalTo:inner.trailingAnchor,constant:-30),stack.topAnchor.constraint(equalTo:inner.topAnchor,constant:30),stack.bottomAnchor.constraint(equalTo:inner.bottomAnchor,constant:-30),chartView.widthAnchor.constraint(equalTo:stack.widthAnchor),chartView.heightAnchor.constraint(equalToConstant:84),continueButton.widthAnchor.constraint(equalTo:stack.widthAnchor),retryButton.widthAnchor.constraint(equalTo:stack.widthAnchor),home.widthAnchor.constraint(equalTo:stack.widthAnchor),stateDetail.widthAnchor.constraint(equalTo:stack.widthAnchor)])
        dim.isHidden=true
    }
    @objc func resumeAction() { pause(); window?.makeFirstResponder(self) }
    @objc func retryAction() { start() }
    @objc func garageAction() { garage() }
    func updateStateOverlay() {
        stateOverlay.isHidden = mode != .paused && mode != .result
        continueButton.isHidden = mode != .paused
        stateTitle.stringValue = mode == .paused ? "En pausa" : bike.finished ? "Ruta completada" : "Otra vuelta"
        stateDetail.stringValue = mode == .paused ? "Tu ruta sigue aquí." : "\(Int(bike.distance)) m de recorrido\n\(Int(bike.bestWheelie)) m de caballito · \(String(format:"%.1f",bike.bestStoppie)) m de invertido"
        if mode == .result {
            stateDetail.stringValue += "\n\(score.total) puntos (récord \(Int(bestScore))) · +\(lastReward) monedas"
            if score.lostToCrash>0 { stateDetail.stringValue += "\nPerdiste \(score.lostToCrash) puntos de una cadena al caerte" }
            let splits=splitDeltas.enumerated().compactMap { i,d in d.map { String(format:"T%d %+.1f s",i+1,$0) } }
            if !splits.isEmpty { stateDetail.stringValue += "\nTramos vs fantasma: "+splits.joined(separator:" · ") }
            if !runNotes.isEmpty { stateDetail.stringValue += "\n"+runNotes.joined(separator:"\n") }
            if !rivalRuns.isEmpty {
                let field=rivalRuns.count+1
                stateDetail.stringValue += bike.finished ? "\nPosición \(racePosition)/\(field)" : "\nTe caíste en la posición \(racePosition)/\(field)"
                if challengeKind == .race { stateDetail.stringValue += challenges.completed ? " · ¡Ganaste a tu rival!" : " · el rival ha ganado o te has caído" }
                else if challengeKind == .circuit { stateDetail.stringValue += challenges.completed ? " · ¡podio!" : "" }
            }
        }
        if mode == .result && challengeKind != .free && challengeKind != .race && challengeKind != .circuit && challengeKind != .tutorial && challengeKind != .endless { stateDetail.stringValue += "\n"+challenges.progressText }
        chartView.isHidden = !(mode == .result && samples.count>8); if !chartView.isHidden { chartView.samples=samples }
        retryButton.title = mode == .paused ? "Reiniciar ruta" : "Volver a salir"
        retryButton.keyEquivalent = mode == .result ? "\r" : ""
    }
}

private final class RideDimView:NSView {
    override var isFlipped:Bool { true }
    override func draw(_ dirtyRect:NSRect) { NSColor.black.withAlphaComponent(0.28).setFill(); bounds.fill() }
}
