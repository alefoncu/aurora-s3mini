import Cocoa

/// The rider is a stylised doll with human proportions. Every limb is a tapered, muscled volume whose
/// ends sit exactly on the solver's joints; clothing, protections, gloves and boots are drawn on top.
extension RideRenderer {
    private func raPoint(_ v:RideVector,_ u:Double)->NSPoint { NSPoint(x:v.x*u,y:-v.y*u) }
    private func raShade(_ color:NSColor,_ amount:Double)->NSColor {
        color.blended(withFraction:abs(amount),of:amount>=0 ? .white : .black) ?? color
    }
    /// Closed Catmull-Rom spline through the points, as cubic Béziers.
    private func raSpline(_ p:[NSPoint],closed:Bool=true)->NSBezierPath {
        let path=NSBezierPath(),n=p.count
        guard n>2 else { return path }
        path.move(to:p[0])
        let last = closed ? n : n-1
        for i in 0..<last {
            let p0=closed ? p[(i+n-1)%n] : p[max(0,i-1)],p1=p[i],p2=p[(i+1)%n],p3=closed ? p[(i+2)%n] : p[min(n-1,i+2)]
            path.curve(to:p2,controlPoint1:NSPoint(x:p1.x+(p2.x-p0.x)/6,y:p1.y+(p2.y-p0.y)/6),
                       controlPoint2:NSPoint(x:p2.x-(p3.x-p1.x)/6,y:p2.y-(p3.y-p1.y)/6))
        }
        if closed { path.close() }
        return path
    }
    private func raFill(_ shape:NSBezierPath,_ base:NSColor,angle:Double=75,outline:Bool=true,strength:Double=1,width:Double=0.6) {
        NSGradient(colors:[raShade(base,0.24*strength),base,raShade(base,-0.28*strength)])?.draw(in:shape,angle:angle)
        if outline { ink.withAlphaComponent(0.72).setStroke(); shape.lineWidth=width; shape.lineJoinStyle = .round; shape.stroke() }
    }
    /// A tapered limb segment: width `w0` at `a`, `w1` at `b`, with an optional muscle belly.
    private func raLimb(_ a:NSPoint,_ b:NSPoint,_ w0:Double,_ w1:Double,bulge:Double=0,at:Double=0.35,color:NSColor,outline:Bool=true) {
        let dx=b.x-a.x,dy=b.y-a.y,l=max(0.01,hypot(dx,dy)),ux=dx/l,uy=dy/l,nx = -uy,ny=ux
        func width(_ t:Double)->Double {
            let d=(t-at)/(t<at ? max(at,0.1) : max(1-at,0.1))
            return w0+(w1-w0)*t+bulge*max(0,1-d*d)
        }
        var left:[NSPoint]=[],right:[NSPoint]=[]
        for t in [0.0,0.2,0.4,0.6,0.8,1.0] {
            let c=NSPoint(x:a.x+dx*t,y:a.y+dy*t),h=width(t)/2
            left.append(NSPoint(x:c.x+nx*h,y:c.y+ny*h)); right.append(NSPoint(x:c.x-nx*h,y:c.y-ny*h))
        }
        let tip=NSPoint(x:b.x+ux*w1*0.5,y:b.y+uy*w1*0.5),tail=NSPoint(x:a.x-ux*w0*0.5,y:a.y-uy*w0*0.5)
        raFill(raSpline(left+[tip]+Array(right.reversed())+[tail]),color,outline:outline)
    }
    /// A soft stripe along a limb (seams, piping, reflective bands).
    private func raStripe(_ a:NSPoint,_ b:NSPoint,from t0:Double,to t1:Double,side:Double,offset:Double,width:Double,_ c:NSColor) {
        let dx=b.x-a.x,dy=b.y-a.y,l=max(0.01,hypot(dx,dy)),nx = -dy/l,ny=dx/l
        line(a.x+dx*t0+nx*offset*side,a.y+dy*t0+ny*offset*side,a.x+dx*t1+nx*offset*side,a.y+dy*t1+ny*offset*side,width,c)
    }
    private func raBand(_ a:NSPoint,_ b:NSPoint,at t:Double,half:Double,width:Double,_ c:NSColor) {
        let dx=b.x-a.x,dy=b.y-a.y,l=max(0.01,hypot(dx,dy)),nx = -dy/l,ny=dx/l,x=a.x+dx*t,y=a.y+dy*t
        line(x-nx*half,y-ny*half,x+nx*half,y+ny*half,width,c)
    }
    // MARK: Feet
    /// `foot` is the sole contact point; `shin` is the unit vector from ankle towards the knee.
    private func raBoot(_ foot:NSPoint,shin:NSPoint,u:Double,style:BikeKind,far:Bool) {
        let tall = style == .motocross || style == .sport
        let sole=NSColor(hex:0x15191D)
        func P(_ x:Double,_ y:Double)->NSPoint { NSPoint(x:foot.x+x*u,y:foot.y-y*u) }
        let dim:Double = far ? -0.22 : 0
        if tall {
            let base=style == .motocross ? NSColor(hex:0xE9E5DA) : NSColor(hex:0x2C333C)
            let color=raShade(base,dim)
            let shaftTop=NSPoint(x:foot.x+shin.x*0.0,y:foot.y)   // anchor for readability
            _ = shaftTop
            // Foot box and ankle block, then the shaft up the shin.
            let foot=raSpline([P(-0.085,0.0),P(-0.095,0.05),P(-0.07,0.115),P(0.0,0.135),P(0.07,0.115),P(0.13,0.088),P(0.185,0.06),P(0.205,0.026),P(0.19,0.0),P(0.08,-0.004)])
            raFill(foot,color,angle:80)
            let ankle=NSPoint(x:P(0,0.095).x,y:P(0,0.095).y)
            let top=NSPoint(x:ankle.x+shin.x*0.19*u,y:ankle.y+shin.y*0.19*u)
            raLimb(ankle,top,0.125*u,0.135*u,bulge:0.006*u,color:color)
            // Sole, heel, toe protector, buckles and shin plate.
            let soleP=raSpline([P(-0.09,0.0),P(-0.09,-0.02),P(0.02,-0.025),P(0.2,-0.022),P(0.215,0.005),P(0.195,0.02),P(0.08,0.012)])
            raFill(soleP,sole,outline:false); ink.setStroke(); soleP.lineWidth=0.5; soleP.stroke()
            raFill(raSpline([P(0.13,0.035),P(0.2,0.03),P(0.2,0.058),P(0.14,0.075)]),style == .motocross ? NSColor(hex:0x6E7378) : NSColor(hex:0x8B9298),outline:true,width:0.4)
            let n=NSPoint(x:-shin.y,y:shin.x)
            for t in (style == .motocross ? [0.22,0.5,0.78] : [0.55]) {
                let c=NSPoint(x:ankle.x+shin.x*0.19*u*t,y:ankle.y+shin.y*0.19*u*t)
                line(c.x-n.x*u*0.062,c.y-n.y*u*0.062,c.x+n.x*u*0.062,c.y+n.y*u*0.062,u*0.022,NSColor(hex:0x20262C))
                circle(c.x+n.x*u*0.02,c.y+n.y*u*0.02,u*0.011,NSColor(hex:0xC7CDD0))
            }
            let brand=style == .motocross ? raShade(jacket,-0.25) : NSColor(hex:0x9AA3AA)
            raStripe(ankle,top,from:0.1,to:0.94,side:1,offset:0.04*u/(0.19*u)*0.19*u*0.5,width:u*0.014,brand)
            return
        }
        // Trainer: rubber sole, canvas upper, toe cap, laces and a padded collar.
        let upper=raShade(style == .bmx ? NSColor(hex:0x2B3138) : NSColor(hex:0x6F6455),dim)
        let shoe=raSpline([P(-0.08,0.0),P(-0.085,0.045),P(-0.07,0.085),P(-0.01,0.1),P(0.06,0.088),P(0.12,0.06),P(0.175,0.04),P(0.195,0.018),P(0.18,0.0),P(0.08,-0.003)])
        raFill(shoe,upper,angle:80)
        NSGraphicsContext.saveGraphicsState(); shoe.addClip()
        raFill(raSpline([P(0.115,0.0),P(0.115,0.05),P(0.17,0.045),P(0.2,0.02),P(0.2,0.0)]),raShade(upper,0.14),outline:false)
        NSGraphicsContext.restoreGraphicsState()
        let soleP=raSpline([P(-0.09,0.0),P(-0.09,-0.022),P(0.03,-0.028),P(0.2,-0.02),P(0.212,0.005),P(0.19,0.02),P(0.08,0.012)])
        raFill(soleP,NSColor(hex:0xE3DFD3),outline:false); ink.withAlphaComponent(0.6).setStroke(); soleP.lineWidth=0.5; soleP.stroke()
        line(P(-0.07,-0.012).x,P(-0.07,-0.012).y,P(0.19,-0.01).x,P(0.19,-0.01).y,u*0.008,NSColor(hex:0x7F7A6F))
        for i in 0..<4 { let a=P(0.03+Double(i)*0.028,0.085-Double(i)*0.008),b=P(0.045+Double(i)*0.028,0.07-Double(i)*0.008); line(a.x,a.y,b.x,b.y,u*0.009,.white) }
        line(P(-0.07,0.09).x,P(-0.07,0.09).y,P(0.02,0.1).x,P(0.02,0.1).y,u*0.02,raShade(upper,-0.3))
    }
    // MARK: Hands
    /// A fist closed around the grip: gauntlet cuff, back of the hand, curled fingers, thumb and the bar-end cap.
    private func raGlove(hand:NSPoint,wrist:NSPoint,u:Double,style:BikeKind,color:NSColor,accent:NSColor) {
        let dx=hand.x-wrist.x,dy=hand.y-wrist.y,l=max(0.001,hypot(dx,dy)),ux=dx/l,uy=dy/l
        // `a` runs along the forearm, `b` across it (positive towards the ground side).
        func G(_ a:Double,_ b:Double)->NSPoint { NSPoint(x:hand.x+(ux*a-uy*b)*u,y:hand.y+(uy*a+ux*b)*u) }
        let sporty = style == .sport || style == .motocross
        if sporty { raLimb(G(-0.115,0),G(-0.03,0),0.088*u,0.098*u,color:raShade(color,-0.12)) }
        else { raLimb(G(-0.07,0),G(-0.02,0),0.07*u,0.078*u,color:raShade(color,-0.1)) }
        let fist=raSpline([G(-0.045,-0.045),G(0.01,-0.058),G(0.065,-0.05),G(0.092,-0.012),G(0.088,0.036),G(0.055,0.072),G(0.005,0.07),G(-0.03,0.035),G(-0.05,-0.005)])
        raFill(fist,color,angle:75,strength:1.2)
        NSGraphicsContext.saveGraphicsState(); fist.addClip()
        // Finger separations curling round the grip, a knuckle crease and a palm shadow.
        for k in [0.0,0.026,0.05] {
            let f=NSBezierPath(); f.move(to:G(0.02,-0.04+k)); f.curve(to:G(0.1,0.0+k*0.6),controlPoint1:G(0.06,-0.045+k),controlPoint2:G(0.09,-0.025+k*0.8))
            f.lineWidth=u*0.007; raShade(color,-0.5).setStroke(); f.stroke()
        }
        line(G(-0.02,0.05).x,G(-0.02,0.05).y,G(0.04,0.066).x,G(0.04,0.066).y,u*0.012,NSColor.black.withAlphaComponent(0.2))
        NSGraphicsContext.restoreGraphicsState()
        // Thumb resting on top of the grip.
        let thumb=raSpline([G(-0.01,-0.052),G(0.04,-0.075),G(0.09,-0.062),G(0.085,-0.04),G(0.04,-0.04)])
        raFill(thumb,raShade(color,0.1),angle:75,width:0.5)
        if sporty {
            // Armoured knuckles in the jacket colour.
            let k=raSpline([G(0.03,-0.062),G(0.085,-0.056),G(0.1,-0.01),G(0.09,0.03),G(0.05,0.0)])
            raFill(k,accent,angle:75,width:0.5)
            line(G(0.045,-0.05).x,G(0.045,-0.05).y,G(0.088,-0.03).x,G(0.088,-0.03).y,u*0.007,NSColor.white.withAlphaComponent(0.55))
        }
        // The bar-end of the grip protrudes towards the viewer: rubber ring and a chrome weight.
        let cap=G(0.05,0.012)
        circle(cap.x,cap.y,0.034*u,NSColor(hex:0x1B2328)); circle(cap.x,cap.y,0.022*u,NSColor(hex:0x808C92)); circle(cap.x,cap.y,0.013*u,NSColor(hex:0xDDE3E1))
        circle(cap.x-0.004*u,cap.y-0.005*u,0.005*u,NSColor.white.withAlphaComponent(0.8))
    }
    /// All limbs are shaded around the solver's exact anchors, never scaled to reach.
    func drawRider(_ pose:RiderPose,units u:Double,kind:BikeKind,passenger:Bool=false,detached:Bool=false) {
        let hip=raPoint(pose.hip,u), shoulder=raPoint(pose.shoulder,u), elbow=raPoint(pose.elbow,u), hand=raPoint(pose.hand,u)
        let knee=raPoint(pose.knee,u),foot=raPoint(pose.foot,u),farKnee=raPoint(pose.farKnee,u),farFoot=raPoint(pose.farFoot,u)
        let neck=raPoint(pose.neck,u),head=raPoint(pose.head,u)
        let style:BikeKind=passenger ? .commuter : kind.outfitStyle
        let coat=passenger ? NSColor(hex:0xC76254) : jacket
        let dark=NSColor(hex:0x202B36), accent=raShade(coat,0.60)
        let jeans:NSColor
        switch style {
        case .commuter:jeans=NSColor(hex:0x3A5270)
        case .motocross:jeans=raShade(coat,-0.46)
        case .sport:jeans=NSColor(hex:0x242C35)
        case .bmx:jeans=NSColor(hex:0x4A5156)
        default:jeans=NSColor(hex:0x3A5270)
        }
        let leather = style == .sport
        let leg:(NSPoint,NSPoint,NSPoint,Double)->Void = { hipP,kneeP,footP,dim in
            let c=self.raShade(jeans,dim)
            let ankle=NSPoint(x:footP.x-0.012*u,y:footP.y-0.085*u)
            let sx=kneeP.x-ankle.x,sy=kneeP.y-ankle.y,sl=max(0.001,hypot(sx,sy))
            self.raBoot(footP,shin:NSPoint(x:sx/sl,y:sy/sl),u:u,style:style,far:dim != 0)
            self.raLimb(kneeP,ankle,0.118*u,0.078*u,bulge:0.026*u,at:0.28,color:c)
            self.raLimb(hipP,kneeP,0.205*u,0.125*u,bulge:0.022*u,at:0.22,color:c)
            self.circle(kneeP.x,kneeP.y,0.058*u,c)
            if dim == 0 {
                self.raStripe(hipP,kneeP,from:0.15,to:0.95,side:-1,offset:0.045*u,width:u*0.008,NSColor.white.withAlphaComponent(leather ? 0.16 : 0.18))
                if style == .commuter || style == .bmx {
                    // Jeans: fold creases at the knee and a stitched outer seam.
                    for k in [-0.03,0.0,0.03] { self.line(kneeP.x-0.05*u,kneeP.y+k*u,kneeP.x-0.015*u,kneeP.y+(k+0.012)*u,u*0.006,NSColor.black.withAlphaComponent(0.22)) }
                    self.raStripe(ankle,kneeP,from:0.0,to:1.0,side:1,offset:0.036*u,width:u*0.006,self.raShade(c,0.28))
                } else {
                    // Knee brace / slider.
                    let pad=self.raSpline([NSPoint(x:kneeP.x-0.02*u,y:kneeP.y-0.068*u),NSPoint(x:kneeP.x+0.05*u,y:kneeP.y-0.055*u),NSPoint(x:kneeP.x+0.068*u,y:kneeP.y+0.0),NSPoint(x:kneeP.x+0.045*u,y:kneeP.y+0.06*u),NSPoint(x:kneeP.x-0.025*u,y:kneeP.y+0.062*u),NSPoint(x:kneeP.x-0.05*u,y:kneeP.y)])
                    self.raFill(pad,style == .motocross ? NSColor(hex:0xDADCD6) : NSColor(hex:0x3A424B))
                    if style == .sport { self.raFill(self.raSpline([NSPoint(x:kneeP.x+0.035*u,y:kneeP.y-0.03*u),NSPoint(x:kneeP.x+0.075*u,y:kneeP.y-0.015*u),NSPoint(x:kneeP.x+0.07*u,y:kneeP.y+0.035*u),NSPoint(x:kneeP.x+0.04*u,y:kneeP.y+0.03*u)]),NSColor(hex:0x9AA0A5),outline:true,width:0.4) }
                    else { for k in [-0.025,0.0,0.025] { self.line(kneeP.x-0.04*u,kneeP.y+k*u,kneeP.x+0.05*u,kneeP.y+k*u,u*0.008,NSColor(hex:0x80858A)) } }
                }
            }
        }
        // Far leg: darker to keep depth.
        leg(hip,farKnee,farFoot,-0.28)
        // Pelvis and torso: a fitted volume with a lumbar curve, chest and shoulder line.
        let dx=shoulder.x-hip.x,dy=shoulder.y-hip.y,l=max(0.001,hypot(dx,dy)),nx = -dy/l,ny=dx/l
        func T(_ s:Double,_ n:Double)->NSPoint { NSPoint(x:hip.x+dx*s+nx*n*u,y:hip.y+dy*s+ny*n*u) }
        let humpy = style == .sport || style == .motocross
        var torsoPts:[NSPoint]=[T(-0.02,-0.095),T(0.2,-0.098),T(0.45,-0.112),T(0.72,-0.13+(humpy ? -0.02 : 0)),T(0.93,-0.115),T(1.05,-0.05),T(1.06,0.03),T(0.96,0.105),T(0.78,0.145),T(0.55,0.128),T(0.32,0.112),T(0.08,0.12),T(-0.04,0.045)]
        if humpy { torsoPts.insert(T(0.88,-0.165),at:5) }
        let torso=raSpline(torsoPts)
        raFill(torso,leather ? NSColor(hex:0x242B33) : coat,angle:70)
        NSGraphicsContext.saveGraphicsState();torso.addClip()
        switch style {
        case .sport:
            // Leather suit panels: coloured back/shoulder panel, white piping, stitched seams, back hump.
            raFill(raSpline([T(0.35,-0.2),T(0.98,-0.2),T(1.05,0.0),T(0.7,0.04),T(0.4,-0.02)]),coat,outline:false)
            line(T(0.05,0.07).x,T(0.05,0.07).y,T(0.95,0.09).x,T(0.95,0.09).y,u*0.012,accent)
            line(T(0.05,-0.02).x,T(0.05,-0.02).y,T(0.9,-0.01).x,T(0.9,-0.01).y,u*0.005,NSColor.white.withAlphaComponent(0.5))
            line(T(0.12,0.09).x,T(0.12,0.09).y,T(0.12,-0.1).x,T(0.12,-0.1).y,u*0.028,raShade(dark,-0.2))
        case .motocross:
            raFill(raSpline([T(0.4,-0.2),T(1.05,-0.2),T(1.08,0.2),T(0.62,0.16),T(0.52,0.0)]),raShade(coat,-0.05),outline:false)
            for f in [0.5,0.64,0.78] { raBand(hip,shoulder,at:f,half:0.14*u,width:u*0.016,dark) }
            line(T(0.02,0.0).x,T(0.02,0.0).y,T(1.0,0.0).x,T(1.0,0.0).y,u*0.018,accent)
            raBand(hip,shoulder,at:0.08,half:0.14*u,width:u*0.04,dark)
        case .bmx:
            line(T(0.12,0.02).x,T(0.12,0.02).y,T(0.9,0.02).x,T(0.9,0.02).y,u*0.01,raShade(coat,0.16))
            ellipse(T(0.62,0.04).x-0.045*u,T(0.62,0.04).y-0.045*u,0.09*u,0.09*u,NSColor(hex:0xEDE6D4,alpha:0.9))
        default:
            // Textile jacket: quilted shoulder panels, chest pocket zip, drawcord hem and belt.
            for f in [0.55,0.7,0.85] { raBand(hip,shoulder,at:f,half:0.14*u,width:u*0.007,raShade(coat,-0.3)) }
            raBand(hip,shoulder,at:0.08,half:0.14*u,width:u*0.03,raShade(coat,-0.28))
            line(T(0.22,0.095).x,T(0.22,0.095).y,T(0.82,0.12).x,T(0.82,0.12).y,u*0.009,NSColor(hex:0xD3DADE))
            line(T(0.52,0.05).x,T(0.52,0.05).y,T(0.4,0.05).x,T(0.4,0.05).y,u*0.014,NSColor(hex:0xD3DADE))
            raBand(hip,shoulder,at:0.02,half:0.13*u,width:u*0.02,NSColor(hex:0x2B2F33))
        }
        switch jacketStyle {
        case .reflective:
            for f in [0.34,0.56] { raBand(hip,shoulder,at:f,half:0.14*u,width:u*0.026,NSColor(hex:0xE9F0F4,alpha:0.95)) }
        case .racing:
            for side in [-1.0,1.0] { line(T(0.0,0.045*side).x,T(0.0,0.045*side).y,T(1.0,0.045*side).x,T(1.0,0.045*side).y,u*0.022,NSColor.white.withAlphaComponent(0.92)) }
        case .twoTone:
            line(T(0.0,0.055).x,T(0.0,0.055).y,T(1.0,0.055).x,T(1.0,0.055).y,u*0.12,raShade(coat,-0.35))
        case .standard: break
        }
        // Soft ambient-occlusion shading under the arm and at the waist.
        line(T(0.2,-0.02).x,T(0.2,-0.02).y,T(0.8,0.0).x,T(0.8,0.0).y,u*0.07,NSColor.black.withAlphaComponent(0.06))
        NSGraphicsContext.restoreGraphicsState()
        // Near leg over the pelvis.
        leg(hip,knee,foot,0)
        // Neck, collar and head.
        let spine=pose.shoulder-pose.hip
        raLimb(neck,NSPoint(x:head.x+nx*u*0.0,y:head.y+u*0.075),0.1*u,0.088*u,color:raShade(skin,-0.06))
        if style != .bmx {
            let collar=raSpline([T(1.0,-0.07),T(1.1,-0.06),T(1.13,0.0),T(1.1,0.07),T(1.0,0.085),T(0.96,0.0)])
            raFill(collar,style == .sport ? raShade(coat,-0.1) : raShade(coat,-0.14))
        }
        // Arm: deltoid, sleeve with elbow volume, forearm and glove.
        let sleeve = style == .bmx ? skin : coat
        let cuffColor = style == .sport ? NSColor(hex:0x242B33) : style == .motocross ? raShade(coat,-0.3) : coat
        raLimb(shoulder,elbow,0.112*u,0.088*u,bulge:0.014*u,at:0.3,color:style == .sport ? NSColor(hex:0x242B33) : sleeve)
        if style == .bmx {
            let cut=NSPoint(x:shoulder.x+(elbow.x-shoulder.x)*0.5,y:shoulder.y+(elbow.y-shoulder.y)*0.5)
            raLimb(shoulder,cut,0.13*u,0.115*u,color:coat)
        }
        raLimb(elbow,hand,0.092*u,0.064*u,bulge:0.016*u,at:0.25,color:style == .bmx ? skin : (style == .sport ? NSColor(hex:0x242B33) : cuffColor == coat ? coat : coat))
        circle(elbow.x,elbow.y,0.047*u,style == .bmx ? skin : style == .sport ? NSColor(hex:0x242B33) : coat)
        if style == .sport || style == .motocross {
            raStripe(shoulder,elbow,from:0.12,to:0.9,side:1,offset:0.03*u,width:u*0.012,accent)
            let guardA=NSPoint(x:elbow.x-0.012*u,y:elbow.y-0.014*u)
            raFill(raSpline([NSPoint(x:guardA.x-0.035*u,y:guardA.y-0.03*u),NSPoint(x:guardA.x+0.045*u,y:guardA.y-0.03*u),NSPoint(x:guardA.x+0.05*u,y:guardA.y+0.03*u),NSPoint(x:guardA.x-0.03*u,y:guardA.y+0.04*u)]),style == .sport ? NSColor(hex:0x3A424B) : NSColor(hex:0xDADCD6),outline:true,width:0.45)
        } else if style != .bmx {
            line(elbow.x-u*0.04,elbow.y+u*0.012,elbow.x+u*0.035,elbow.y-u*0.018,u*0.007,raShade(coat,-0.34))
        }
        let gloveColor:NSColor
        switch style { case .sport: gloveColor=NSColor(hex:0x3A4149); case .motocross: gloveColor=NSColor(hex:0xE4E1D6); case .bmx: gloveColor=NSColor(hex:0x4A525A); default: gloveColor=NSColor(hex:0x9A7B58) }
        raGlove(hand:hand,wrist:elbow,u:u,style:style,color:gloveColor,accent:raShade(coat,0.05))
        drawHead(center:head,units:u,kind:style,angle:atan2(spine.x,spine.y)*(detached ? 1 : 0.35))
    }
    /// Purchased helmet details, clipped to the shell so they follow its shape.
    private func drawHelmetStyle(shell:NSBezierPath,center h:NSPoint,units u:Double) {
        guard helmetStyle != .standard else { return }
        NSGraphicsContext.saveGraphicsState(); shell.addClip()
        switch helmetStyle {
        case .stripe:
            line(h.x-0.17*u,h.y-0.06*u,h.x+0.15*u,h.y-0.15*u,u*0.036,NSColor.white.withAlphaComponent(0.92))
            line(h.x-0.17*u,h.y-0.03*u,h.x+0.15*u,h.y-0.12*u,u*0.012,jacket)
        case .flames:
            for (i,c) in [0xF26A21,0xF7B32B,0xD9401B].enumerated() {
                let k=Double(i)*0.045,flame=NSBezierPath()
                flame.move(to:NSPoint(x:h.x-0.19*u,y:h.y+(0.075-k)*u)); flame.curve(to:NSPoint(x:h.x-0.01*u,y:h.y+(0.03-k*0.8)*u),controlPoint1:NSPoint(x:h.x-0.13*u,y:h.y+(0.02-k)*u),controlPoint2:NSPoint(x:h.x-0.07*u,y:h.y+(0.07-k)*u))
                flame.curve(to:NSPoint(x:h.x-0.19*u,y:h.y+(0.11-k)*u),controlPoint1:NSPoint(x:h.x-0.06*u,y:h.y+(0.11-k)*u),controlPoint2:NSPoint(x:h.x-0.12*u,y:h.y+(0.115-k)*u)); flame.close()
                NSColor(hex:c).setFill(); flame.fill()
            }
        case .gold:
            line(h.x-0.17*u,h.y-0.06*u,h.x+0.15*u,h.y-0.15*u,u*0.016,NSColor(hex:0xE9B949))
            NSColor(hex:0xE9B949,alpha:0.5).setFill(); NSBezierPath(rect:NSRect(x:h.x-0.02*u,y:h.y-0.095*u,width:0.2*u,height:0.07*u)).fill()
        case .standard: break
        }
        NSGraphicsContext.restoreGraphicsState()
    }
    private func drawHead(center h:NSPoint,units u:Double,kind:BikeKind,angle:Double) {
        NSGraphicsContext.saveGraphicsState()
        let orientation=NSAffineTransform(); orientation.translateX(by:h.x,yBy:h.y); orientation.rotate(byRadians:angle); orientation.translateX(by:-h.x,yBy:-h.y); orientation.concat()
        defer { NSGraphicsContext.restoreGraphicsState() }
        func H(_ x:Double,_ y:Double)->NSPoint { NSPoint(x:h.x+x*u,y:h.y+y*u) }
        func face(_ extra:Double=0) {
            // Human profile: brow, nose, lips and chin; the ear is added by the caller.
            let f=raSpline([H(-0.08,-0.085),H(0.02,-0.115),H(0.09,-0.09),H(0.115,-0.045),H(0.118,-0.0),H(0.15,0.028),H(0.122,0.04),H(0.128,0.062),H(0.115,0.086),H(0.12,0.1),H(0.06,0.135),H(-0.03,0.12),H(-0.085,0.05)])
            raFill(f,skin,angle:60)
            circle(h.x+0.075*u,h.y-0.03*u,0.011*u,ink)
            line(h.x+0.05*u,h.y-0.052*u,h.x+0.105*u,h.y-0.056*u,u*0.007,raShade(skin,-0.55))
            line(h.x+0.1*u,h.y+0.065*u,h.x+0.126*u,h.y+0.064*u,u*0.006,raShade(skin,-0.45))
        }
        if helmetOn && kind == .bmx {
            // Skate-style half shell: face visible, chin strap, vents.
            face()
            let ear=NSBezierPath(ovalIn:NSRect(x:h.x-0.045*u,y:h.y-0.035*u,width:0.05*u,height:0.07*u)); raFill(ear,raShade(skin,-0.06),width:0.4)
            let shell=raSpline([H(-0.15,0.035),H(-0.165,-0.04),H(-0.125,-0.115),H(-0.04,-0.155),H(0.06,-0.15),H(0.14,-0.11),H(0.155,-0.075),H(0.12,-0.062),H(0.03,-0.066),H(-0.03,-0.04),H(-0.06,0.02),H(-0.1,0.065)])
            raFill(shell,helmet,angle:60)
            drawHelmetStyle(shell:shell,center:h,units:u)
            for i in 0..<3 { let x=h.x-0.1*u+Double(i)*0.055*u;line(x,h.y-0.135*u,x+0.025*u,h.y-0.128*u,u*0.014,NSColor(hex:0x28313B)) }
            line(h.x-0.02*u,h.y+0.03*u,h.x+0.03*u,h.y+0.125*u,u*0.011,ink)
            line(h.x+0.07*u,h.y+0.085*u,h.x+0.03*u,h.y+0.125*u,u*0.011,ink)
            raFill(NSBezierPath(roundedRect:NSRect(x:h.x+0.02*u,y:h.y+0.118*u,width:0.035*u,height:0.022*u),xRadius:0.006*u,yRadius:0.006*u),NSColor(hex:0xA9B0B4),outline:true,width:0.35)
            return
        }
        if helmetOn {
            let fit=NSAffineTransform(); fit.translateX(by:h.x,yBy:h.y); fit.scaleX(by:0.8,yBy:0.8); fit.translateX(by:-h.x,yBy:-h.y); fit.concat()
            // Full-face shell: rounded crown, long chin bar, base trim and a rear flare.
            let shellPts=[H(-0.115,0.125),H(-0.165,0.045),H(-0.17,-0.04),H(-0.13,-0.115),H(-0.04,-0.158),H(0.06,-0.152),H(0.145,-0.1),H(0.182,-0.025),H(0.192,0.06),H(0.158,0.13),H(0.075,0.152),H(-0.015,0.142),H(-0.07,0.128)]
            let shell=raSpline(shellPts)
            raFill(shell,helmet,angle:55,strength:1.15,width:0.8)
            NSGraphicsContext.saveGraphicsState(); shell.addClip()
            // Soft shading under the shell and a specular band over the crown.
            line(h.x-0.15*u,h.y+0.12*u,h.x+0.16*u,h.y+0.15*u,u*0.07,NSColor.black.withAlphaComponent(0.16))
            let hl=raSpline([H(-0.11,-0.105),H(-0.03,-0.148),H(0.07,-0.138),H(0.1,-0.12),H(0.0,-0.118),H(-0.07,-0.09)])
            NSColor.white.withAlphaComponent(0.6).setFill(); hl.fill()
            NSGraphicsContext.restoreGraphicsState()
            drawHelmetStyle(shell:shell,center:h,units:u)
            // Rubber base trim running along the lower edge.
            let trim=NSBezierPath(); trim.move(to:H(-0.112,0.122)); trim.curve(to:H(0.15,0.128),controlPoint1:H(-0.03,0.152),controlPoint2:H(0.1,0.162)); trim.lineWidth=u*0.015; NSColor(hex:0x20272C).setStroke(); trim.lineCapStyle = .round; trim.stroke()
            // Visor: a wide tinted shield with a black rubber seal, a reflection and a chrome pivot at the rear.
            let seal=raSpline([H(-0.012,-0.1),H(0.07,-0.13),H(0.15,-0.1),H(0.19,-0.03),H(0.192,0.03),H(0.12,0.047),H(0.05,0.035),H(-0.012,0.0)])
            raFill(seal,NSColor(hex:0x15191D),angle:60,outline:true,width:0.7)
            let port=raSpline([H(0.0,-0.09),H(0.07,-0.118),H(0.142,-0.092),H(0.178,-0.03),H(0.18,0.02),H(0.118,0.034),H(0.054,0.024),H(0.002,-0.008)])
            NSGradient(colors:[NSColor(hex:0x5C7B90),NSColor(hex:0x1E3345),NSColor(hex:0x0B151D)])?.draw(in:port,angle:60)
            NSGraphicsContext.saveGraphicsState(); port.addClip()
            let ref=raSpline([H(0.02,-0.09),H(0.1,-0.115),H(0.165,-0.07),H(0.12,-0.075),H(0.06,-0.065)])
            NSColor.white.withAlphaComponent(0.55).setFill(); ref.fill()
            line(h.x+0.04*u,h.y-0.012*u,h.x+0.15*u,h.y-0.03*u,u*0.007,NSColor.white.withAlphaComponent(0.35))
            NSGraphicsContext.restoreGraphicsState()
            if kind == .motocross {
                // Goggles: a foam frame, lens and the strap running round the shell.
                raFill(port,NSColor(hex:0x1E2A33),angle:60,strength:0.4)
                let lens=raSpline([H(0.04,-0.075),H(0.1,-0.09),H(0.16,-0.05),H(0.165,-0.0),H(0.08,0.01),H(0.035,-0.02)]); raFill(lens,NSColor(hex:0x3D6C8E),angle:60,outline:true,width:0.5)
                line(h.x-0.17*u,h.y-0.05*u,h.x+0.03*u,h.y-0.05*u,u*0.03,raShade(jacket,-0.4))
            }
            // Pivot screw, brow and chin vents, and the chin-bar breather.
            circle(h.x-0.012*u,h.y-0.03*u,0.017*u,NSColor(hex:0xB9C1C5)); circle(h.x-0.012*u,h.y-0.03*u,0.009*u,NSColor(hex:0x5B676E))
            for i in 0..<3 { line(h.x+0.06*u+Double(i)*0.025*u,h.y-0.15*u+Double(i)*0.004*u,h.x+0.07*u+Double(i)*0.025*u,h.y-0.14*u+Double(i)*0.004*u,u*0.006,NSColor(hex:0x3B4652)) }
            raFill(raSpline([H(0.118,0.062),H(0.172,0.056),H(0.178,0.092),H(0.14,0.108),H(0.112,0.09)]),NSColor(hex:0x2B333B),angle:60,width:0.4)
            for i in 0..<3 { line(h.x+0.128*u,h.y+(0.07+Double(i)*0.012)*u,h.x+0.168*u,h.y+(0.066+Double(i)*0.012)*u,u*0.004,NSColor(hex:0x93A1AA)) }
            if kind == .motocross {
                // Extended peak and chin guard.
                let peak=raSpline([H(0.0,-0.14),H(0.09,-0.175),H(0.2,-0.17),H(0.24,-0.15),H(0.12,-0.12),H(0.04,-0.115)]); raFill(peak,helmet)
                raFill(raSpline([H(0.16,0.06),H(0.205,0.07),H(0.2,0.115),H(0.165,0.14)]),raShade(helmet,-0.1),outline:true,width:0.4)
                line(h.x-0.12*u,h.y-0.1*u,h.x+0.03*u,h.y-0.15*u,u*0.02,raShade(jacket,0.1))
            } else if kind == .sport {
                line(h.x-0.13*u,h.y-0.09*u,h.x-0.02*u,h.y-0.14*u,u*0.022,jacket)
            }
        } else {
            face()
            let ear=NSBezierPath(ovalIn:NSRect(x:h.x-0.04*u,y:h.y-0.04*u,width:0.05*u,height:0.075*u)); raFill(ear,raShade(skin,-0.06),width:0.4)
            let hair=raSpline([H(-0.115,0.07),H(-0.15,-0.01),H(-0.12,-0.1),H(-0.04,-0.15),H(0.06,-0.14),H(0.11,-0.095),H(0.03,-0.1),H(-0.03,-0.06),H(-0.06,0.0),H(-0.08,0.05)])
            raFill(hair,NSColor(hex:0x40322E),angle:60)
        }
    }
}
