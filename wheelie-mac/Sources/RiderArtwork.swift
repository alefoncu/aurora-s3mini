import Cocoa

extension RideRenderer {
    private func raPoint(_ v:RideVector,_ u:Double)->NSPoint { NSPoint(x:v.x*u,y:-v.y*u) }
    private func raShade(_ color:NSColor,_ amount:Double)->NSColor {
        color.blended(withFraction:abs(amount),of:amount>=0 ? .white : .black) ?? color
    }
    private func raFill(_ shape:NSBezierPath,_ base:NSColor,angle:Double=25,outline:Bool=true) {
        NSGradient(colors:[raShade(base,0.22),base,raShade(base,-0.20)])?.draw(in:shape,angle:angle)
        if outline { ink.withAlphaComponent(0.68).setStroke(); shape.lineWidth=0.7; shape.lineJoinStyle = .round; shape.stroke() }
    }
    private func raLimb(_ a:NSPoint,_ b:NSPoint,width:Double,color:NSColor) {
        let dx=b.x-a.x,dy=b.y-a.y,l=max(0.01,hypot(dx,dy))
        NSGraphicsContext.saveGraphicsState(); let t=NSAffineTransform(); t.translateX(by:a.x,yBy:a.y); t.rotate(byRadians:atan2(dy,dx)); t.concat()
        let shape=NSBezierPath(roundedRect:NSRect(x:-width*0.4,y:-width*0.5,width:l+width*0.8,height:width),xRadius:width*0.46,yRadius:width*0.46)
        raFill(shape,color,angle:90)
        let seam=NSBezierPath(); seam.move(to:NSPoint(x:width*0.25,y:-width*0.28)); seam.curve(to:NSPoint(x:l-width*0.1,y:-width*0.25),controlPoint1:NSPoint(x:l*0.35,y:-width*0.43),controlPoint2:NSPoint(x:l*0.6,y:-width*0.30)); seam.lineWidth=0.55; NSColor.white.withAlphaComponent(0.22).setStroke(); seam.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }
    private func raBoot(_ at:NSPoint,u:Double,kind:BikeKind) {
        let mx=kind == .motocross
        if kind == .commuter || kind == .bmx {
            let shoe=NSBezierPath()
            shoe.move(to:NSPoint(x:at.x-0.075*u,y:at.y-0.065*u))
            shoe.line(to:NSPoint(x:at.x+0.035*u,y:at.y-0.065*u))
            shoe.curve(to:NSPoint(x:at.x+0.17*u,y:at.y-0.018*u),controlPoint1:NSPoint(x:at.x+0.09*u,y:at.y-0.02*u),controlPoint2:NSPoint(x:at.x+0.14*u,y:at.y-0.05*u))
            shoe.line(to:NSPoint(x:at.x+0.17*u,y:at.y+0.006*u));shoe.line(to:NSPoint(x:at.x-0.075*u,y:at.y+0.006*u));shoe.close()
            raFill(shoe,NSColor(hex:kind == .bmx ? 0x292D33 : 0x716658))
            line(at.x-0.075*u,at.y,at.x+0.165*u,at.y,u*0.02,NSColor(hex:0xDDD9CF))
            for i in 0..<3 { let x=at.x+Double(i)*u*0.025;line(x,at.y-u*0.045,x+u*0.015,at.y-u*0.023,u*0.008,.white) }
            return
        }
        let p=NSBezierPath()
        p.move(to:NSPoint(x:at.x-0.075*u,y:at.y-0.12*u))
        p.line(to:NSPoint(x:at.x+0.028*u,y:at.y-0.12*u))
        p.curve(to:NSPoint(x:at.x+0.07*u,y:at.y-0.045*u),controlPoint1:NSPoint(x:at.x+0.03*u,y:at.y-0.09*u),controlPoint2:NSPoint(x:at.x+0.04*u,y:at.y-0.05*u))
        p.curve(to:NSPoint(x:at.x+0.16*u,y:at.y-0.02*u),controlPoint1:NSPoint(x:at.x+0.12*u,y:at.y-0.04*u),controlPoint2:NSPoint(x:at.x+0.16*u,y:at.y-0.04*u))
        p.line(to:NSPoint(x:at.x+0.16*u,y:at.y)); p.line(to:NSPoint(x:at.x-0.08*u,y:at.y)); p.close()
        raFill(p,mx ? NSColor(hex:0xEAE6DA) : NSColor(hex:0x3A414B))
        line(at.x-0.075*u,at.y,at.x+0.155*u,at.y,0.018*u,NSColor(hex:0x131C24))
        if mx { for i in 0..<3 { let y=at.y-(0.045+Double(i)*0.026)*u; line(at.x-0.065*u,y,at.x+0.02*u,y,0.012*u,NSColor(hex:0x6C7173)) } }
        else { line(at.x-0.035*u,at.y-0.08*u,at.x+0.055*u,at.y-0.035*u,0.014*u,silver) }
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
        case .commuter:jeans=NSColor(hex:0x354A62)
        case .motocross:jeans=raShade(coat,-0.42)
        case .sport:jeans=dark
        case .bmx:jeans=NSColor(hex:0x42484C)
        default:jeans=NSColor(hex:0x354A62)
        }
        // Far leg is intentionally darker, retaining depth while preserving the rig.
        raLimb(hip,farKnee,width:u*0.123,color:raShade(jeans,-0.25)); raLimb(farKnee,farFoot,width:u*0.096,color:raShade(jeans,-0.25)); raBoot(farFoot,u:u,kind:style)
        // The torso is a fitted, curved cloth volume aligned with the physical spine.
        let dx=shoulder.x-hip.x,dy=shoulder.y-hip.y,l=max(0.001,hypot(dx,dy)),nx = -dy/l,ny=dx/l
        func off(_ p:NSPoint,_ k:Double)->NSPoint { NSPoint(x:p.x+nx*k*u,y:p.y+ny*k*u) }
        let torso=NSBezierPath(); torso.move(to:off(hip,-0.11)); torso.curve(to:off(shoulder,-0.105),controlPoint1:off(NSPoint(x:hip.x+dx*0.4,y:hip.y+dy*0.4),-0.145),controlPoint2:off(shoulder,-0.15))
        torso.curve(to:off(shoulder,0.105),controlPoint1:NSPoint(x:shoulder.x+dx/l*u*0.10-nx*u*0.08,y:shoulder.y+dy/l*u*0.10-ny*u*0.08),controlPoint2:NSPoint(x:shoulder.x+dx/l*u*0.10+nx*u*0.08,y:shoulder.y+dy/l*u*0.10+ny*u*0.08))
        torso.curve(to:off(hip,0.11),controlPoint1:off(shoulder,0.12),controlPoint2:off(NSPoint(x:hip.x+dx*0.25,y:hip.y+dy*0.25),0.115)); torso.close()
        raFill(torso,style == .sport ? dark : coat,angle:20)
        NSGraphicsContext.saveGraphicsState();torso.addClip()
        if style == .motocross || style == .sport {
            // Sewn panels follow the spine and remain inside the garment.
            line(hip.x,hip.y,shoulder.x,shoulder.y,u*0.095,coat)
            line(hip.x+nx*u*0.07,hip.y+ny*u*0.07,shoulder.x+nx*u*0.07,shoulder.y+ny*u*0.07,u*0.025,accent)
            if style == .motocross {
                for f in [0.48,0.60,0.72] { let x=hip.x+dx*f,y=hip.y+dy*f;line(x-nx*u*0.09,y-ny*u*0.09,x+nx*u*0.09,y+ny*u*0.09,u*0.018,dark) }
            }
        } else if style == .commuter {
            let x=hip.x+dx*0.68,y=hip.y+dy*0.68
            line(x-nx*u*0.065,y-ny*u*0.065,x+nx*u*0.07,y+ny*u*0.07,u*0.017,NSColor(hex:0xD3DADE))
            line(x+nx*u*0.08,y+ny*u*0.08,hip.x+dx*0.45+nx*u*0.08,hip.y+dy*0.45+ny*u*0.08,u*0.008,dark)
        } else {
            let x=hip.x+dx*0.65,y=hip.y+dy*0.65
            circle(x,y,u*0.055,NSColor(hex:0xE5DED0))
            line(x-u*0.025,y,x+u*0.025,y,u*0.012,coat)
        }
        NSGraphicsContext.restoreGraphicsState()
        line(hip.x-nx*u*0.07,hip.y-ny*u*0.07,shoulder.x-nx*u*0.07,shoulder.y-ny*u*0.07,u*0.028,raShade(coat,0.35))
        line(hip.x+nx*u*0.065,hip.y+ny*u*0.065,shoulder.x+nx*u*0.07,shoulder.y+ny*u*0.07,u*0.008,raShade(coat,-0.35))
        // Jeans have a knee volume and boot cuff, not a uniform stick silhouette.
        raLimb(hip,knee,width:u*0.14,color:jeans)
        raLimb(knee,foot,width:u*0.106,color:raShade(jeans,-0.05))
        ellipse(knee.x-u*0.061,knee.y-u*0.055,u*0.122,u*0.11,raShade(jeans,0.07))
        line(hip.x-0.023*u,hip.y+0.025*u,knee.x-0.025*u,knee.y-0.01*u,u*0.009,NSColor(hex:0x91A0AF,alpha:0.55))
        if style == .sport || style == .motocross || style == .bmx {
            let pad=NSBezierPath(roundedRect:NSRect(x:knee.x-u*0.045,y:knee.y-u*0.055,width:u*0.09,height:u*0.11),xRadius:u*0.025,yRadius:u*0.025)
            raFill(pad,dark)
            line(knee.x-u*0.025,knee.y,knee.x+u*0.025,knee.y,u*0.012,style == .bmx ? NSColor(hex:0x9A9C98) : accent)
        }
        raBoot(foot,u:u,kind:style)
        // A jacket sleeve, visible elbow protector and forearm with local highlights.
        if style == .bmx {
            raLimb(shoulder,elbow,width:u*0.086,color:skin)
            let cuff=NSPoint(x:shoulder.x+(elbow.x-shoulder.x)*0.48,y:shoulder.y+(elbow.y-shoulder.y)*0.48)
            raLimb(shoulder,cuff,width:u*0.12,color:coat)
        } else { raLimb(shoulder,elbow,width:u*0.108,color:coat) }
        raLimb(elbow,hand,width:u*(style == .bmx ? 0.070 : 0.087),color:style == .bmx ? skin : style == .sport ? dark : coat)
        if style == .sport || style == .motocross {
            let x=elbow.x+(hand.x-elbow.x)*0.75,y=elbow.y+(hand.y-elbow.y)*0.75
            line(x,y,hand.x,hand.y,u*0.105,dark)
            line(shoulder.x,shoulder.y,elbow.x,elbow.y,u*0.022,accent)
        }
        ellipse(elbow.x-u*0.043,elbow.y-u*0.038,u*0.086,u*0.076,raShade(coat,-0.13))
        let glove=NSBezierPath(ovalIn:NSRect(x:hand.x-u*0.043,y:hand.y-u*0.036,width:u*0.086,height:u*0.072)); raFill(glove,NSColor(hex:0x28313B))
        line(hand.x-u*0.01,hand.y-u*0.018,hand.x+u*0.026,hand.y-u*0.013,u*0.008,NSColor(hex:0x8C959C))
        raLimb(neck,NSPoint(x:head.x,y:head.y+u*0.06),width:u*0.07,color:skin)
        let spine=pose.shoulder-pose.hip
        drawHead(center:head,units:u,kind:style,angle:atan2(spine.x,spine.y)*(detached ? 1 : 0.35))
    }
    private func drawHead(center h:NSPoint,units u:Double,kind:BikeKind,angle:Double) {
        NSGraphicsContext.saveGraphicsState()
        let orientation=NSAffineTransform(); orientation.translateX(by:h.x,yBy:h.y); orientation.rotate(byRadians:angle); orientation.translateX(by:-h.x,yBy:-h.y); orientation.concat()
        defer { NSGraphicsContext.restoreGraphicsState() }
        if helmetOn && kind == .bmx {
            // Skate-style half shell leaves the face visible, with real chin straps.
            let face=NSBezierPath(ovalIn:NSRect(x:h.x-u*0.09,y:h.y-u*0.095,width:u*0.19,height:u*0.22));raFill(face,skin)
            let shell=NSBezierPath();shell.move(to:NSPoint(x:h.x-u*0.13,y:h.y+u*0.01))
            shell.curve(to:NSPoint(x:h.x+u*0.13,y:h.y-u*0.035),controlPoint1:NSPoint(x:h.x-u*0.19,y:h.y-u*0.20),controlPoint2:NSPoint(x:h.x+u*0.14,y:h.y-u*0.19))
            shell.line(to:NSPoint(x:h.x+u*0.13,y:h.y-u*0.005));shell.line(to:NSPoint(x:h.x-u*0.13,y:h.y+u*0.035));shell.close();raFill(shell,helmet)
            for i in 0..<3 { let x=h.x-u*0.075+Double(i)*u*0.055;line(x,h.y-u*0.095,x+u*0.022,h.y-u*0.105,u*0.013,NSColor(hex:0x28313B)) }
            line(h.x-u*0.08,h.y+u*0.015,h.x+u*0.01,h.y+u*0.105,u*0.012,ink)
            line(h.x+u*0.08,h.y,h.x+u*0.01,h.y+u*0.105,u*0.012,ink)
            circle(h.x+u*0.073,h.y+u*0.03,u*0.012,ink)
            return
        }
        if helmetOn {
            let shell=NSBezierPath()
            shell.move(to:NSPoint(x:h.x-0.135*u,y:h.y+0.045*u))
            shell.curve(to:NSPoint(x:h.x+0.065*u,y:h.y-0.135*u),controlPoint1:NSPoint(x:h.x-0.18*u,y:h.y-0.11*u),controlPoint2:NSPoint(x:h.x-0.04*u,y:h.y-0.18*u))
            shell.curve(to:NSPoint(x:h.x+0.152*u,y:h.y-0.012*u),controlPoint1:NSPoint(x:h.x+0.13*u,y:h.y-0.12*u),controlPoint2:NSPoint(x:h.x+0.13*u,y:h.y-0.055*u))
            shell.line(to:NSPoint(x:h.x+0.12*u,y:h.y+0.095*u))
            shell.curve(to:NSPoint(x:h.x-0.135*u,y:h.y+0.045*u),controlPoint1:NSPoint(x:h.x+0.025*u,y:h.y+0.16*u),controlPoint2:NSPoint(x:h.x-0.105*u,y:h.y+0.14*u)); shell.close()
            raFill(shell,helmet,angle:45)
            // Visor follows the rounded shell and gains two reflected light bands.
            let visor=NSBezierPath(); visor.move(to:NSPoint(x:h.x+0.005*u,y:h.y-0.077*u)); visor.curve(to:NSPoint(x:h.x+0.143*u,y:h.y-0.065*u),controlPoint1:NSPoint(x:h.x+0.055*u,y:h.y-0.09*u),controlPoint2:NSPoint(x:h.x+0.11*u,y:h.y-0.085*u)); visor.line(to:NSPoint(x:h.x+0.165*u,y:h.y-0.006*u)); visor.curve(to:NSPoint(x:h.x+0.004*u,y:h.y+0.018*u),controlPoint1:NSPoint(x:h.x+0.11*u,y:h.y+0.025*u),controlPoint2:NSPoint(x:h.x+0.06*u,y:h.y+0.035*u)); visor.close(); raFill(visor,NSColor(hex:0x1B2C3E),angle:90)
            line(h.x+0.023*u,h.y-0.057*u,h.x+0.112*u,h.y-0.058*u,u*0.009,NSColor(hex:0x8CBBD1,alpha:0.8))
            line(h.x+0.03*u,h.y-0.041*u,h.x+0.09*u,h.y-0.04*u,u*0.004,NSColor.white.withAlphaComponent(0.32))
            let chin=NSBezierPath(); chin.move(to:NSPoint(x:h.x+0.015*u,y:h.y+0.024*u)); chin.line(to:NSPoint(x:h.x+0.145*u,y:h.y+0.013*u)); chin.line(to:NSPoint(x:h.x+0.126*u,y:h.y+0.077*u)); chin.line(to:NSPoint(x:h.x+0.028*u,y:h.y+0.106*u)); chin.close(); raFill(chin,helmet)
            line(h.x+0.066*u,h.y+0.062*u,h.x+0.108*u,h.y+0.051*u,u*0.011,NSColor(hex:0x3B4652))
            line(h.x-0.108*u,h.y-0.063*u,h.x-0.037*u,h.y-0.12*u,u*0.026,body)
            line(h.x-0.115*u,h.y+0.051*u,h.x-0.08*u,h.y+0.088*u,u*0.012,NSColor(hex:0x5D6368))
            ellipse(h.x-0.106*u,h.y-0.115*u,u*0.075,u*0.025,NSColor.white.withAlphaComponent(0.24))
            if kind == .motocross {
                let peak=NSBezierPath();peak.move(to:NSPoint(x:h.x-u*0.07,y:h.y-u*0.12));peak.line(to:NSPoint(x:h.x+u*0.21,y:h.y-u*0.105));peak.line(to:NSPoint(x:h.x+u*0.19,y:h.y-u*0.075));peak.line(to:NSPoint(x:h.x-u*0.06,y:h.y-u*0.09));peak.close();raFill(peak,helmet)
                line(h.x-u*0.13,h.y-u*0.025,h.x+u*0.005,h.y-u*0.025,u*0.035,raShade(jacket,-0.40))
                visor.lineWidth=u*0.017;raShade(jacket,0.28).setStroke();visor.stroke()
                line(h.x+u*0.07,h.y+u*0.087,h.x+u*0.155,h.y+u*0.065,u*0.025,helmet)
            } else if kind == .sport {
                line(h.x-u*0.11,h.y-u*0.07,h.x-u*0.01,h.y-u*0.125,u*0.023,jacket)
            }
        } else {
            let face=NSBezierPath(ovalIn:NSRect(x:h.x-u*0.09,y:h.y-u*0.12,width:u*0.19,height:u*0.245)); raFill(face,skin)
            let hair=NSBezierPath(); hair.move(to:NSPoint(x:h.x-u*0.09,y:h.y)); hair.curve(to:NSPoint(x:h.x+u*0.1,y:h.y-u*0.065),controlPoint1:NSPoint(x:h.x-u*0.15,y:h.y-u*0.20),controlPoint2:NSPoint(x:h.x+u*0.10,y:h.y-u*0.18)); hair.line(to:NSPoint(x:h.x+u*0.025,y:h.y-u*0.035)); hair.line(to:NSPoint(x:h.x-u*0.015,y:h.y+u*0.02)); hair.close(); raFill(hair,NSColor(hex:0x40322E))
            circle(h.x+u*0.065,h.y-u*0.01,u*0.014,ink)
        }
    }
}
