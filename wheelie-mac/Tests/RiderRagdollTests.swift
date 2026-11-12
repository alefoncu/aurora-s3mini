import Foundation

@main struct RiderRagdollTests {
    static func distance(_ a:RideVector,_ b:RideVector)->Double { hypot(a.x-b.x,a.y-b.y) }
    static func points(_ p:RiderPose)->[RideVector] { [p.hip,p.shoulder,p.head,p.elbow,p.hand,p.knee,p.foot,p.farKnee,p.farFoot] }
    static func boneError(_ p:RiderPose)->Double {
        [(distance(p.hip,p.shoulder),p.torsoLength),(distance(p.shoulder,p.elbow),p.upperArmLength),
         (distance(p.elbow,p.hand),p.forearmLength),(distance(p.hip,p.knee),p.thighLength),
         (distance(p.knee,p.foot),p.shinLength),(distance(p.hip,p.farKnee),p.thighLength),
         (distance(p.farKnee,p.farFoot),p.shinLength)].map { abs($0.0-$0.1) }.max()!
    }
    static func make(_ kind:BikeKind,route:Int=0,pitch:Double=0.6,velocity:RideVector=RideVector(6,2))->RiderRagdoll {
        RiderRagdoll(pose:RiderRig.solve(vehicle:kind.rig,lean:0.3),origin:RideVector(120,BikePhysics.ground(120,route:route)+1.5),pitch:pitch,velocity:velocity,angularVelocity:1.8,route:route)
    }
    static func main() {
        for kind in BikeKind.allCases { for route in 0...2 {
            let doll=make(kind,route:route),initial=doll.pose
            var highestError=0.0
            for _ in 0..<600 {
                doll.update(1/120)
                let p=doll.pose
                precondition(points(p).allSatisfy{$0.x.isFinite && $0.y.isFinite},"Non-finite ragdoll")
                highestError=max(highestError,boneError(p))
                for (point,radius) in zip(points(p),[0.10,0.09,0.12,0.045,0.045,0.055,0.065,0.055,0.065]) {
                    let slope=BikePhysics.slope(point.x,route:route)
                    let gap=(point.y-BikePhysics.ground(point.x,route:route))/sqrt(1+slope*slope)
                    precondition(gap>=radius-0.003,"Ragdoll contact volume penetrated terrain")
                }
            }
            precondition(boneError(doll.pose)<0.01,"Settled bones must stay within one centimetre")
            precondition(highestError<0.035,"Bone error \(highestError)")
            precondition(doll.pose.hip.y<initial.hip.y-0.4,"Gravity must bring the detached rider down")
            precondition(doll.pose.hip.x>initial.hip.x+0.4,"Initial momentum must move the rider")
            precondition(distance(doll.pose.hand,initial.hand)>0.4,"Hands must detach from the grips")
            let stable=doll.pose
            for dt in [Double.nan,Double.infinity,-1,0] { doll.update(dt) }
            precondition(distance(doll.pose.hip,stable.hip)==0)
        } }
        let slow=make(.motocross),fast=make(.motocross)
        for _ in 0..<90 { slow.update(1/30) }
        for _ in 0..<360 { fast.update(1/120) }
        for (a,b) in zip(points(slow.pose),points(fast.pose)) { precondition(distance(a,b)<0.005,"Frame rates diverged") }
        let capped=make(.sport),tenth=make(.sport)
        capped.update(20); tenth.update(0.1)
        precondition(distance(capped.pose.head,tenth.pose.head)<1e-8,"Stall cap diverged")
        let origin=RideVector(10,3),velocity=RideVector(4,0)
        let local=RiderRig.solve(vehicle:BikeKind.bmx.rig,lean:0)
        let thrown=RiderRagdoll(pose:local,origin:origin,pitch:0,velocity:velocity,angularVelocity:0,route:0)
        precondition(distance(thrown.pose.hip,origin+local.hip)<1e-10,"Initial local/world conversion")
        let start=thrown.pose.hip
        thrown.update(1/120)
        precondition(thrown.pose.hip.x>start.x && thrown.pose.hip.y<start.y,"Initial velocity and gravity")
        print("RiderRagdollTests passed: all vehicle rigs/three routes, gravity and momentum, detached grips, contacts, constrained bones, fps, stall cap and invalid dt.")
    }
}
