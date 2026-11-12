import Cocoa

@main struct MakeIcon {
    static func main() throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let folder=CommandLine.arguments.count>1 ? CommandLine.arguments[1] : "build/AppIcon.iconset"
        try FileManager.default.createDirectory(atPath:folder,withIntermediateDirectories:true)
        let master=NSImage(size:NSSize(width:1024,height:1024));master.lockFocusFlipped(true)
        let plate=NSBezierPath(roundedRect:NSRect(x:26,y:26,width:972,height:972),xRadius:214,yRadius:214)
        NSGradient(colors:[NSColor(hex:0x38546C),NSColor(hex:0x172A40),NSColor(hex:0x101C2D)])?.draw(in:plate,angle:90)
        NSGraphicsContext.saveGraphicsState();plate.addClip()
        let art=RideRenderer();art.body=NSColor(hex:0xEF9E35);art.jacket=NSColor(hex:0xDDE4E8);art.helmet=NSColor(hex:0xE8EDF0)
        for i in stride(from:12,through:1,by:-1) { let f=Double(i)/12;art.ellipse(185+(1-f)*190,175+(1-f)*190,650*f,650*f,NSColor(hex:0xAAC4CD,alpha:0.012)) }
        art.shadow(x:510,y:847,width:640,height:40,alpha:0.4)
        art.motorcycle(x:280,y:746,scale:4.2,angle:0.47,kind:.commuter,rotation:0,time:0,lean:-0.15)
        art.line(194,891,814,891,3,NSColor(hex:0x738A9B,alpha:0.5))
        NSGraphicsContext.restoreGraphicsState()
        NSColor.white.withAlphaComponent(0.11).setStroke();plate.lineWidth=2;plate.stroke()
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
