import Cocoa

// Exercises real NSTouchBar items and native button actions without a window or
// pretending to simulate a physical finger on the hardware.
@main
struct TouchBarTests {
    struct Hold: Equatable { let action: RideAction; let down: Bool }
    static func main() {
        NSApplication.shared.setActivationPolicy(.prohibited)
        var holds: [Hold] = [], commands: [RideCommand] = []
        let controller = TouchBarController(onHold: { holds.append(Hold(action:$0,down:$1)) },
                                            onCommand: { commands.append($0) })
        func id(_ suffix:String)->NSTouchBarItem.Identifier { .init("com.scratch.wheelieride.touchbar.\(suffix)") }
        func item(_ bar:NSTouchBar,_ suffix:String)->NSCustomTouchBarItem {
            guard let value=controller.touchBar(bar,makeItemForIdentifier:id(suffix)) as? NSCustomTouchBarItem else { fatalError("Missing \(suffix)") }
            return value
        }
        func button(_ bar:NSTouchBar,_ suffix:String)->NSButton { item(bar,suffix).view as! NSButton }
        func checkCommand(_ button:NSButton,_ expected:RideCommand) {
            precondition(button.isEnabled)
            let before=commands.count
            button.performClick(nil)
            precondition(commands.count==before+1 && commands.last==expected,"Native Touch Bar button must route its command")
        }
        let garage=controller.touchBar
        precondition(garage.customizationIdentifier == nil)
        precondition(controller.touchBar(garage,makeItemForIdentifier:id("throttle")) == nil)
        let play=button(garage,"restart"); precondition(play.title=="Rodar"); checkCommand(play,.restart)
        controller.update(mode:.riding,speed:10,wheelie:20)
        let riding=controller.touchBar
        precondition(riding !== garage && riding.customizationIdentifier=="com.scratch.wheelieride.touchbar")
        var items:[RideAction:NSCustomTouchBarItem]=[:]
        for action in RideAction.allCases { items[action]=item(riding,action.rawValue) }
        for action in RideAction.allCases {
            let before=holds.count
            precondition(items[action]!.view.accessibilityPerformPress())
            precondition(holds.last==Hold(action:action,down:true))
            controller.releaseAll()
            precondition(holds.count==before+2 && holds.last==Hold(action:action,down:false))
        }
        controller.update(mode:.riding,speed:10,wheelie:0,gear:2,rpm:5400,automatic:false)
        let up=button(riding,"shiftUp"), down=button(riding,"shiftDown")
        checkCommand(up,.shiftUp); checkCommand(down,.shiftDown)
        precondition((item(riding,"status").view as! NSTextField).stringValue.contains("M2") && (item(riding,"status").view as! NSTextField).stringValue.contains("5400"))
        let throttle=items[.throttle]!.view
        precondition(throttle.accessibilityPerformPress())
        let beforeShift=holds.count
        checkCommand(up,.shiftUp)
        precondition(holds.count==beforeShift,"Changing gear must preserve held gas and rider balance")
        controller.update(mode:.riding,speed:10,wheelie:0,gear:2,rpm:5400,automatic:true)
        precondition(!up.isEnabled && !down.isEnabled,"Automatic transmission must disable manual gear commands")
        let beforeDisabledShift=commands.count
        up.performClick(nil); down.performClick(nil)
        precondition(commands.count==beforeDisabledShift)
        controller.update(mode:.riding,speed:10,wheelie:0,gear:0,rpm:0,automatic:false)
        precondition(!up.isEnabled && !down.isEnabled,"Bicycle and CVT telemetry must not expose manual gear controls")
        controller.releaseAll()
        precondition(throttle.accessibilityPerformPress())
        let beforeUpdate=holds.count
        controller.update(mode:.riding,speed:12,wheelie:23)
        precondition(controller.touchBar === riding && holds.count==beforeUpdate,"Telemetry must preserve held gas and bar identity")
        checkCommand(button(riding,"pause"),.pause)
        precondition(holds.last==Hold(action:.throttle,down:false),"Commands release held gas")
        precondition(throttle.accessibilityPerformPress())
        controller.update(mode:.paused,speed:12,wheelie:23)
        let paused=controller.touchBar
        precondition(paused !== riding && paused.customizationIdentifier==nil)
        precondition(holds.last==Hold(action:.throttle,down:false),"Pause releases driving input")
        precondition(controller.touchBar(paused,makeItemForIdentifier:id("throttle"))==nil)
        for value in items.values { precondition(!value.view.accessibilityPerformPress()) }
        let resume=button(paused,"pause"), restart=button(paused,"restart"), home=button(paused,"garage")
        precondition(resume.title=="Continuar" && restart.title=="Reiniciar" && home.title=="Taller")
        checkCommand(resume,.pause); checkCommand(restart,.restart); checkCommand(home,.garage)
        precondition((item(paused,"status").view as! NSTextField).stringValue=="EN PAUSA")
        controller.update(mode:.paused,speed:12,wheelie:23)
        precondition(controller.touchBar === paused && resume.isEnabled)
        controller.update(mode:.riding,speed:12,wheelie:23)
        precondition(controller.touchBar === riding && !resume.isEnabled,"Resuming returns the cached gameplay bar and disables stale pause buttons")
        precondition(throttle.accessibilityPerformPress())
        precondition(items[.leanBack]!.view.accessibilityPerformPress())
        let combined=holds.count
        NotificationCenter.default.post(name:NSApplication.didResignActiveNotification,object:nil)
        let releases=Array(holds.suffix(2))
        precondition(holds.count==combined+2 && releases.allSatisfy{!$0.down})
        precondition(Set(releases.map{$0.action.rawValue})==Set(["throttle","leanBack"]))
        let cancelled=holds.count
        controller.releaseAll(); controller.releaseAll(); precondition(holds.count==cancelled)
        precondition(throttle.accessibilityPerformPress())
        RunLoop.main.run(until:Date(timeIntervalSinceNow:0.3))
        precondition(holds.last==Hold(action:.throttle,down:false),"Accessible pulse auto releases")
        precondition(throttle.accessibilityPerformPress())
        let beforeReplace=holds.count
        _=item(riding,"throttle")
        precondition(holds.count==beforeReplace+1 && holds.last==Hold(action:.throttle,down:false))
        precondition(!throttle.accessibilityPerformPress(), "A replaced control must stay disabled")
        controller.update(mode:.result,speed:0,wheelie:0)
        let result=controller.touchBar
        precondition(result.customizationIdentifier==nil)
        let again=button(result,"restart"); precondition(again.title=="Otra vuelta"); checkCommand(again,.restart)
        checkCommand(button(result,"garage"),.garage)
        controller.update(mode:.blocked,speed:0,wheelie:0)
        let blocked=controller.touchBar
        precondition(blocked.defaultItemIdentifiers==[id("status")])
        for command in ["pause","restart","garage","throttle"] { precondition(controller.touchBar(blocked,makeItemForIdentifier:id(command))==nil) }
        precondition(!resume.isEnabled && !restart.isEnabled && !again.isEnabled && !play.isEnabled)
        let blockedCommands=commands.count
        resume.performClick(nil); restart.performClick(nil); again.performClick(nil); play.performClick(nil)
        precondition(commands.count==blockedCommands,"Inactive native buttons must not fire behind a sheet")
        controller.update(mode:.garage,speed:0,wheelie:0)
        precondition(controller.touchBar === garage && play.isEnabled)
        controller.update(riding:true,paused:true,speed:0,wheelie:0)
        precondition(controller.touchBar === paused,"Compatibility API maps paused correctly")
        controller.update(mode:.riding,speed:8,wheelie:0,stoppie:3.4)
        let invertido=item(riding,"stoppie").view
        precondition(invertido.accessibilityPerformPress() && holds.last==Hold(action:.stoppie,down:true))
        precondition((item(riding,"status").view as! NSTextField).stringValue.contains("INV"))
        controller.update(mode:.paused,speed:8,wheelie:0,stoppie:3.4)
        precondition(holds.last==Hold(action:.stoppie,down:false),"Pausing must release the combined stoppie input")
        print("TouchBarTests passed: separate brakes, manual gear routing and interlocks, RPM telemetry, contextual garage/pause/result actions, native button routing, stable bar identity, telemetry, blocked contexts, all driving holds, cancellation and customization replacement.")
    }
}
