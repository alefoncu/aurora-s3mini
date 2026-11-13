import Cocoa

/// Generates the macOS app icon: a sunset scene with the sport bike in a wheelie, drawn with the game's own
/// vehicle and rider artwork. The plate follows the macOS icon grid (824 pt squircle inside a 1024 pt canvas).
@main struct MakeIcon {
    static func main() throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let folder=CommandLine.arguments.count>1 ? CommandLine.arguments[1] : "build/AppIcon.iconset"
        try FileManager.default.createDirectory(atPath:folder,withIntermediateDirectories:true)
        let master=NSImage(size:NSSize(width:1024,height:1024));master.lockFocusFlipped(true)
        let plateRect=NSRect(x:100,y:100,width:824,height:824)
        let plate=NSBezierPath(roundedRect:plateRect,xRadius:186,yRadius:186)
        // Soft drop shadow under the plate.
        NSGraphicsContext.saveGraphicsState()
        let shadow=NSShadow();shadow.shadowColor=NSColor.black.withAlphaComponent(0.5);shadow.shadowBlurRadius=30;shadow.shadowOffset=NSSize(width:0,height:-16)
        shadow.set();NSColor.black.setFill();plate.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSGraphicsContext.saveGraphicsState();plate.addClip()
        // Sky: deep indigo to violet, hot magenta, orange and gold at the horizon.
        NSGradient(colors:[NSColor(hex:0x150F3F),NSColor(hex:0x3C1B73),NSColor(hex:0xB93A78),NSColor(hex:0xFF7A45),NSColor(hex:0xFFC35C)],atLocations:[0,0.26,0.52,0.74,0.92],colorSpace:.deviceRGB)?.draw(in:plateRect,angle:90)
        // A few stars in the upper sky.
        for (x,y,r,a) in [(250.0,190.0,2.4,0.9),(420,160,1.8,0.7),(610,215,2.2,0.8),(760,175,1.9,0.7),(330,262,1.5,0.55),(700,285,1.6,0.5),(180,300,1.4,0.5),(860,260,2.0,0.7)] as [(Double,Double,Double,Double)] {
            NSColor.white.withAlphaComponent(a).setFill();NSBezierPath(ovalIn:NSRect(x:x-r,y:y-r,width:r*2,height:r*2)).fill()
        }
        let horizon:Double=712,sun=NSPoint(x:700,y:horizon)
        // Glow and the half sun with retro slits.
        NSGradient(colors:[NSColor(hex:0xFFE9A0,alpha:0.75),NSColor(hex:0xFF8A4A,alpha:0.28),NSColor(hex:0xFF5A55,alpha:0)],atLocations:[0,0.45,1],colorSpace:.deviceRGB)?.draw(fromCenter:sun,radius:0,toCenter:sun,radius:470,options:[])
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect:NSRect(x:0,y:0,width:1024,height:horizon)).addClip()
        let disc=NSBezierPath(ovalIn:NSRect(x:sun.x-225,y:sun.y-225,width:450,height:450))
        NSGradient(colors:[NSColor(hex:0xFFF0A8),NSColor(hex:0xFFB347),NSColor(hex:0xFF5E6C)],atLocations:[0,0.55,1],colorSpace:.deviceRGB)?.draw(in:disc,angle:90)
        NSGraphicsContext.saveGraphicsState(); disc.addClip()
        for i in 0..<6 { let y=horizon-150+Double(i)*26;let h=3.0+Double(i)*2.6; NSColor(hex:0xB93A78,alpha:0.85).setFill();NSBezierPath(rect:NSRect(x:sun.x-235,y:y,width:470,height:h)).fill() }
        NSGraphicsContext.restoreGraphicsState()
        NSGraphicsContext.restoreGraphicsState()
        // Two layers of distant ridges.
        func ridge(_ pts:[(Double,Double)],_ color:NSColor) {
            let p=NSBezierPath();p.move(to:NSPoint(x:60,y:horizon+60))
            for q in pts { p.line(to:NSPoint(x:q.0,y:q.1)) }
            p.line(to:NSPoint(x:960,y:horizon+60));p.close();color.setFill();p.fill()
        }
        ridge([(60,640),(150,600),(230,640),(330,570),(430,628),(520,596),(620,650),(740,590),(850,640),(960,610)],NSColor(hex:0x4A2263))
        ridge([(60,690),(170,654),(290,690),(400,662),(540,700),(660,672),(780,704),(900,676),(960,694)],NSColor(hex:0x2A1442))
        // Road: warm verge, dark asphalt with a bright edge and big dashes.
        NSGradient(colors:[NSColor(hex:0x3A1D4A),NSColor(hex:0x1C1030)],atLocations:[0,1],colorSpace:.deviceRGB)?.draw(in:NSRect(x:0,y:horizon,width:1024,height:230),angle:90)
        NSColor(hex:0xFFB36B,alpha:0.9).setFill();NSBezierPath(rect:NSRect(x:0,y:horizon+36,width:1024,height:6)).fill()
        NSColor(hex:0xFF6A8A,alpha:0.35).setFill();NSBezierPath(rect:NSRect(x:0,y:horizon+42,width:1024,height:18)).fill()
        for i in 0..<4 { NSColor(hex:0xFFE9B8,alpha:0.85).setFill();NSBezierPath(roundedRect:NSRect(x:175+Double(i)*190,y:872,width:115,height:12),xRadius:6,yRadius:6).fill() }

        // The bike: sport model in a wheelie, rotated about its rear axle so the rear tyre stays on the road.
        let art=RideRenderer();art.body=NSColor(hex:0x12C8E8);art.jacket=NSColor(hex:0xF2F4F6);art.helmet=NSColor(hex:0xFFFFFF);art.livery = .none
        let scale=4.05,rig=BikeKind.sport.rig,contact:Double=834
        let axleY=contact-rig.wheelRadius*rig.drawingUnitsPerMetre*scale
        art.shadow(x:410,y:contact+6,width:460,height:30,alpha:0.5)
        // Speed streaks and dust behind the rear wheel.
        for (i,(y,len)) in [(contact-55,170.0),(contact-95,230.0),(contact-135,130.0)].enumerated() {
            let g=NSGradient(colors:[NSColor.white.withAlphaComponent(0),NSColor.white.withAlphaComponent(0.55)])
            g?.draw(in:NSRect(x:215-len,y:y-2+Double(i),width:len,height:5),angle:0)
        }
        for (dx,dy,r,a) in [(-32.0,-12.0,15.0,0.30),(-64,-22,20,0.22),(-96,-28,24,0.15),(-14,-28,10,0.28)] as [(Double,Double,Double,Double)] {
            NSColor(hex:0xFFD9B0,alpha:a).setFill();NSBezierPath(ovalIn:NSRect(x:268+dx-r,y:contact+dy-r,width:r*2,height:r*2)).fill()
        }
        art.motorcycle(x:300,y:axleY,scale:scale,angle:0.44,kind:.sport,rotation:0.6,time:0,lean:-0.1,riderLift:0.4)
        NSGraphicsContext.restoreGraphicsState()

        // Glassy sheen and a fine rim.
        NSGraphicsContext.saveGraphicsState();plate.addClip()
        NSGradient(colors:[NSColor.white.withAlphaComponent(0.10),NSColor.white.withAlphaComponent(0)])?.draw(in:NSRect(x:100,y:100,width:824,height:300),angle:90)
        NSGraphicsContext.restoreGraphicsState()
        NSColor.white.withAlphaComponent(0.2).setStroke();let inner=NSBezierPath(roundedRect:plateRect.insetBy(dx:1.5,dy:1.5),xRadius:185,yRadius:185);inner.lineWidth=3;inner.stroke()
        master.unlockFocus()

        let names:[Int:[String]]=[16:["icon_16x16"],32:["icon_16x16@2x","icon_32x32"],64:["icon_32x32@2x"],128:["icon_128x128"],256:["icon_128x128@2x","icon_256x256"],512:["icon_256x256@2x","icon_512x512"],1024:["icon_512x512@2x"]]
        for size in [16,32,64,128,256,512,1024] {
            let image=NSImage(size:NSSize(width:size,height:size));image.lockFocusFlipped(true)
            master.draw(in:NSRect(x:0,y:0,width:size,height:size),from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:[.interpolation:NSImageInterpolation.high]);image.unlockFocus()
            let rep=NSBitmapImageRep(data:image.tiffRepresentation!)!,png=rep.representation(using:.png,properties:[:])!
            for name in names[size]! { try png.write(to:URL(fileURLWithPath:folder+"/"+name+".png")) }
        }
    }
}
