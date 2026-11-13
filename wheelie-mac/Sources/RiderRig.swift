import Foundation

/// Metre-based skeleton in VehicleRig's y-up frame. Contacts and bone lengths
/// are solved in that frame; rendering only converts its scale and orientation.
struct RiderPose {
    let hip,shoulder,neck,head,elbow,knee,hand,foot,farKnee,farFoot:RideVector
    let upperArmLength,forearmLength,thighLength,shinLength,torsoLength:Double
}

enum RiderRig {
    static let pedalRadius=0.12
    private static let upperArm=0.31,forearm=0.31,thigh=0.40,shin=0.43,torso=0.49
    /// The arms never lock out: the elbow keeps a natural bend (the torso leans in instead).
    private static let elbowSlack=0.04

    /// Solve the body posture first so exact limb chains can reach their real
    /// contacts. This never shortens an endpoint or stretches a forearm/shin.
    static func solve(vehicle:VehicleRig,lean:Double,lift:Double=0,pedalPhase:Double=0,
                      cycling:Bool=false,passenger:Bool=false,stunt:Bool=false,
                      handsOff:Double=0,superman:Double=0)->RiderPose {
        let lean=finiteClamp(lean,-1,1),lift=finiteClamp(lift,0,1)
        // Trick blends: 0 is the normal seated pose, 1 the full trick. Passengers never do them.
        let hands=passenger ? 0 : finiteClamp(handsOff,0,1),fly=passenger ? 0 : finiteClamp(superman,0,1)
        let phase=pedalPhase.isFinite ? pedalPhase : 0
        let pedal=RideVector(cos(phase),sin(phase))*pedalRadius
        var foot:RideVector,farFoot:RideVector
        if cycling && !passenger {
            foot=vehicle.crank+pedal; farFoot=vehicle.crank-pedal
        } else if passenger {
            foot=vehicle.footPeg+RideVector(-0.25,-0.03)
            farFoot=foot+RideVector(-0.035,0.012)
        } else {
            foot=vehicle.footPeg; farFoot=foot+RideVector(-0.035,0.012)
        }
        var hip=vehicle.seat+RideVector((passenger ? -0.22 : 0)+lean*0.035-0.20*fly,
                                      0.08+lift*(passenger ? 0.075 : 0.12)+(stunt ? 0.17 : 0)+0.14*fly)
        if fly>0 {
            // Superman: legs stretched straight out behind, body flat over the seat, hands still on the grips.
            let stretched=hip+RideVector(-0.78,0.10)
            foot=foot*(1-fly)+stretched*fly; farFoot=farFoot*(1-fly)+(stretched+RideVector(-0.035,0.012))*fly
        }
        // A rising pedal makes the rider crouch within both leg reach discs.
        for _ in 0..<5 {
            hip=reachableRoot(hip,target:foot,minimum:0.10,maximum:thigh+shin-0.015)
            hip=reachableRoot(hip,target:farFoot,minimum:0.10,maximum:thigh+shin-0.015)
        }
        let hand:RideVector
        if passenger { hand=vehicle.seat+RideVector(0.10,0.19) }
        else if stunt { hand=hip+RideVector(-0.24,0.53) }
        else { hand=vehicle.grip*(1-hands)+(hip+RideVector(0.34,0.62))*hands }   // hands off: arm raised up and forward
        // Alternate the leg and arm reach constraints so pulling the hip towards the bars never overstretches a leg.
        for _ in 0..<8 {
            hip=reachableRoot(hip,target:hand,minimum:0.05,maximum:torso+upperArm+forearm-elbowSlack)
            hip=reachableRoot(hip,target:foot,minimum:0.10,maximum:thigh+shin-0.015)
            hip=reachableRoot(hip,target:farFoot,minimum:0.10,maximum:thigh+shin-0.015)
        }
        hip=reachableRoot(hip,target:hand,minimum:0.05,maximum:torso+upperArm+forearm-elbowSlack)
        let preferredTilt=(passenger ? -0.10 : vehicle.riderTorsoTilt)+lean*0.52+(cycling ? 0.05 : 0)
        let preferredAngle=(Double.pi/2-preferredTilt)*(1-fly)+0.18*fly
        let shoulder=reachableShoulder(hip:hip,hand:hand,preferredAngle:preferredAngle)
        let spine=(shoulder-hip)/torso
        let neck=shoulder+spine*0.055,head=shoulder+spine*0.20
        return RiderPose(hip:hip,shoulder:shoulder,neck:neck,head:head,
            elbow:joint(shoulder,hand,upperArm,forearm,bend:-1),
            knee:joint(hip,foot,thigh,shin,bend:1),hand:hand,foot:foot,
            farKnee:joint(hip,farFoot,thigh,shin,bend:1),farFoot:farFoot,
            upperArmLength:upperArm,forearmLength:forearm,thighLength:thigh,
            shinLength:shin,torsoLength:torso)
    }
    private static func reachableShoulder(hip:RideVector,hand:RideVector,preferredAngle:Double)->RideVector {
        let offset=hand-hip,d=length(offset),reach=upperArm+forearm-elbowSlack
        guard d>1e-10 else { return hip+RideVector(cos(preferredAngle),sin(preferredAngle))*torso }
        let direction=atan2(offset.y,offset.x)
        // Intersect the torso circle and arm reach disc, then project the
        // preferred lean onto the permitted arc rather than moving the hand.
        let cosine=(d*d+torso*torso-reach*reach)/(2*d*torso)
        let limit=acos(max(-1,min(1,cosine)))
        let desired=atan2(sin(preferredAngle-direction),cos(preferredAngle-direction))
        let angle=direction+max(-limit,min(limit,desired))
        return hip+RideVector(cos(angle),sin(angle))*torso
    }
    private static func reachableRoot(_ root:RideVector,target:RideVector,minimum:Double,maximum:Double)->RideVector {
        let offset=root-target,d=length(offset)
        guard d>1e-10 else { return target+RideVector(0,minimum) }
        return target+offset*(max(minimum,min(maximum,d))/d)
    }
    private static func joint(_ root:RideVector,_ target:RideVector,_ first:Double,_ second:Double,bend:Double)->RideVector {
        let delta=target-root,d=length(delta)
        guard d>1e-12 else { return root+RideVector(first,0) }
        let direction=delta/d
        let along=(first*first-second*second+d*d)/(2*d)
        let across=sqrt(max(0,first*first-along*along))*bend
        return root+direction*along+RideVector(-direction.y,direction.x)*across
    }
    private static func length(_ v:RideVector)->Double { hypot(v.x,v.y) }
    private static func finiteClamp(_ value:Double,_ lower:Double,_ upper:Double)->Double {
        value.isFinite ? max(lower,min(upper,value)) : 0
    }
}
