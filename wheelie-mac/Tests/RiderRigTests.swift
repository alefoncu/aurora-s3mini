import Foundation

@main struct RiderRigTests {
    static func distance(_ a:RideVector,_ b:RideVector)->Double { hypot(a.x-b.x,a.y-b.y) }
    static func close(_ a:Double,_ b:Double,_ description:String) {
        precondition(abs(a-b)<1e-6,"\(description): \(a) != \(b)")
    }
    static func validate(_ p:RiderPose) {
        for v in [p.hip,p.shoulder,p.neck,p.head,p.elbow,p.knee,p.hand,p.foot,p.farKnee,p.farFoot] { precondition(v.x.isFinite && v.y.isFinite) }
        close(distance(p.hip,p.shoulder),p.torsoLength,"Torso")
        close(distance(p.shoulder,p.elbow),p.upperArmLength,"Upper arm")
        close(distance(p.elbow,p.hand),p.forearmLength,"Forearm")
        close(distance(p.hip,p.knee),p.thighLength,"Thigh")
        close(distance(p.knee,p.foot),p.shinLength,"Shin")
        close(distance(p.hip,p.farKnee),p.thighLength,"Far thigh")
        close(distance(p.farKnee,p.farFoot),p.shinLength,"Far shin")
    }
    static func main() {
        var tested=0
        for kind in BikeKind.allCases {
            let rig=kind.rig
            for i in -10...10 { for j in 0...10 { for phaseIndex in 0..<24 {
                let phase=Double(phaseIndex)*Double.pi/12,cycling=kind == .bmx
                let p=RiderRig.solve(vehicle:rig,lean:Double(i)/10,lift:Double(j)/10,pedalPhase:phase,cycling:cycling)
                validate(p); close(distance(p.hand,rig.grip),0,"Hands meet grips")
                let target=cycling ? rig.crank+RideVector(cos(phase),sin(phase))*RiderRig.pedalRadius : rig.footPeg
                close(distance(p.foot,target),0,"Feet meet pegs/pedals"); tested += 1
            } } }
            var previous=RiderRig.solve(vehicle:rig,lean:-1)
            for i in 1...400 {
                let p=RiderRig.solve(vehicle:rig,lean:-1+Double(i)/200)
                precondition(distance(previous.shoulder,p.shoulder)<0.02,"Shoulder discontinuity")
                precondition(distance(previous.elbow,p.elbow)<0.02,"Elbow discontinuity")
                previous=p
            }
            for passenger in [false,true] { for stunt in [false,true] { for lift in [0.0,0.5,1.0] {
                validate(RiderRig.solve(vehicle:rig,lean:0.8,lift:lift,passenger:passenger,stunt:stunt))
            } } }
            validate(RiderRig.solve(vehicle:rig,lean:.nan,lift:.infinity,pedalPhase:.nan))
        }
        // Trick poses: exact bones throughout, continuous blends, and recognisable end poses.
        for kind in BikeKind.allCases {
            let rig=kind.rig
            let plain=RiderRig.solve(vehicle:rig,lean:0.3,lift:0.2,cycling:kind == .bmx)
            let zero=RiderRig.solve(vehicle:rig,lean:0.3,lift:0.2,cycling:kind == .bmx,handsOff:0,superman:0)
            close(distance(plain.hand,zero.hand),0,"Zero blend equals the normal pose"); close(distance(plain.hip,zero.hip),0,"Zero blend hip")
            var previous=RiderRig.solve(vehicle:rig,lean:0.3,lift:0.2,cycling:kind == .bmx)
            for kindOfTrick in 0..<2 { for i in 0...200 {
                let b=Double(i)/200
                let p=RiderRig.solve(vehicle:rig,lean:0.3,lift:0.2,cycling:kind == .bmx,handsOff:kindOfTrick == 0 ? b : 0,superman:kindOfTrick == 1 ? b : 0)
                validate(p)
                if i == 0 { previous=p }
                for (a,c,name) in [(previous.shoulder,p.shoulder,"shoulder"),(previous.elbow,p.elbow,"elbow"),(previous.knee,p.knee,"knee"),(previous.foot,p.foot,"foot"),(previous.hand,p.hand,"hand")] {
                    precondition(distance(a,c)<0.03,"\(name) jumps while blending a trick on \(kind): \(distance(a,c))")
                }
                previous=p
            } }
            let off=RiderRig.solve(vehicle:rig,lean:0,handsOff:1)
            precondition(distance(off.hand,rig.grip)>0.3 && off.hand.y>off.shoulder.y-0.1,"Hands off must leave the bars and rise: \(kind)")
            let fly=RiderRig.solve(vehicle:rig,lean:0,superman:1)
            close(distance(fly.hand,rig.grip),0,"Superman keeps the hands on the grips")
            precondition(fly.foot.x<fly.hip.x-0.55 && distance(fly.foot,rig.footPeg)>0.3,"Superman stretches the legs behind: \(kind)")
            precondition(abs(fly.shoulder.y-fly.hip.y)<0.3,"Superman keeps the torso nearly flat: \(kind) \(fly.shoulder.y-fly.hip.y)")
            let pillion=RiderRig.solve(vehicle:rig,lean:0,passenger:true,handsOff:1,superman:1)
            close(distance(pillion.hand,RiderRig.solve(vehicle:rig,lean:0,passenger:true).hand),0,"Passengers ignore trick poses")
            validate(RiderRig.solve(vehicle:rig,lean:0,handsOff:.nan,superman:.infinity))
        }
        let street=RiderRig.solve(vehicle:BikeKind.commuter.rig,lean:0)
        let enduro=RiderRig.solve(vehicle:BikeKind.motocross.rig,lean:0)
        let sport=RiderRig.solve(vehicle:BikeKind.sport.rig,lean:0)
        precondition(distance(street.hip,enduro.hip)>0.1)
        precondition(distance(sport.shoulder,enduro.shoulder)>0.1)
        print("RiderRigTests passed: \(tested) poses, exact contacts/fixed bones, continuous lean, pedals, passenger, stunt, hands-off and superman blends, invalid inputs.")
    }
}
