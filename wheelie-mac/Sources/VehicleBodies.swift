import Cocoa

/// Bodywork per vehicle. Shapes are given in y-up drawing units relative to the rear axle.
extension RideRenderer {
    // MARK: Shared body details
    func vmRoundLamp(_ c:NSPoint,r:Double,chrome:Bool=true) {
        if chrome { vmChrome(NSBezierPath(ovalIn:NSRect(x:c.x-r-1.4,y:c.y-r-1.4,width:(r+1.4)*2,height:(r+1.4)*2))) }
        else { vmFill(NSBezierPath(ovalIn:NSRect(x:c.x-r-1.4,y:c.y-r-1.4,width:(r+1.4)*2,height:(r+1.4)*2)),colors:[NSColor(hex:0x56646C),NSColor(hex:0x1B252B)],angle:60) }
        vmFill(NSBezierPath(ovalIn:NSRect(x:c.x-r,y:c.y-r,width:r*2,height:r*2)),colors:[NSColor(hex:0xFFFBDF),NSColor(hex:0xD3C58C)],angle:50,outline:0.4)
        circle(c.x+r*0.15,c.y-r*0.1,r*0.42,NSColor(hex:0xFFFFF4,alpha:0.9))
        line(c.x-r*0.5,c.y-r*0.55,c.x+r*0.1,c.y-r*0.78,0.7,NSColor.white.withAlphaComponent(0.7))
    }
    func vmTailLight(_ x:Double,_ y:Double,w:Double=7,h:Double=3.6) {
        vmRounded(NSRect(x:x,y:-y-h,width:w,height:h),radius:1.2,colors:[NSColor(hex:0xFF8068),NSColor(hex:0xB02A24)],angle:90)
        line(x+1,-y-h*0.6,x+w-1,-y-h*0.6,0.5,NSColor.white.withAlphaComponent(0.55))
    }
    func vmIndicator(_ x:Double,_ y:Double) {
        vmFill(NSBezierPath(ovalIn:NSRect(x:x-2,y:-y-1.6,width:4,height:3.2)),colors:[NSColor(hex:0xFFC566),NSColor(hex:0xC77A1F)],outline:0.4)
    }
    func vmPlate(_ x:Double,_ y:Double,w:Double,h:Double,text s:String,size:Double=5) {
        let r=NSRect(x:x,y:-y-h,width:w,height:h)
        vmRounded(r,radius:1,colors:[NSColor(hex:0xFFFFF1),NSColor(hex:0xC8D0C4)],angle:80)
        text(s,x+w/2,-y-h+h*0.5-size*0.62,size,NSColor(hex:0x2B3B40),.heavy,center:true)
    }
    func vmWindscreen(_ pts:[(Double,Double)]) {
        let w=vmSpline(pts)
        vmFill(w,colors:[NSColor(hex:0xCDE4EC,alpha:0.82),NSColor(hex:0x2E4A5C,alpha:0.92)],angle:60,outline:0.7)
        vmClip(w) { line(pts[0].0+2,-pts[0].1-3,pts[1].0+4,-pts[1].1+2,0.9,NSColor.white.withAlphaComponent(0.55)) }
    }
    private func vmKneeGrip(_ pts:[(Double,Double)]) { vmFill(vmSpline(pts),colors:[NSColor(hex:0x4C555B),NSColor(hex:0x151C21)],angle:70,outline:0.5) }

    // MARK: Street 125
    func vmStreetBody(rig:VehicleRig) {
        let tank=vmSpline([(30,45),(32,53),(43,60),(60,62),(73,58),(80,50),(72,43),(54,41),(38,41)])
        vmPanel(tank,body,gloss:0.5)
        vmClip(tank) {
            line(36,-45,74,-49,3.2,vmTone(body,-0.5))
            line(40,-57,64,-60,0.9,NSColor.white.withAlphaComponent(0.55))
        }
        vmKneeGrip([(46,43),(46,52),(58,53),(60,44)])
        vmRounded(NSRect(x:56,y:-65,width:9,height:3.2),radius:1.4,colors:[NSColor(hex:0xE3E7E0),NSColor(hex:0x667880)])   // filler cap
        // Side cover with the badge, airbox and rear fender.
        let side=vmSpline([(7,24),(8,36),(20,40),(34,37),(36,26),(22,20)])
        vmPanel(side,body,gloss:0.25)
        text("125",19,-33,6,vmTone(body,-0.65),.bold,center:true)
        vmSeat(rig:rig,kind:.commuter)
        vmPanel(vmSpline([(-22,22),(-16,30),(-2,32),(12,28),(18,21),(6,24),(-8,24),(-18,16)]),body,gloss:0.3,outline:0.7)
        vmPlate(-24,30,w:9,h:6,text:"125",size:3.6)
        vmTailLight(-18,38); vmIndicator(-17,25)
        vmMetalLink(vmQ(4,40),vmQ(-10,38),width:2.6,dark:true)   // grab handle
        // Retro round headlamp with a chrome bucket, instrument pod.
        vmMetalLink(vmQ(82,57),vmQ(90,54),width:2.2,dark:true)
        vmRoundLamp(vmQ(94,56),r:6.0)
        vmFill(NSBezierPath(ovalIn:NSRect(x:71,y:-73,width:9,height:9)),colors:[NSColor(hex:0x4E5A62),NSColor(hex:0x151C21)],angle:60,outline:0.5)
        circle(75.5,-68.5,3.2,NSColor(hex:0xF4F1DE)); line(75.5,-68.5,77.5,-70,0.5,NSColor(hex:0xC63D2C))
        vmIndicator(88,50)
    }

    // MARK: Cruiser 750
    func vmCruiserBody(rig:VehicleRig) {
        // Big teardrop tank with a chrome strip, deep valanced fenders, saddlebag and a sissy bar.
        let tank=vmSpline([(28,40),(30,50),(42,58),(62,60),(78,56),(83,46),(72,38),(52,36),(36,36)])
        vmPanel(tank,body,gloss:0.55)
        vmClip(tank) { line(34,-47,78,-49,1.6,NSColor(hex:0xF1F4F0)); line(36,-44,76,-45,0.6,NSColor(hex:0x2B353B)) }
        vmRounded(NSRect(x:52,y:-62,width:10,height:3.2),radius:1.4,colors:[NSColor(hex:0xE3E7E0),NSColor(hex:0x667880)])
        // Saddle: bucket seat with a passenger pad behind.
        vmSeat(rig:rig,kind:.cruiser,length:18)
        vmFill(vmSpline([(-14,36),(-8,40),(8,42),(14,38),(6,35),(-8,34)]),colors:[NSColor(hex:0x6B4A33),NSColor(hex:0x2B1B10)],angle:85,outline:0.6)
        // Deep rear fender.
        let fender=vmSpline([(-24,12),(-20,28),(-4,36),(14,34),(24,24),(18,13),(6,24),(-8,25),(-16,15)])
        vmPanel(fender,body,gloss:0.4,outline:0.8)
        vmChrome(vmSpline([(-18,28),(-5,34),(12,32),(14,31),(-4,32),(-17,26)]),outline:0.4)
        // Leather saddlebag with straps and buckles.
        let bag=NSBezierPath(roundedRect:NSRect(x:-10,y:-40,width:34,height:19),xRadius:6,yRadius:6)
        vmFill(bag,colors:[NSColor(hex:0x946543),NSColor(hex:0x432A18)],angle:80,outline:0.7)
        for x in [-2.0,16.0] { line(x,-40,x,-22,0.7,NSColor(hex:0xCCA574,alpha:0.75)); vmRounded(NSRect(x:x-2.2,y:-34,width:4.4,height:4),radius:1,colors:[NSColor(hex:0xE0D2AC),NSColor(hex:0x8E7B55)]) }
        for i in 0..<8 { circle(-9+Double(i)*4.3,-23.2,0.5,NSColor(hex:0xE2C698)) }
        // Backrest and chrome sissy bar, tail light.
        vmMetalLink(vmQ(-8,40),vmQ(-12,64),width:1.7,dark:false); vmMetalLink(vmQ(2,40),vmQ(-5,58),width:1.4,dark:false)
        vmFill(NSBezierPath(roundedRect:NSRect(x:-19,y:-72,width:13,height:8),xRadius:3,yRadius:3),colors:[NSColor(hex:0x80593C),NSColor(hex:0x2E1C0F)],angle:80,outline:0.6)
        vmTailLight(-24,18,w:5,h:3); vmIndicator(-21,14)
        // Chrome headlight nacelle, tall pullback bars, speedo pod, passing lamps.
        vmMetalLink(vmQ(84,58),vmQ(94,54),width:2.4,dark:false)
        vmRoundLamp(vmQ(97,55),r:6.8)
        vmChrome(NSBezierPath(roundedRect:NSRect(x:76,y:-72,width:11,height:7),xRadius:3,yRadius:3))
        circle(81.5,-68.5,2.4,NSColor(hex:0xEFEAD2))
        for y in [-48.0,-42.0] { vmFill(NSBezierPath(ovalIn:NSRect(x:94,y:y-2.8,width:5.6,height:5.6)),colors:[NSColor(hex:0xFFF7D2),NSColor(hex:0x9F9265)],outline:0.4) }
        // Running boards via a pair of long chrome footboards.
        vmMetalLink(vmQ(52,10),vmQ(72,10),width:3.4,dark:false)
    }

    // MARK: Enduro 250
    func vmEnduroBody(rig:VehicleRig) {
        // Radiator shrouds sweeping from the seat to the front number plate, air-box side panel, long flat seat and fender.
        let shroud=vmSpline([(38,56),(48,67),(66,72),(82,66),(78,52),(68,38),(54,33),(44,40)])
        vmPanel(shroud,body,gloss:0.4)
        vmClip(shroud) { line(50,-66,76,-58,3,vmTone(body,-0.45)); line(46,-50,70,-44,0.9,NSColor.white.withAlphaComponent(0.5)) }
        let panel=vmSpline([(48,52),(58,60),(68,57),(72,46),(66,38),(54,40)])
        vmFill(panel,colors:[NSColor(hex:0xFAFAEE),NSColor(hex:0xBFC8C2)],angle:70,outline:0.4)
        text("07",60,-53,8.5,NSColor(hex:0x31444B),.heavy,center:true)
        // Rear subframe cover and tail.
        let tail=vmSpline([(-18,55),(-4,62),(20,62),(38,57),(26,49),(8,46),(-12,48)])
        vmPanel(tail,body,gloss:0.32)
        vmSeat(rig:rig,kind:.motocross,length:22)
        let airbox=vmSpline([(12,41),(14,49),(26,50),(33,44),(27,40)])
        vmFill(airbox,colors:[vmTone(body,-0.35),vmTone(body,-0.62)],angle:60,outline:0.6)
        for i in 0..<2 { line(17,-(43+Double(i)*3),28,-(42+Double(i)*3),0.5,vmTone(body,0.15)) }
        // Rear mudguard, tail light and plate hanger.
        vmPanel(vmSpline([(-26,34),(-18,46),(-8,50),(-12,44),(-18,36)]),body,gloss:0.2,outline:0.6)
        vmTailLight(-20,47,w:4,h:2.6)
        // Front number plate (the "tombstone") and headlight mask.
        let plate=vmSpline([(88,86),(100,84),(98,64),(86,62),(84,74)])
        vmFill(plate,colors:[NSColor(hex:0xFFFFEF),NSColor(hex:0xB3C1BB)],angle:65,outline:0.7)
        text("07",92,-79,7,NSColor(hex:0x2C4648),.heavy,center:true)
        vmBolt(90,-83,r:0.8); vmBolt(92,-65,r:0.8)
        // Skid plate and a rear brake pedal.
        vmFill(vmRoundedPoly([(34,8),(36,5),(60,5),(62,8),(58,10),(38,10)],radius:1.2),colors:[NSColor(hex:0xB5BCBD),NSColor(hex:0x58666D)],angle:80,outline:0.6); vmBolt(40,-7.5,r:0.8); vmBolt(56,-7.5,r:0.8)
        vmMetalLink(vmQ(46,10),vmQ(26,16),width:1.6,dark:true)
    }

    // MARK: Sport 600
    func vmSportBody(rig:VehicleRig) {
        // Pointed tail, sharp tank, half-fairing nose with twin lamps and a belly pan that leaves the engine visible.
        let tail=vmRoundedPoly([(-4,43),(-2,50),(22,58),(44,52),(44,44),(18,40)],radius:3)
        vmPanel(tail,body,gloss:0.5)
        vmClip(tail) { line(0,-48,38,-52,1.2,NSColor.white.withAlphaComponent(0.75)); line(14,-42,40,-47,2.6,vmTone(body,-0.45)) }
        vmSeat(rig:rig,kind:.sport,length:12)
        let tank=vmRoundedPoly([(32,46),(36,58),(56,67),(76,62),(86,56),(72,44),(48,42)],radius:5)
        vmPanel(tank,body,gloss:0.55)
        vmClip(tank) { line(40,-59,74,-60,3.4,vmTone(body,-0.5)); line(36,-56,66,-64,0.9,NSColor.white.withAlphaComponent(0.55)) }
        vmKneeGrip([(44,46),(44,55),(56,57),(58,47)])
        // Belly pan first, then the fairing nose over it.
        let belly=vmRoundedPoly([(50,32),(88,38),(102,30),(96,16),(84,3),(58,0),(47,9)],radius:3)
        vmPanel(belly,body,gloss:0.4)
        vmClip(belly) { line(52,-26,98,-30,3.0,vmTone(body,-0.45)); line(50,-20,96,-22,0.8,NSColor.white.withAlphaComponent(0.7)) }
        let outlet=vmPoly([(66,22),(86,26),(88,20),(72,15)])
        vmFill(outlet,colors:[NSColor(hex:0x152028),NSColor(hex:0x4A5E69)],angle:80,outline:0.4)
        for i in 0..<3 { line(70+Double(i)*5,-(17+Double(i)*1.2),72+Double(i)*5,-(22+Double(i)*1.2),0.6,NSColor(hex:0x93A8B0)) }
        let nose=vmRoundedPoly([(64,50),(80,67),(100,65),(114,55),(106,43),(92,40),(74,40)],radius:3.2)
        vmPanel(nose,body,gloss:0.6)
        vmClip(nose) { line(70,-56,108,-52,2.4,vmTone(body,-0.45)) }
        // Angular twin projector lamps, an air scoop, indicator and the screen.
        let lamp=vmRoundedPoly([(96,56),(108,54),(110,48),(98,47)],radius:1.6)
        vmFill(lamp,colors:[NSColor(hex:0x253A47),NSColor(hex:0x0B151C)],angle:70,outline:0.6)
        circle(101.5,-51.5,2.3,NSColor(hex:0xF4F8F2)); circle(106,-50.6,1.5,NSColor(hex:0xF4F8F2,alpha:0.85))
        let scoop=vmPoly([(88,50),(94,46),(94,43),(88,45)]); vmFill(scoop,colors:[NSColor(hex:0x0F171C),NSColor(hex:0x3C4A52)],outline:0.4)
        vmIndicator(106,44)
        vmWindscreen([(78,66),(82,80),(98,72),(94,65)])
        vmMetalLink(vmQ(88,64),vmQ(84,72),width:1.1,dark:true)
        vmTailLight(-6,44,w:7,h:2.6); vmPlate(-11,40,w:8,h:5,text:"7",size:3.6)
        vmBolt(59,-9,r:1);vmBolt(95,-30,r:0.9)
    }

    // MARK: Hyper R 1000
    func vmHyperBody(rig:VehicleRig) {
        // Angular superbike: pointed tail, sharp tank, full fairing with winglets and an LED lamp.
        let tail=vmPoly([(-2,49),(18,58),(44,52),(30,43),(6,43)])
        vmPanel(tail,body,gloss:0.5)
        vmClip(tail) { line(2,-50,38,-54,1.4,NSColor.white.withAlphaComponent(0.7)) }
        vmSeat(rig:rig,kind:.hyperbike,length:11)
        let tank=vmSpline([(32,50),(40,62),(58,69),(78,63),(84,57),(68,44),(48,44)])
        vmPanel(tank,body,gloss:0.6)
        vmClip(tank) { line(42,-61,76,-62,3.2,vmTone(body,-0.55)); line(38,-57,70,-66,0.8,NSColor.white.withAlphaComponent(0.55)) }
        vmKneeGrip([(46,48),(46,58),(60,60),(62,50)])
        let fairing=vmPoly([(55,47),(81,69),(104,60),(116,50),(100,38),(92,20),(79,2),(44,0),(48,20)])
        vmPanel(fairing,body,gloss:0.5,outline:0.9)
        // Dark intake duct and inner cowl, a panel with louvres, and the side winglet.
        let duct=vmPoly([(52,35),(90,54),(104,52),(80,34),(72,9),(49,6)])
        vmFill(duct,colors:[NSColor(hex:0x24384A),NSColor(hex:0x0D161D)],angle:70,outline:0.5)
        vmClip(duct) { for i in 0..<5 { line(54+Double(i)*5,-(8+Double(i)*3.2),90-Double(i)*2,-(36+Double(i)*2),0.5,NSColor(hex:0x6C8798,alpha:0.7)) } }
        vmFill(vmPoly([(55,30),(83,43),(79,35),(58,22)]),colors:[NSColor(hex:0xE2EAEA),NSColor(hex:0x9AA9AB)],angle:90,outline:0.4)
        let wing=vmPoly([(82,46),(106,43),(100,38),(78,41)])
        vmFill(wing,colors:[NSColor(hex:0x20323E),NSColor(hex:0x0E1820)],angle:80,outline:0.6)
        line(85,-44,102,-42,0.6,NSColor(hex:0xA2BAC2))
        // LED headlamp with a DRL strip, tall screen and mirrors.
        vmFill(vmPoly([(97,57),(112,53),(110,47),(96,50)]),colors:[NSColor(hex:0x2B4558),NSColor(hex:0x0A141B)],angle:60,outline:0.6)
        line(99,-53.5,110,-51,1.0,NSColor(hex:0xF0FFFF)); circle(105,-51,1.6,NSColor(hex:0xFFFFFF))
        vmWindscreen([(80,66),(85,80),(104,64),(98,60)])
        vmMetalLink(vmQ(90,66),vmQ(86,74),width:1.1,dark:true)
        text("R",69,-44,11,NSColor(hex:0xF2F0DF),.heavy,center:true)
        text("1000",63,-12,4.8,NSColor(hex:0xD8E4E6),.bold,center:true)
        vmTailLight(-3,48,w:8,h:2.4); vmPlate(-9,43,w:8,h:5,text:"R",size:3.6)
        vmBolt(48,-9,r:0.9);vmBolt(96,-46,r:0.9)
    }

    // MARK: Scooter 80
    func vmScooterBody(rig:VehicleRig) {
        // Step-through shell: leg shield, floor, rear cowl over the CVT, and a handlebar cowl with a round lamp.
        let shell=vmSpline([(-10,16),(-8,32),(6,42),(24,45),(36,42),(42,24),(46,12),(66,10),(70,26),(70,50),(78,60),(88,60),(94,46),(94,24),(86,6),(70,0),(40,0),(14,2)])
        vmPanel(shell,body,gloss:0.5,outline:0.85)
        // Floorboard with a rubber mat and rib lines.
        vmFill(vmSpline([(42,14),(44,10),(66,9),(68,13),(56,15)]),colors:[NSColor(hex:0x4C555B),NSColor(hex:0x151C21)],angle:80,outline:0.5)
        for i in 0..<6 { line(46+Double(i)*3.6,-13,46+Double(i)*3.6,-10,0.5,NSColor(hex:0x7C8A92)) }
        // Belt drive cover with cooling louvres and the muffler pod.
        let cvt=vmSpline([(0,22),(2,34),(18,36),(32,30),(30,16),(14,10)])
        vmFill(cvt,colors:[NSColor(hex:0xA9B4B6),NSColor(hex:0x4A5961)],angle:70,outline:0.7)
        for i in 0..<5 { line(8,-(14+Double(i)*3.6),24,-(16+Double(i)*3.4),0.7,NSColor(hex:0x2B363D)) }
        let pod=vmSpline([(-12,14),(-10,22),(8,25),(22,22),(22,14),(6,10)]); vmChrome(pod); line(-6,-20,18,-21,0.6,NSColor.white)
        vmSeat(rig:rig,kind:.scooter,length:17)
        // Rear cowl accent and tail lamp.
        let cowl=vmSpline([(-12,34),(-6,44),(8,47),(20,45),(14,40),(2,40)]); vmPanel(cowl,vmTone(body,-0.12),gloss:0.3,outline:0.6)
        vmTailLight(-14,42,w:5,h:3); vmIndicator(-13,34)
        text("80",82,-37,4.6,vmTone(body,-0.65),.semibold,center:true)
        // Front cowl: apron, mirrors-style pods, round headlamp and a dashboard.
        let hood=vmSpline([(72,62),(80,70),(92,68),(94,56),(84,52)])
        vmPanel(hood,vmTone(body,-0.06),gloss:0.4,outline:0.7)
        vmRoundLamp(vmQ(91,62),r:4.4,chrome:false)
        vmFill(NSBezierPath(roundedRect:NSRect(x:72,y:-72,width:10,height:5),xRadius:2,yRadius:2),colors:[NSColor(hex:0x4E5A62),NSColor(hex:0x151C21)],angle:60,outline:0.5)
        vmIndicator(84,52)
        line(80,-52,84,-24,1.1,NSColor.white.withAlphaComponent(0.35))
        vmMetalLink(vmQ(10,6),vmQ(60,3),width:2.4,dark:true)   // side stand rail
    }

    // MARK: Scrambler 400
    func vmScramblerBody(rig:VehicleRig) {
        // Retro round-tank scrambler: bubble tank with a rubber knee pad, flat ribbed saddle, round lamp and high pipe.
        let tank=vmSpline([(31,47),(33,56),(45,63),(62,64),(77,58),(80,50),(68,44),(48,42),(36,43)])
        vmPanel(tank,body,gloss:0.55)
        vmClip(tank) {
            line(36,-52,72,-54,3.4,vmTone(body,-0.52)); line(38,-47,70,-49,0.7,NSColor(hex:0xF1F0DD))
            line(42,-60,66,-62,0.9,NSColor.white.withAlphaComponent(0.55))
        }
        vmKneeGrip([(48,43),(48,52),(60,52),(62,44)])
        vmRounded(NSRect(x:56,y:-67,width:9,height:3.2),radius:1.4,colors:[NSColor(hex:0xE3E7E0),NSColor(hex:0x667880)])
        // Side panel with the badge and an air filter canister.
        vmFill(vmSpline([(6,28),(8,40),(24,43),(34,38),(32,26),(18,22)]),colors:[NSColor(hex:0xDAD6C2),NSColor(hex:0x8F9A90)],angle:80,outline:0.6)
        text("400",19,-35,5.5,NSColor(hex:0x34423C),.bold,center:true)
        // Flat ribbed saddle.
        vmFill(vmSpline([(-10,47),(0,52),(30,52),(46,50),(46,45),(20,43),(-8,43)]),colors:[NSColor(hex:0x9A7C5C),NSColor(hex:0x40372B)],angle:85,outline:0.7)
        for i in 0..<10 { line(-6+Double(i)*5,-50.5,-5+Double(i)*5,-44.5,0.55,NSColor(hex:0xBFA27A,alpha:0.6)) }
        // Short fenders, tail lamp, number board and a rack.
        vmPanel(vmSpline([(-24,26),(-18,36),(-4,38),(-10,31),(-18,28)]),body,gloss:0.3,outline:0.6)
        vmTailLight(-22,40,w:4.5,h:2.8); vmIndicator(-17,29)
        vmFill(vmSpline([(8,38),(10,46),(20,46),(22,38)]),colors:[NSColor(hex:0xFAF6E2),NSColor(hex:0xBFC4B0)],angle:80,outline:0.5)
        text("7",15,-43,5.5,NSColor(hex:0x2C4648),.heavy,center:true)
        // Round LED headlight, braced bars and a small round clock.
        vmMetalLink(vmQ(84,64),vmQ(93,62),width:2.2,dark:true)
        vmRoundLamp(vmQ(97,63),r:6.4)
        vmFill(NSBezierPath(ovalIn:NSRect(x:72,y:-77,width:8,height:8)),colors:[NSColor(hex:0x4E5A62),NSColor(hex:0x151C21)],angle:60,outline:0.5)
        circle(76,-73,2.6,NSColor(hex:0xF1EEDA))
        // Bash plate.
        vmMetalLink(vmQ(30,2),vmQ(62,2),width:3.2,dark:false)
    }

    // MARK: Trial 200
    func vmTrialsBody(rig:VehicleRig,tank showTank:Bool=true) {
        // Skeletal: a tiny tank/seat spine, a high front mudguard, a number plate and exposed frame.
        if showTank {
            let tank=vmSpline([(20,48),(30,60),(54,64),(72,60),(70,53),(50,50),(26,45)])
            vmPanel(tank,body,gloss:0.5)
            vmClip(tank) { line(26,-52,66,-58,2.4,vmTone(body,-0.5)) }
        }
        vmFill(vmSpline([(8,46),(10,52),(30,52),(38,48),(26,44)]),colors:[NSColor(hex:0x4E5B60),NSColor(hex:0x1D2D34)],angle:80,outline:0.6)
        let tail=vmPoly([(-14,46),(14,49),(24,45),(-10,41)]); vmPanel(tail,body,gloss:0.3,outline:0.65)
        vmTailLight(-15,46,w:4,h:2.6)
        // Radiator, plastic side panels and a skid plate.
        vmRadiator(rect:NSRect(x:56,y:-52,width:6,height:20),angle:-12,about:NSPoint(x:59,y:-42),hoses:false)
        let plate=vmSpline([(86,82),(98,80),(98,62),(85,64)])
        vmFill(plate,colors:[NSColor(hex:0xF7F3DA),NSColor(hex:0xBCC8BC)],angle:80,outline:0.7)
        text("2",91.5,-77,8,NSColor(hex:0x2C4648),.bold,center:true)
        vmFill(vmRoundedPoly([(32,8),(34,5),(58,5),(60,8),(56,10),(36,10)],radius:1.2),colors:[NSColor(hex:0xB5BCBD),NSColor(hex:0x58666D)],angle:80,outline:0.6)
        vmMetalLink(vmQ(6,24),vmQ(26,22),width:5,dark:true)
    }

    // MARK: Volt E-8
    func vmElectricBody(rig:VehicleRig) {
        // Minimal frame, a battery pack with cooling fins and a mid-drive motor.
        vmTrialsBody(rig:rig,tank:false)
        // A slim body-coloured beam over the pack instead of a fuel tank.
        vmPanel(vmRoundedPoly([(24,50),(34,56),(68,60),(76,56),(64,50),(36,46)],radius:2.5),body,gloss:0.5,outline:0.7)
        let pack=vmSpline([(33,36),(33,44),(66,46),(68,36),(66,14),(34,12)])
        vmFill(pack,colors:[NSColor(hex:0x56626C),NSColor(hex:0x1A2229),NSColor(hex:0x384450)],angle:80,outline:0.8)
        vmClip(pack) {
            for i in 0..<6 { line(37+Double(i)*5.6,-14,37+Double(i)*5.6,-44,0.8,NSColor(hex:0x0E1418,alpha:0.7)); line(38+Double(i)*5.6,-14,38+Double(i)*5.6,-44,0.4,NSColor(hex:0x6B7B86,alpha:0.7)) }
            for i in 0..<5 { vmRounded(NSRect(x:37+Double(i)*6,y:-42,width:4.5,height:2),radius:0.7,colors:[NSColor(hex:0x7FF29B),NSColor(hex:0x2E9E52)]) }
        }
        text("E",58,-31,8,NSColor(hex:0x6FE08A),.heavy,center:true)
        // Mid motor with orange phase cables and a controller box.
        vmClutchCover(vmQ(40,12),r:8.4)
        let cable=NSBezierPath(); cable.move(to:vmQ(40,20)); cable.curve(to:vmQ(34,36),controlPoint1:vmQ(28,22),controlPoint2:vmQ(26,32)); cable.lineWidth=2.4; NSColor(hex:0x151C21).setStroke(); cable.stroke(); cable.lineWidth=1.0; NSColor(hex:0xFF9A3C).setStroke(); cable.stroke()
        vmRounded(NSRect(x:18,y:-36,width:11,height:9),radius:2,colors:[NSColor(hex:0x4B5760),NSColor(hex:0x1A2229)])
        vmRoundLamp(vmQ(93,62),r:4.6,chrome:false)
        vmMetalLink(vmQ(12,10),vmQ(36,16),width:3.2,dark:true)
    }
}
