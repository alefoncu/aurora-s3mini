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
        let street=RiderRig.solve(vehicle:BikeKind.commuter.rig,lean:0)
        let enduro=RiderRig.solve(vehicle:BikeKind.motocross.rig,lean:0)
        let sport=RiderRig.solve(vehicle:BikeKind.sport.rig,lean:0)
        precondition(distance(street.hip,enduro.hip)>0.1)
        precondition(distance(sport.shoulder,enduro.shoulder)>0.1)
        print("RiderRigTests passed: \(tested) poses, exact contacts/fixed bones, continuous lean, pedals, passenger, stunt, invalid inputs.")
    }
}
