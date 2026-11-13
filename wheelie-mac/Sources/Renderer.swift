import Cocoa

extension NSColor {
    convenience init(hex: Int, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: alpha)
    }
}

/// Side-view art is procedural so wheels, suspension and the rider can articulate.
final class RideRenderer {
    var metresToPixels=RideScene.metresToPixels
    let ink = NSColor(hex: 0x172027)
    let silver = NSColor(hex: 0xBAC2C6)
    var body = NSColor(hex: 0xE9AD27), jacket = NSColor(hex: 0x2164A7), helmet = NSColor(hex: 0xE6E9EC)
    var skin = NSColor(hex: 0xDDA480)
    var helmetOn = true, passenger = false
    var helmetStyle = HelmetStyle.standard, jacketStyle = JacketStyle.standard, livery = Livery.none
    var raceNumber = 7
    /// 0...0.85: how much the wheels blur at speed (set per vehicle before drawing it); spokes fade into a translucent disc.
    var wheelBlur = 0.0
    func blur(speed:Double,radius:Double)->Double { max(0,min(0.85,(speed/max(0.2,radius)-16)/34)) }
    /// Logical scene layout, set by the view each frame: the bike's screen x, the ground line and the scene size.
    var focusX = 370.0, groundY = 458.0, viewWidth = 1280.0, viewHeight = 720.0
    var landscape: NSImage?, desert: NSImage?
    var asphaltTexture: NSImage?, dirtTexture: NSImage?
    private var treeTextures:[Int:NSImage]=[:]
    private var textureCG:[String:CGImage]=[:]
    /// Draw a cached backdrop through Core Graphics directly: no colour or resampling work, a plain copy.
    private func blit(_ cg:CGImage,_ rect:NSRect,flipX:Bool=false,quality:CGInterpolationQuality = .none) {
        guard let ctx=NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState(); ctx.interpolationQuality = quality
        // The view is flipped (y down): flip the image back upright, and mirror it when asked.
        ctx.translateBy(x:flipX ? rect.maxX : rect.minX,y:rect.maxY); ctx.scaleBy(x:flipX ? -1 : 1,y:-1)
        ctx.draw(cg,in:CGRect(x:0,y:0,width:rect.width,height:rect.height))
        ctx.restoreGState()
    }
    init() {
        if let url = Bundle.main.url(forResource: "valley", withExtension: "png") { landscape = NSImage(contentsOf: url) }
        if let url = Bundle.main.url(forResource: "dunes", withExtension: "png") { desert = NSImage(contentsOf: url) }
        asphaltTexture = texture(dirt: false); dirtTexture = texture(dirt: true)
    }
    func box(_ x: Double,_ y: Double,_ w: Double,_ h: Double,_ c: NSColor,_ r: Double = 0) {
        c.setFill(); NSBezierPath(roundedRect: NSRect(x:x,y:y,width:w,height:h),xRadius:r,yRadius:r).fill()
    }
    func ellipse(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ c:NSColor) { c.setFill(); NSBezierPath(ovalIn:NSRect(x:x,y:y,width:w,height:h)).fill() }
    func circle(_ x:Double,_ y:Double,_ r:Double,_ c:NSColor) { ellipse(x-r,y-r,2*r,2*r,c) }
    func line(_ x:Double,_ y:Double,_ xx:Double,_ yy:Double,_ w:Double,_ c:NSColor) {
        let p = NSBezierPath(); p.move(to: NSPoint(x:x,y:y)); p.line(to:NSPoint(x:xx,y:yy)); p.lineWidth=w; p.lineCapStyle = .round; c.setStroke(); p.stroke()
    }
    func path(_ pts:[NSPoint],_ c:NSColor,stroke:NSColor?=nil,width:Double=1) {
        guard let f=pts.first else { return }; let p=NSBezierPath(); p.move(to:f); for pt in pts.dropFirst() { p.line(to:pt) }; p.close(); c.setFill(); p.fill(); if let s=stroke { s.setStroke(); p.lineWidth=width; p.lineJoinStyle = .round; p.stroke() }
    }
    func poly(_ pts:[(Double,Double)],_ c:NSColor,stroke:NSColor?=nil,width:Double=1) { path(pts.map{NSPoint(x:$0.0,y:$0.1)},c,stroke:stroke,width:width) }
    func tube(_ a:NSPoint,_ b:NSPoint,_ w:Double,_ c:NSColor) {
        line(a.x,a.y,b.x,b.y,w+2,ink); line(a.x,a.y,b.x,b.y,w,c)
        line(a.x-0.5,a.y-1,b.x-0.5,b.y-1,max(1,w*0.18),NSColor.white.withAlphaComponent(0.18))
    }
    func text(_ s:String,_ x:Double,_ y:Double,_ size:Double,_ color:NSColor = .white,_ weight:NSFont.Weight = .regular,center:Bool=false,mono:Bool=false) {
        let font = mono ? NSFont.monospacedDigitSystemFont(ofSize:size,weight:weight) : NSFont.systemFont(ofSize:size,weight:weight)
        let attrs:[NSAttributedString.Key:Any] = [.font:font,.foregroundColor:color]
        let width=(s as NSString).size(withAttributes:attrs).width
        (s as NSString).draw(at:NSPoint(x:center ? x-width/2 : x,y:y),withAttributes:attrs)
    }
    /// Vertical gradients are rendered once into a thin strip and stretched across the rect: drawing
    /// an NSGradient evaluates a colour function per pixel, which dominated the frame cost.
    private var gradientStrips:[String:CGImage]=[:]
    private func colorKey(_ c:NSColor)->String {
        guard let v=c.usingColorSpace(.sRGB) else { return "?" }
        return String(format:"%.3f,%.3f,%.3f,%.3f",v.redComponent,v.greenComponent,v.blueComponent,v.alphaComponent)
    }
    func gradient(_ rect:NSRect,_ top:NSColor,_ bottom:NSColor) {
        guard rect.width>0,rect.height>=1 else { return }
        let height=max(1,Int(rect.height.rounded())),key="\(height)|"+colorKey(top)+"|"+colorKey(bottom)
        if gradientStrips[key]==nil {
            let strip=NSImage(size:NSSize(width:8,height:Double(height))); strip.lockFocusFlipped(true)
            NSGradient(starting:top,ending:bottom)?.draw(in:NSRect(x:0,y:0,width:8,height:Double(height)),angle:90)
            strip.unlockFocus()
            gradientStrips[key]=strip.cgImage(forProposedRect:nil,context:nil,hints:nil)
        }
        if let cg=gradientStrips[key] { blit(cg,NSRect(x:rect.minX,y:rect.minY,width:rect.width,height:Double(height))) }
    }
    func image(_ img:NSImage,_ rect:NSRect,alpha:Double=1) { img.draw(in:rect,from:.zero,operation:.sourceOver,fraction:alpha,respectFlipped:true,hints:[.interpolation:NSImageInterpolation.high]) }
    private func texture(dirt:Bool)->NSImage {
        let img=NSImage(size:NSSize(width:512,height:256)); img.lockFocusFlipped(true)
        box(0,0,512,256,NSColor(hex:dirt ? 0xB78957 : 0x656B6E))
        var seed:UInt64=982731
        func rand()->Double { seed = seed &* 6364136223846793005 &+ 1; return Double(seed>>33)/Double(UInt64(1)<<31) }
        for _ in 0..<14000 {
            let x=rand()*512,y=rand()*256,v=rand(),a=0.03+rand()*0.1
            ellipse(x,y,rand()*2.4+0.4,rand()*1.2+0.3,(v>0.5 ? NSColor.white : .black).withAlphaComponent(a))
        }
        if dirt { for _ in 0..<80 { let x=rand()*512,y=rand()*256; line(x,y,x+rand()*35+4,y-1,0.7,NSColor(hex:0xE5C898,alpha:0.2)) } }
        img.unlockFocus(); return img
    }
    func hash(_ n:Double)->Double { let v=sin(n*12.9898)*43758.5453; return v-floor(v) }
    /// One repeating strip of city buildings for a parallax layer (windows lit per building), baked once by the backdrop.
    func cityStrip(layer:Int,count:Int,width:Double,night:Bool) {
        for n in 0..<count {
            let h=hash(Double(n*7+layer*31)),x=Double(n)*width
            let height=130+h*210+Double(layer)*18,bw=width*(0.7+h*0.25),top=560-height+Double(layer)*34
            box(x,top,bw,620-top,NSColor(hex:[0x1F2636,0x2A3245,0x39425A][layer]))
            var wy=top+10
            while wy<540 {
                var wx=x+7
                while wx<x+bw-10 {
                    if hash(Double(n)*3.1+wx*0.07+wy*0.11)>0.55 { box(wx,wy,6,8,NSColor(hex:0xFFD58A,alpha:night ? 0.85 : 0.5)) }
                    wx+=14
                }
                wy+=18
            }
        }
    }
    /// Falling snow, in one path (the only animated part of the snow backdrop).
    func snowfall(route:Int,time:Double) {
        guard route==3 else { return }
        let flakes=NSBezierPath()
        for i in 0..<90 {
            let fall=40+Double(i%5)*14,sway=sin(time*0.8+Double(i))*14,r=1+Double(i%3)*0.7
            let x=(Double(i)*137.0+time*(8+Double(i%4)*5)+sway).truncatingRemainder(dividingBy:viewWidth+20)
            let y=(Double(i)*83.0+time*fall).truncatingRemainder(dividingBy:640)
            flakes.append(NSBezierPath(ovalIn:NSRect(x:x-r,y:y-r,width:2*r,height:2*r)))
        }
        NSColor.white.withAlphaComponent(0.8).setFill(); flakes.fill()
    }
    /// Falling rain over the whole scene, drawn on top of the ride.
    /// Falling rain; `intensity` 0...1 sets how many drops there are.
    func weather(intensity:Double,time:Double) {
        guard intensity.isFinite,intensity>0.02 else { return }
        let drops=NSBezierPath()
        for i in 0..<Int(150*min(1,intensity)) {
            let speed=620+Double(i%7)*60
            var x=(Double(i)*97.0-time*90).truncatingRemainder(dividingBy:1400)
            if x<0 { x+=1400 }
            let y=(Double(i)*53.0+time*speed).truncatingRemainder(dividingBy:780)-30
            drops.move(to:NSPoint(x:x,y:y)); drops.line(to:NSPoint(x:x-5,y:y+20))
        }
        drops.lineWidth=1; NSColor(hex:0xBFD4EA,alpha:0.30).setStroke(); drops.stroke()
    }
    func ground(_ meters:Double,at cameraX:Double,cameraY:Double,route:Int,lane:Int=0)->Double {
        groundY + cameraY - BikePhysics.ground(meters,route:route,lane:lane)*metresToPixels
    }
    /// The elevated road of every visible fork: a deck on pillars above the ground road, merging into it at both ends.
    func forkRoads(cameraX:Double,cameraY:Double,route:Int,night:Bool) {
        guard BikePhysics.forksEnabled else { return }
        let ppm=metresToPixels,left=cameraX-focusX/ppm-5,right=cameraX+(viewWidth-focusX)/ppm+5
        let k0=Int(floor(left/BikePhysics.forkSpacing))
        for slot in k0-1...k0+2 {
            guard let f=BikePhysics.fork(slot:slot),f.end>left && f.start<right else { continue }
            let from=max(f.start,left),to=min(f.end,right),step=2.0
            var top:[NSPoint]=[],bottom:[NSPoint]=[]
            var x=from
            while x<=to+step {
                let px=focusX+(x-cameraX)*ppm,gy=ground(x,at:cameraX,cameraY:cameraY,route:route,lane:1)
                top.append(NSPoint(x:px,y:gy-26)); bottom.append(NSPoint(x:px,y:gy+20)); x+=step
            }
            // Pillars from the deck down to the ground road.
            var p=ceil(from/30)*30
            while p<=to { 
                let px=focusX+(p-cameraX)*ppm,deck=ground(p,at:cameraX,cameraY:cameraY,route:route,lane:1)+20,base=ground(p,at:cameraX,cameraY:cameraY,route:route,lane:0)-26
                if deck<base-6 { line(px,deck,px,base,7,NSColor(hex:night ? 0x2A323A : 0x7F8A90)); line(px-1.5,deck,px-1.5,base,1.5,NSColor.white.withAlphaComponent(0.25)) }
                p+=30
            }
            path(top+bottom.reversed(),NSColor(hex:night ? 0x23282E : 0x4B5258),stroke:ink,width:1.2)
            // The deck's lit surface, a dashed centre line and a rail along the front edge.
            path(top+top.reversed().map { NSPoint(x:$0.x,y:$0.y+9) },NSColor(hex:night ? 0x39414B : 0x6A737A))
            for i in stride(from:0,to:max(0,top.count-1),by:3) { let a=top[i],b=top[min(top.count-1,i+1)]; line(a.x,a.y+4.5,b.x,b.y+4.5,2,NSColor(hex:0xE9E2C6,alpha:0.8)) }
            for p in stride(from:ceil(from/12)*12,through:to,by:12) {
                let px=focusX+(p-cameraX)*ppm,gy=ground(p,at:cameraX,cameraY:cameraY,route:route,lane:1)
                line(px,gy+18,px,gy+4,2.2,NSColor(hex:0xC9D0D4))
            }
            let rail=bottom.map { NSPoint(x:$0.x,y:$0.y-3) }
            if let first=rail.first { let pth=NSBezierPath(); pth.move(to:first); for q in rail.dropFirst() { pth.line(to:q) }; pth.lineWidth=2.4; NSColor(hex:0xC9D0D4).setStroke(); pth.stroke() }
            // Sign at the start of the fork.
            let sx=focusX+(f.start-cameraX)*ppm
            if sx > -80 && sx < viewWidth+80 {
                let sy=ground(f.start,at:cameraX,cameraY:cameraY,route:route)-45
                line(sx,sy,sx,sy-52,3,ink); box(sx-62,sy-100,124,48,NSColor(hex:0xE6E4D8),3)
                text("BIFURCACIÓN",sx,sy-97,9,ink,.bold,center:true); text("C elige camino",sx,sy-79,11,ink,.semibold,center:true)
            }
        }
    }
    /// `limit` is how far the course extends: 1,200 m, laps x 1,200 m on a circuit, or infinite.
    func scenery(cameraX:Double,cameraY:Double,route:Int,night:Bool,limit:Double=1200) {
        let cam=cameraX*metresToPixels
        // Distant roadside objects pass behind the playable silhouette.
        RideProfile.section("  props") { for i in -2..<12 {
            let world=Double(Int(cameraX/23)+i)*23
            let x=focusX+(world-cameraX)*metresToPixels
            guard x > -180 && x < 1460 else { continue }
            let y=ground(world,at:cameraX,cameraY:cameraY,route:route)-42
            if Int(world/23)%3==0 { rock(x,y,Double(abs(Int(world))%22+24),night:night) }
            else if Int(world/23)%3==1 { if route==2 { rock(x,y,32,night:night) } else if route==4 { lamp(x,y,night:night) } else if route==3 { pine(x,y,seed:Int(world)) } else { tree(x,y,seed:Int(world),night:night) } }
        } }
        RideProfile.section("  carretera") {
        let step=5.0
        var road:[NSPoint]=[]
        for x in stride(from:-10.0,through:viewWidth+10,by:step) { road.append(NSPoint(x:x,y:ground(cameraX+(x-focusX)/metresToPixels,at:cameraX,cameraY:cameraY,route:route)-26)) }
        for x in stride(from:viewWidth+10,through:-10,by:-step) { road.append(NSPoint(x:x,y:ground(cameraX+(x-focusX)/metresToPixels,at:cameraX,cameraY:cameraY,route:route)+113)) }
        // A visible strip of textured soil below the track.
        var earth=road; for i in (earth.count/2)..<earth.count { earth[i].y = 740 }
        path(earth,NSColor(hex:route==0 ? 0x7A725E : route==3 ? 0xB7C3CB : route==4 ? 0x3A3F47 : 0x8F694B))
        NSGraphicsContext.saveGraphicsState()
        let clip=NSBezierPath(); clip.move(to:road[0]); for p in road.dropFirst() { clip.line(to:p) }; clip.close()
        // The white edge lines drawn afterwards hide the clip's border, so an aliased clip is invisible and cheaper.
        NSGraphicsContext.current?.shouldAntialias=false; clip.addClip(); NSGraphicsContext.current?.shouldAntialias=true
        box(0,groundY-208,viewWidth,max(470,viewHeight-groundY+208),NSColor(hex:route==0 ? 0x666D71 : route==3 ? 0xE9EFF3 : route==4 ? 0x2F343C : 0xC09862))
        if route != 3, let texture=(route==0 || route==4) ? asphaltTexture : dirtTexture {
            let shift=cam.truncatingRemainder(dividingBy:512)
            let key=(route==0 || route==4) ? "asphalt" : "dirt"
            if textureCG[key]==nil { textureCG[key]=texture.cgImage(forProposedRect:nil,context:nil,hints:nil) }
            if let cg=textureCG[key] { for i in -1..<4 { blit(cg,NSRect(x:Double(i)*512-shift,y:330,width:512,height:300),quality:.low) } }
        }
        gradient(NSRect(x:0,y:groundY-128,width:viewWidth,height:300),NSColor.white.withAlphaComponent(0.08),NSColor.black.withAlphaComponent(0.09))
        NSGraphicsContext.restoreGraphicsState()
        }
        RideProfile.section("  bordes") {
        for x in stride(from:-10.0,through:viewWidth+10,by:8) {
            let a=ground(cameraX+(x-focusX)/metresToPixels,at:cameraX,cameraY:cameraY,route:route), b=ground(cameraX+(x+8-focusX)/metresToPixels,at:cameraX,cameraY:cameraY,route:route)
            line(x,a-27,x+8,b-27,3,NSColor(hex:0xE4E5CE))
            line(x,a+108,x+8,b+108,3,NSColor(hex:0xECEADF,alpha:0.85))
        }
        if route==0 || route==4 {
            for n in -2..<15 { let world=Double(Int(cameraX/5)+n)*5; let x=focusX+(world-cameraX)*metresToPixels; let y=ground(world,at:cameraX,cameraY:cameraY,route:route)+67; line(x,y,x+66,y-1,3,NSColor(hex:0xE5D9B6,alpha:0.74)) }
        }
        }
        RideProfile.section("  hierba") {
        // Individual grass blades at the far verge retain the original game's roadside line.
        let start=Int((cameraX-380/metresToPixels)*18), end=Int((cameraX+920/metresToPixels)*18)
        if start<end { for i in start..<end {
            let w=Double(i)/18, x=focusX+(w-cameraX)*metresToPixels
            let y=ground(w,at:cameraX,cameraY:cameraY,route:route)-30
            let h=Double(abs((i*17)%11)+4), tilt=Double((i*13)%9)-4
            if route != 4 { line(x,y,x+tilt,y-h,1.8,NSColor(hex:route==3 ? [0xF4F7F9,0xDDE6EC,0xC9D6DF,0xEEF3F6][abs(i)%4] : night ? 0x617356 : route==2 ? [0x9B8652,0xAA985F,0xBBA56D,0x8B794C][abs(i)%4] : [0x718441,0x8B9C46,0xA4A956,0x566D3B][abs(i)%4])) }
        } }
        }
        RideProfile.section("  carteles") {
        for n in -1..<6 {
            let world=Double(Int(cameraX/100)+n)*100
            guard world>0 && world<=limit else { continue }
            let x=focusX+(world-cameraX)*metresToPixels
            if x < -80 || x > 1360 { continue }
            let y=ground(world,at:cameraX,cameraY:cameraY,route:route)-45
            line(x,y,x,y-43,3,ink)
            if BikePhysics.circuit && Int(world)%1200 == 0 {
                box(x-58,y-86,116,45,NSColor(hex:0xE6E4D8),3)
                text("VUELTA \(Int(world/1200)+1)",x,y-82,10,ink,.bold,center:true)
                text("Circuito",x,y-65,12,ink,.semibold,center:true)
            } else if BikePhysics.endlessCourse && Int(world)%600 == 0 {
                box(x-58,y-86,116,45,NSColor(hex:0xE6E4D8),3)
                text("NIVEL \(Int(world)/600+1)",x,y-82,10,ink,.bold,center:true)
                text(BikePhysics.zoneTitle(at:world+120),x,y-65,12,ink,.semibold,center:true)
            } else if !BikePhysics.circuit && !BikePhysics.endlessCourse && Int(world)%Int(BikePhysics.finish/4) == 0 && world<limit {
                box(x-58,y-86,116,45,NSColor(hex:0xE6E4D8),3)
                text("TRAMO \(BikePhysics.difficultyStage(at:world)+1)",x,y-82,10,ink,.bold,center:true)
                text(BikePhysics.stageTitle(at:world),x,y-65,12,ink,.semibold,center:true)
            } else {
                box(x-22,y-69,45,27,NSColor(hex:0xE6E4D8),3);text("\(Int(world))",x,y-66,14,ink,.semibold,center:true,mono:true)
            }
        }
        // The finish line, and on a circuit a checkered line at the end of every lap.
        var lines:[Double]=limit.isFinite ? [limit] : []
        if BikePhysics.circuit { lines=stride(from:BikePhysics.circuitLength,through:limit,by:BikePhysics.circuitLength).map { $0 } }
        for end in lines {
            let finish=focusX+(end-cameraX)*metresToPixels
            guard finish > -20 && finish < 1350 else { continue }
            let y=ground(end,at:cameraX,cameraY:cameraY,route:route)
            line(finish,y-27,finish,y-170,4,silver)
            for r in 0..<4 { for c in 0..<6 { box(finish+Double(c)*11,y-170+Double(r)*11,11,11,(r+c)%2==0 ? .white : ink) } }
        }
        }
    }
    func rock(_ x:Double,_ y:Double,_ s:Double,night:Bool) {
        poly([(x-s,y),(x-s*0.65,y-s*0.75),(x-s*0.1,y-s),(x+s*0.65,y-s*0.55),(x+s,y)],NSColor(hex:night ? 0x545D58 : 0x8E9580),stroke:NSColor(hex:0x626957),width:1)
        poly([(x-s*0.65,y-s*0.75),(x-s*0.1,y-s),(x+s*0.65,y-s*0.55),(x+s*0.25,y-s*0.4),(x+s*0.05,y-s*0.65),(x-s*0.1,y-s*0.2)],NSColor(hex:night ? 0x68736A : 0xB3B6A0))
    }
    func tree(_ x:Double,_ y:Double,seed:Int,night:Bool) {
        let variant=abs(seed/23)%6,key=variant+(night ? 100 : 0)
        let texture:NSImage
        if let cached=treeTextures[key] { texture=cached } else {
            let img=NSImage(size:NSSize(width:160,height:220)); img.lockFocusFlipped(true)
            var state=UInt64(321+variant*97)
            func random()->Double { state=state &* 6364136223846793005 &+ 1; return Double(state>>33)/Double(UInt64(1)<<31) }
            let trunk=NSBezierPath(); trunk.move(to:NSPoint(x:75,y:218)); trunk.curve(to:NSPoint(x:77,y:60),controlPoint1:NSPoint(x:82,y:165),controlPoint2:NSPoint(x:64,y:101)); trunk.line(to:NSPoint(x:82,y:60)); trunk.curve(to:NSPoint(x:83,y:218),controlPoint1:NSPoint(x:75,y:108),controlPoint2:NSPoint(x:90,y:167)); trunk.close()
            NSGradient(colors:[NSColor(hex:0x78684A),NSColor(hex:0x423F31)])?.draw(in:trunk,angle:0)
            for i in 0..<12 {
                let branchX=28+random()*104,branchY=25+random()*88
                line(79,147-Double(i)*4,branchX,branchY,2.0-Double(i)*0.09,NSColor(hex:0x655C40))
                for _ in 0..<3 { let xx=branchX+(random()-0.5)*28,yy=branchY-random()*24; line(branchX,branchY,xx,yy,0.8,NSColor(hex:0x686042)) }
            }
            for _ in 0..<31 {
                let cx=27+random()*105,cy=28+random()*100,r=12+random()*15
                let crown=NSBezierPath()
                for j in 0..<12 {
                    let a=Double(j)*Double.pi/6,rr=r*(0.75+random()*0.30)
                    let point=NSPoint(x:cx+cos(a)*rr,y:cy+sin(a)*rr*0.8)
                    if j==0 { crown.move(to:point) } else { crown.line(to:point) }
                }
                crown.close()
                let palette=night ? [0x344B3A,0x405442,0x52634B] : [0x596A3E,0x70854B,0x8C9657,0x657C43]
                let base=NSColor(hex:palette[Int(random()*Double(palette.count))%palette.count])
                NSGradient(starting:base.blended(withFraction:0.12,of:.white) ?? base,ending:base.blended(withFraction:0.16,of:.black) ?? base)?.draw(in:crown,angle:90)
            }
            for _ in 0..<360 {
                let xx=23+random()*114,yy=15+random()*118
                let dx=(xx-80)/61,dy=(yy-75)/69
                if dx*dx+dy*dy>1 { continue }
                let w=2+random()*3,h=1.5+random()*2
                poly([(xx-w,yy),(xx,yy-h),(xx+w,yy-1),(xx+1,yy+h)],NSColor(hex:night ? 0x6A7959 : random()>0.5 ? 0xB0B576 : 0x324E30,alpha:0.38))
            }
            img.unlockFocus();treeTextures[key]=img;texture=img
        }
        let height=145+Double(variant)*7
        image(texture,NSRect(x:x-height*0.36,y:y-height,width:height*0.73,height:height))
    }
    func cone(_ world:Double,cameraX:Double,cameraY:Double,route:Int,knocked:Bool=false) {
        let x=focusX+(world-cameraX)*metresToPixels,y=ground(world,at:cameraX,cameraY:cameraY,route:route)
        guard x > -50 && x < 1330 else { return }
        if knocked {
            ellipse(x-14,y-2,48,6,NSColor.black.withAlphaComponent(0.15))
            poly([(x-8,y-4),(x+24,y-15),(x+27,y-7),(x+2,y+3)],NSColor(hex:0xE96524),stroke:ink,width:0.7)
            line(x+7,y-8,x+13,y-10,4,NSColor(hex:0xF1EBDD)); return
        }
        ellipse(x-21,y-3,48,8,NSColor.black.withAlphaComponent(0.16)); box(x-18,y-4,36,5,ink,2)
        poly([(x-12,y-4),(x-3,y-34),(x+4,y-34),(x+13,y-4)],NSColor(hex:0xEF6A27),stroke:ink,width:0.8)
        poly([(x-8,y-15),(x-5,y-25),(x+7,y-25),(x+10,y-15)],NSColor(hex:0xEEE5D2))
    }
    /// A forward-pointing light cone and a pool of light on the road, for night rides.
    func headlight(x:Double,y:Double,angle:Double,wheelbasePixels:Double) {
        let c=cos(angle),s=sin(angle)
        let origin=NSPoint(x:x+c*wheelbasePixels*0.97+s*8,y:y-s*wheelbasePixels*0.97+c*(-26))
        func pt(_ length:Double,_ spread:Double)->NSPoint { NSPoint(x:origin.x+c*length-s*spread,y:origin.y-s*length-c*spread) }
        let beam=NSBezierPath(); beam.move(to:origin); beam.line(to:pt(420,-34)); beam.line(to:pt(420,70)); beam.close()
        NSGraphicsContext.saveGraphicsState(); beam.addClip()
        NSGradient(colors:[NSColor(hex:0xFFF1C2,alpha:0.50),NSColor(hex:0xFFF1C2,alpha:0.0)])?.draw(in:beam,angle:-Double(angle)*180/Double.pi)
        NSGraphicsContext.restoreGraphicsState()
        circle(origin.x,origin.y,5,NSColor(hex:0xFFF8DC,alpha:0.95))
    }
    func lamp(_ x:Double,_ y:Double,night:Bool) {
        line(x,y,x,y-120,4,NSColor(hex:0x2A2F38)); line(x,y-120,x+26,y-124,3,NSColor(hex:0x2A2F38))
        circle(x+26,y-120,6,NSColor(hex:0xFFE3A3,alpha:night ? 1 : 0.7))
        if night { ellipse(x-10,y-132,70,34,NSColor(hex:0xFFE3A3,alpha:0.12)) }
    }
    func pine(_ x:Double,_ y:Double,seed:Int) {
        let h=110+Double(abs(seed)%5)*14
        line(x,y,x,y-h*0.22,6,NSColor(hex:0x5B4632))
        for tier in 0..<4 {
            let t=Double(tier),w=h*(0.34-t*0.05),top=y-h*0.2-t*h*0.2
            poly([(x-w,top),(x,top-h*0.3),(x+w,top)],NSColor(hex:0x2F5A45),stroke:NSColor(hex:0x234535),width:0.6)
            poly([(x-w*0.55,top-h*0.12),(x,top-h*0.3),(x+w*0.55,top-h*0.12),(x,top-h*0.07)],NSColor(hex:0xF2F6F8))
        }
    }
    func barrel(_ world:Double,cameraX:Double,cameraY:Double,route:Int,knocked:Bool=false) {
        let x=focusX+(world-cameraX)*metresToPixels,y=ground(world,at:cameraX,cameraY:cameraY,route:route)
        guard x > -60 && x < 1340 else { return }
        if knocked {
            ellipse(x-18,y-2,70,7,NSColor.black.withAlphaComponent(0.15))
            box(x-6,y-26,56,26,NSColor(hex:0xB4492E),5); box(x+8,y-26,5,26,NSColor(hex:0xE8D9B8)); box(x+32,y-26,5,26,NSColor(hex:0xE8D9B8))
            return
        }
        ellipse(x-24,y-3,52,8,NSColor.black.withAlphaComponent(0.16))
        box(x-17,y-60,34,60,NSColor(hex:0xB4492E),7); box(x-17,y-46,34,5,NSColor(hex:0xE8D9B8)); box(x-17,y-18,34,5,NSColor(hex:0xE8D9B8))
        box(x-12,y-58,7,54,NSColor.white.withAlphaComponent(0.16),3)
    }
    func log(_ world:Double,cameraX:Double,cameraY:Double,route:Int,knocked:Bool=false) {
        let x=focusX+(world-cameraX)*metresToPixels,y=ground(world,at:cameraX,cameraY:cameraY,route:route)
        guard x > -80 && x < 1360 else { return }
        let lift=knocked ? 6.0 : 0.0
        ellipse(x-48,y-3,104,8,NSColor.black.withAlphaComponent(0.16))
        box(x-48,y-30-lift,96,28,NSColor(hex:0x6B4A2E),12); box(x-44,y-27-lift,88,6,NSColor.white.withAlphaComponent(0.12),3)
        circle(x+46,y-16-lift,13,NSColor(hex:0xC79A62)); circle(x+46,y-16-lift,7,NSColor(hex:0xA87B47))
    }
    /// A wet patch lying on the road, following the ground line.
    func puddle(center world:Double,halfLength:Double,cameraX:Double,cameraY:Double,route:Int) {
        let x0=focusX+(world-halfLength-cameraX)*metresToPixels,x1=focusX+(world+halfLength-cameraX)*metresToPixels
        guard x1 > -20 && x0 < viewWidth+20 else { return }
        var top:[NSPoint]=[],bottom:[NSPoint]=[]
        let steps=12
        for i in 0...steps {
            let f=Double(i)/Double(steps),w=world-halfLength+2*halfLength*f
            let px=focusX+(w-cameraX)*metresToPixels,gy=ground(w,at:cameraX,cameraY:cameraY,route:route)
            let bulge=sin(f*Double.pi)*8
            top.append(NSPoint(x:px,y:gy-bulge*0.2)); bottom.append(NSPoint(x:px,y:gy+3+bulge))
        }
        path(top+bottom.reversed(),NSColor(hex:0x5C7FA3,alpha:0.55))
        if let a=top.dropFirst(2).first,let b=top.dropLast(3).last { line(a.x,a.y+2,b.x,b.y+2,1.5,NSColor.white.withAlphaComponent(0.4)) }
    }
    func wheel(_ x:Double,_ y:Double,_ r:Double,rotation:Double,bmx:Bool,offroad:Bool) {
        circle(x,y,r,NSColor(hex:0x141A20)); circle(x,y,r-2,NSColor(hex:0x333A3E)); circle(x,y,r-5,silver); circle(x,y,r-6.6,NSColor(hex:0x3D464A))
        let count=bmx ? 24 : 18
        for i in 0..<count { let a=Double(i)*2*Double.pi/Double(count)+rotation; line(x+cos(a+0.5)*3,y+sin(a+0.5)*3,x+cos(a)*(r-7),y+sin(a)*(r-7),bmx ? 0.55 : 0.7,NSColor(hex:0xDCE0E1,alpha:0.8)) }
        circle(x,y,bmx ? 3.4 : 7,NSColor(hex:0x919DA2)); circle(x,y,2.3,ink)
        if !bmx { for i in 0..<8 { let a=Double(i)*Double.pi/4+rotation; circle(x+cos(a)*4.8,y+sin(a)*4.8,0.65,ink) } }
        if offroad { for i in 0..<30 { let a=Double(i)*Double.pi/15+rotation; line(x+cos(a)*(r-1.5),y+sin(a)*(r-1.5),x+cos(a)*(r+0.3),y+sin(a)*(r+0.3),1.7,ink) } }
        // A fixed silver rim highlight, separate from rotating spokes.
        line(x-r*0.63,y-r*0.68,x-r*0.42,y-r*0.84,0.9,NSColor.white.withAlphaComponent(0.75))
    }
    struct Geometry { var front:Double,radius:Double,seat:NSPoint,grip:NSPoint,peg:NSPoint }
    func geometry(_ kind:BikeKind)->Geometry {
        let r=kind.rig,u=r.drawingUnitsPerMetre
        func p(_ v:RideVector)->NSPoint { NSPoint(x:v.x*u,y:-v.y*u) }
        return Geometry(front:r.wheelbase*u,radius:r.wheelRadius*u,seat:p(r.seat),grip:p(r.grip),peg:p(r.footPeg))
    }
    func motorcycle(x:Double,y:Double,scale:Double,angle:Double,kind:BikeKind,rotation:Double,time:Double,lean:Double=0,stunt:Bool=false,handsOff:Double=0,superman:Double=0,crash:Double=0,showRider:Bool=true,rearWheelLocal:RideVector?=nil,frontWheelLocal:RideVector?=nil,frontCompression:Double=0,rearCompression:Double=0,frontRotation:Double?=nil,pedalPhase:Double=0,riderLift:Double=0) {
        let rig=kind.rig,u=rig.drawingUnitsPerMetre
        func p(_ v:RideVector)->NSPoint { NSPoint(x:v.x*u,y:-v.y*u) }
        NSGraphicsContext.saveGraphicsState(); let transform=NSAffineTransform(); transform.translateX(by:x,yBy:y); transform.scale(by:scale); transform.rotate(byRadians:-angle); transform.concat()
        drawVehicle(kind:kind,rearAxle:p(rearWheelLocal ?? rig.rearAxle),frontAxle:p(frontWheelLocal ?? rig.frontAxle),frontCompression:frontCompression,rearCompression:rearCompression,rotationRear:rotation,rotationFront:frontRotation ?? rotation,pedalPhase:pedalPhase,time:time)
        drawLivery(kind:kind,units:u)
        if showRider {
            if passenger && kind.supportsPassenger {
                let pose=RiderRig.solve(vehicle:rig,lean:lean*0.3,lift:riderLift,pedalPhase:pedalPhase,passenger:true)
                drawRider(pose,units:u,kind:kind,passenger:true)
            }
            let pose=RiderRig.solve(vehicle:rig,lean:lean,lift:riderLift,pedalPhase:pedalPhase,cycling:kind == .bmx,stunt:stunt,handsOff:handsOff,superman:superman)
            drawRider(pose,units:u,kind:kind,passenger:false)
        }
        NSGraphicsContext.restoreGraphicsState()
    }
    /// Purchased decorations on the tail section, placed from the vehicle's own seat point so every vehicle
    /// gets them in a visible spot (the rider covers the tank).
    func drawLivery(kind:BikeKind,units u:Double) {
        guard livery != .none,kind != .bmx else { return }
        let seat=NSPoint(x:kind.rig.seat.x*u,y:-kind.rig.seat.y*u)
        switch livery {
        case .number:
            let c=NSPoint(x:seat.x-0.27*u,y:seat.y+0.075*u),plate=NSBezierPath(roundedRect:NSRect(x:c.x-0.085*u,y:c.y-0.06*u,width:0.17*u,height:0.12*u),xRadius:0.025*u,yRadius:0.025*u)
            NSColor.white.setFill(); plate.fill(); ink.withAlphaComponent(0.6).setStroke(); plate.lineWidth=0.6; plate.stroke()
            text("\(raceNumber)",c.x,c.y-0.055*u,0.1*u,ink,.heavy,center:true,mono:true)
        case .stripes:
            for k in [0.0,0.03] { line(seat.x-0.36*u,seat.y+(0.075+k)*u,seat.x-0.04*u,seat.y+(0.055+k)*u,0.016*u,NSColor.white.withAlphaComponent(0.92)) }
        case .checker:
            for i in 0..<6 { let x=seat.x-0.36*u+Double(i)*0.06*u; box(x,seat.y+0.06*u,0.03*u,0.03*u,i%2==0 ? .white : ink); box(x,seat.y+0.09*u,0.03*u,0.03*u,i%2==0 ? ink : .white) }
        case .none: break
        }
    }
    func shadow(x:Double,y:Double,width:Double,height:Double,alpha:Double=0.22) {
        for i in stride(from:5,through:1,by:-1) { let f=Double(i)/5; ellipse(x-width*f/2,y-height*f/2,width*f,height*f,NSColor.black.withAlphaComponent(alpha/5)) }
    }
}
