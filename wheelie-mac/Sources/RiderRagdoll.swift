import Foundation

/// A detached, world-space rider. Bone constraints transfer momentum between
/// particles while contacts and friction let the figure tumble and settle.
final class RiderRagdoll {
    private struct Particle {
        var position:RideVector
        var velocity:RideVector
        let inverseMass:Double
        let radius:Double
    }
    private struct Bone {
        let a:Int,b:Int
        let length:Double
        let stiffness:Double
    }
    private var particles:[Particle]
    private let bones:[Bone]
    private let template:RiderPose
    private let route:Int
    private static let step=1.0/240.0

    init(pose:RiderPose,origin:RideVector,pitch:Double,velocity:RideVector,angularVelocity:Double,route:Int) {
        self.template=pose
        self.route=route
        let pitch=pitch.isFinite ? pitch : 0
        let origin=Self.finite(origin),velocity=Self.finite(velocity)
        let omega=angularVelocity.isFinite ? max(-30,min(30,angularVelocity)) : 0
        let c=cos(pitch),s=sin(pitch)
        let local=[pose.hip,pose.shoulder,pose.head,pose.elbow,pose.hand,pose.knee,pose.foot,pose.farKnee,pose.farFoot]
        let masses=[9.0,8,4,1.2,0.6,2.5,1.2,2.5,1.2]
        let radii=[0.10,0.09,0.15,0.045,0.045,0.055,0.065,0.055,0.065]
        particles=local.enumerated().map { i,v in
            let rotated=RideVector(v.x*c-v.y*s,v.x*s+v.y*c)
            return Particle(position:origin+rotated,
                velocity:velocity+RideVector(-rotated.y,rotated.x)*omega,
                inverseMass:1/masses[i],radius:radii[i])
        }
        let pairs=[(0,1),(1,2),(1,3),(3,4),(0,5),(5,6),(0,7),(7,8),(0,2)]
        bones=pairs.map { a,b in
            Bone(a:a,b:b,length:Self.length(local[b]-local[a]),stiffness:(a==0 && b==2) ? 0.7 : 1)
        }
    }

    var pose:RiderPose {
        let p=particles.map(\.position)
        return RiderPose(hip:p[0],shoulder:p[1],neck:p[1]+(p[2]-p[1])*0.275,head:p[2],
            elbow:p[3],knee:p[5],hand:p[4],foot:p[6],farKnee:p[7],farFoot:p[8],
            upperArmLength:template.upperArmLength,forearmLength:template.forearmLength,
            thighLength:template.thighLength,shinLength:template.shinLength,torsoLength:template.torsoLength)
    }

    func update(_ dt:Double) {
        guard dt.isFinite,dt>0 else { return }
        var remaining=min(dt,0.1)
        while remaining>1e-9 {
            let h=min(Self.step,remaining)
            integrate(h)
            remaining-=h
        }
    }

    private func integrate(_ h:Double) {
        let previous=particles.map(\.position)
        var incoming=[RideVector](); incoming.reserveCapacity(particles.count)
        for i in particles.indices {
            particles[i].velocity *= exp(-0.32*h)
            particles[i].velocity.y -= 9.81*h
            incoming.append(particles[i].velocity)
            particles[i].position += particles[i].velocity*h
        }
        var contacts=Array(repeating:false,count:particles.count)
        // Alternating contact and bone passes avoids projecting the limbs through
        // the ground after their endpoints have already been separated.
        for _ in 0..<16 {
            for bone in bones {
                let delta=particles[bone.b].position-particles[bone.a].position
                let d=Self.length(delta)
                guard d>1e-10 else { continue }
                let wa=particles[bone.a].inverseMass,wb=particles[bone.b].inverseMass
                let correction=delta*((d-bone.length)/d*bone.stiffness/(wa+wb))
                particles[bone.a].position += correction*wa
                particles[bone.b].position -= correction*wb
            }
            for i in particles.indices {
                let p=particles[i].position
                let slope=BikePhysics.slope(p.x,route:route)
                let normal=RideVector(-slope,1)/sqrt(1+slope*slope)
                let gap=(p.y-BikePhysics.ground(p.x,route:route))*normal.y
                let penetration=particles[i].radius-gap
                if penetration>0 {
                    particles[i].position += normal*penetration
                    contacts[i]=true
                }
            }
        }
        for i in particles.indices {
            var v=(particles[i].position-previous[i])/h
            if contacts[i] {
                let slope=BikePhysics.slope(particles[i].position.x,route:route)
                let normal=RideVector(-slope,1)/sqrt(1+slope*slope)
                let tangent=RideVector(normal.y,-normal.x)
                let originalNormal=Self.dot(incoming[i],normal)
                let correctedNormal=Self.dot(v,normal)
                let bounce=originalNormal < -1.2 ? -originalNormal*0.06 : 0
                // Remove inward contact velocity and apply a small impact bounce.
                v += normal*(max(bounce,correctedNormal)-correctedNormal)
                var parallel=Self.dot(v,tangent)
                let friction=0.85*9.81*h
                parallel=parallel>0 ? max(0,parallel-friction) : min(0,parallel+friction)
                v=normal*Self.dot(v,normal)+tangent*parallel
            }
            // Damping and the position constraints dissipate impacts; this guard
            // only bounds a pathological initial impulse or extreme collision.
            let magnitude=Self.length(v)
            particles[i].velocity=magnitude>80 ? v*(80/magnitude) : v
        }
    }
    private static func dot(_ a:RideVector,_ b:RideVector)->Double { a.x*b.x+a.y*b.y }
    private static func length(_ v:RideVector)->Double { hypot(v.x,v.y) }
    private static func finite(_ v:RideVector)->RideVector { RideVector(v.x.isFinite ? v.x : 0,v.y.isFinite ? v.y : 0) }
}
