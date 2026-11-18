import Cocoa

/// `--feature-shots <folder>`: real window captures of the accessibility sheet, the pilot centre, the result panel with its
/// chart and the HUD with large text, contrast and symbols, so the new screens can be reviewed without playing.
extension AppDelegate {
    func featureShots(to directory:String) {
        game.audio.enabled=false; game.progress.unlockEverything(); game.obstacles=true; game.bike.kind = .sport
        try? FileManager.default.createDirectory(atPath:directory,withIntermediateDirectories:true)
        func pump(_ seconds:Double) { RunLoop.current.run(until:Date(timeIntervalSinceNow:seconds)) }
        func shot(_ win:NSWindow,_ name:String) {
            pump(0.4)
            if let image=CGWindowListCreateImage(.null,.optionIncludingWindow,CGWindowID(win.windowNumber),[.boundsIgnoreFraming,.bestResolution]) {
                try? NSBitmapImageRep(cgImage:image).representation(using:.png,properties:[:])?.write(to:URL(fileURLWithPath:directory+"/"+name+".png"))
            }
        }
        // HUD with every accessibility option on.
        game.access.textScale=1.3; game.access.highContrastApp=true; game.access.noColorOnlyApp=true
        game.bike.route=0; game.challengeKind = .race; game.start(); game.bike.x=560
        for _ in 0..<60 { game.keys=[126]; game.advanceFrame(1/60); pump(0.01) }
        shot(window,"hud-accessible")
        game.access.textScale=1; game.access.highContrastApp=false; game.access.noColorOnlyApp=false
        // Result panel with the chart.
        game.challengeKind = .free; game.start()
        var frames=0
        while game.mode != .result && frames<6000 { game.keys=[126]; game.advanceFrame(1/60); frames+=1; if frames%30 == 0 { pump(0.005) } }
        game.syncState(); shot(window,"result-chart")
        // Accessibility sheet.
        game.garage(); showAccessibility(); pump(0.3); if let panel=accessSheet?.panel { shot(panel,"accessibility-sheet") }
        accessSheet.map { window.endSheet($0.panel); $0.panel.orderOut(nil) }; accessSheet=nil
        // Pilot centre, every tab.
        showPilotCenter()
        if let center=pilotCenter,let tabs=center.window.contentView as? NSTabView {
            for (i,item) in tabs.tabViewItems.enumerated() { tabs.selectTabViewItem(at:i); shot(center.window,"pilot-\(i)-\(item.label.lowercased().replacingOccurrences(of:" ",with:"-"))") }
        }
        NSApp.terminate(nil)
    }
}
