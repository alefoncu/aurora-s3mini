import Foundation

/// A planar sprung chassis with two independently moving unsprung wheel masses.
/// All positions are metres, y up. The rendered origin and wheel centres come
/// directly from this model; neither wheel is positioned by an artwork animation.
final class BikePhysics {
    var kind:BikeKind = .commuter { didSet { if oldValue != kind { reset() } } }
    var route=0 { didSet { if oldValue != route { reset() } } }
    var speed=0.0
    var transmission=RideTransmission()
    var suspensionStiffness=1.0 { didSet { suspensionStiffness=suspensionStiffness.isFinite ? max(0.65,min(1.45,suspensionStiffness)) : 1 } }
    var suspensionDamping=1.0 { didSet { suspensionDamping=suspensionDamping.isFinite ? max(0.6,min(1.6,suspensionDamping)) : 1 } }
    var x:Double {
        get { chassisPosition.x }
        set { com.x += newValue-chassisPosition.x; publish() }
    }
    private(set) var chassisPosition=RideVector.zero
    private(set) var pitch=0.0
    var angle:Double { pitch-atan(Self.slope(rearWheelPosition.x,route:route)) }
    var angularVelocity=0.0
    var distance=0.0, wheelieDistance=0.0, bestWheelie=0.0
    private(set) var stoppieDistance=0.0,bestStoppie=0.0
    var isStoppie:Bool { !crashed && !finished && frontContact && !rearContact && angle < -0.16 && speed>0.5 }
    private(set) var height=0.0
    var verticalVelocity:Double { get { bodyV } set { bodyV=newValue } }
    var wheelRotation:Double { rearWheelRotation }
    private(set) var rearWheelPosition=RideVector.zero, frontWheelPosition=RideVector.zero
    private(set) var rearCompression=0.0, frontCompression=0.0
    private(set) var rearContact=true, frontContact=true
    private(set) var rearWheelRotation=0.0, frontWheelRotation=0.0
    private(set) var riderShift=0.0, landingImpact=0.0
    private(set) var throttlePosition=0.0, brakePressure=0.0
    private(set) var frontBrakePressure=0.0, rearBrakePressure=0.0
    /// Signed longitudinal slip: positive is wheelspin, negative is braking slip.
    /// This planar model does not simulate lateral steering or sideways slides.
    private(set) var frontSlip=0.0, rearSlip=0.0
    private(set) var frontWheelRate=0.0, rearWheelRate=0.0
    private(set) var pedalCadence=0.0, pedalPhase=0.0
    private(set) var rearDriveForce=0.0, frontBrakeForce=0.0, rearBrakeForce=0.0
    private(set) var frontNormalLoad=0.0, rearNormalLoad=0.0
    /// Effective longitudinal tyre grip. Road tyres lose more grip off road;
    /// knobby enduro tyres retain their advantage on loose surfaces.
    var frictionCoefficient:Double {
        switch route {
        case 1: return kind == .motocross ? 0.88 : kind == .bmx ? 0.76 : kind.outfitStyle == .sport ? 0.63 : 0.72
        case 2: return kind == .motocross ? 0.70 : kind == .bmx ? 0.60 : kind.outfitStyle == .sport ? 0.48 : 0.57
        case 3: return kind == .motocross ? 0.48 : kind == .bmx ? 0.40 : kind.outfitStyle == .sport ? 0.32 : 0.38
        case 4: return kind == .motocross ? 0.70 : kind == .bmx ? 0.66 : kind.outfitStyle == .sport ? 0.80 : 0.74
        default:return kind == .motocross ? 0.88 : kind == .bmx ? 0.92 : 1.02
        }
    }
    var crashed=false, finished=false
    /// Optional course hazards (puddles that reduce grip); off unless the garage enables obstacles.
    var hazards=false
    /// Anti-lock braking: no braking slip penalty, brake force kept just under the grip limit.
    var absEnabled=false
    /// Air time/rotation of the current flight and the last completed landing.
    private(set) var airTime=0.0, airRotation=0.0
    private(set) var landingSerial=0, lastAirTime=0.0, lastAirHeight=0.0, lastFlips=0
    private var airPeak=0.0, trickHeld=false, angularDamping=1.4
    static let airTrickAcceleration=80.0
    static let routeNames=["Valle","Sierra","Dunas","Nieve","Ciudad lluvia"]
    static var routeCount:Int { routeNames.count }
    var coins=0
    static let finish=1200.0
    private static let h=1.0/480.0
    private var com=RideVector.zero, bodyV=0.0
    private var rearY=0.0,frontY=0.0,rearV=0.0,frontV=0.0
    private var jumpHeld=false,jumpPending=false,jumpCooldown=0.0
    private var frontWasContact=true,rearWasContact=true
    private var settling=false
    /// Speed of an unpowered, unbraked bike rolling backwards down a slope (m/s, >= 0).
    /// The public `speed` stays a non-negative forward speed.
    private var rollback=0.0

    init() { reset() }
    private var rig:VehicleRig { kind.rig }
    private var inertia:Double { rig.sprungMass*(rig.wheelbase*rig.wheelbase*0.22+0.45) }
    private func rotated(_ p:RideVector)->RideVector {
        RideVector(cos(pitch)*p.x-sin(pitch)*p.y,sin(pitch)*p.x+cos(pitch)*p.y)
    }
    private var origin:RideVector { com-rotated(rig.centerOfMass) }
    private func nominal(_ front:Bool)->RideVector { origin+rotated(front ? rig.frontAxle : rig.rearAxle) }
    private func lever(_ front:Bool)->Double { rotated((front ? rig.frontAxle : rig.rearAxle)-rig.centerOfMass).x }
    private func spring(_ front:Bool)->Double {
        let travel=front ? rig.frontTravel : rig.rearTravel
        let load=rig.sprungMass*9.81*(front ? rig.centerOfMass.x/rig.wheelbase : 1-rig.centerOfMass.x/rig.wheelbase)
        return load/(travel*0.30)*suspensionStiffness
    }
    private func damping(_ front:Bool)->Double {
        // Damping is integrated implicitly, so lightweight wheels remain stable
        // even with the high damping rate needed by a motorcycle's sprung mass.
        1.2*sqrt(spring(front)*rig.sprungMass*0.5)*suspensionDamping
    }
    func reset() {
        speed=0; rollback=0; pitch=0; angularVelocity=0; bodyV=0
        airTime=0;airRotation=0;airPeak=0;trickHeld=false;angularDamping=1.4
        riderShift=0; rearWheelRotation=0; frontWheelRotation=0
        throttlePosition=0;brakePressure=0;rearDriveForce=0;frontBrakeForce=0;rearBrakeForce=0
        frontBrakePressure=0;rearBrakePressure=0;frontSlip=0;rearSlip=0;frontWheelRate=0;rearWheelRate=0
        transmission.reset(kind:kind)
        pedalCadence=0;pedalPhase=0
        frontNormalLoad=0;rearNormalLoad=0
        wheelieDistance=0;bestWheelie=0;stoppieDistance=0;bestStoppie=0;distance=0;coins=0
        crashed=false;finished=false;jumpHeld=false;jumpPending=false;jumpCooldown=0
        landingImpact=0; rearContact=true;frontContact=true
        rearWasContact=true;frontWasContact=true
        let sag=(rig.frontTravel+rig.rearTravel)*0.15
        com=RideVector(rig.centerOfMass.x,Self.ground(0,route:route)+rig.wheelRadius-sag+rig.centerOfMass.y)
        rearY=Self.ground(0,route:route)+rig.wheelRadius
        frontY=Self.ground(rig.wheelbase,route:route)+rig.wheelRadius
        rearV=0;frontV=0
        settling=true
        for _ in 0..<480 { integrate(Self.h,throttle:false,brake:false,back:false,forward:false) }
        settling=false
        com.x=rotated(rig.centerOfMass).x
        bodyV=0;rearV=0;frontV=0;angularVelocity=0
        distance=0;wheelieDistance=0;bestWheelie=0;coins=0;landingImpact=0
        publish()
    }
    func update(_ dt:Double,throttle:Bool,brake:Bool,leanBack:Bool,leanForward:Bool,jump:Bool=false,frontBrake:Bool=false,rearBrake:Bool=false,trick:Bool=false) {
        guard dt.isFinite,dt>0,!finished else { return }
        trickHeld=trick && !crashed
        jumpPending=jump && !jumpHeld && !crashed;jumpHeld=jump;landingImpact=0
        var remaining=min(dt,0.25)
        while remaining>0.0000001 && !finished {
            let h=min(Self.h,remaining)
            integrate(h,throttle:!crashed && throttle,brake:crashed || brake,back:!crashed && leanBack,forward:!crashed && leanForward,frontBrake:!crashed && frontBrake,rearBrake:!crashed && rearBrake)
            remaining-=h
        }
        publish()
    }
    private func integrate(_ dt:Double,throttle:Bool,brake:Bool,back:Bool,forward:Bool,frontBrake:Bool=false,rearBrake:Bool=false) {
        let oldX=origin.x
        let targetShift=(back ? -1.0:0)+(forward ? 1.0:0)
        riderShift += (targetShift-riderShift)*min(1,dt*14)
        jumpCooldown=max(0,jumpCooldown-dt)
        if jumpPending {
            if (rearContact || frontContact) && jumpCooldown<=0 && !settling {
                let impulse=kind == .bmx ? 3.2 : kind == .motocross ? 3.1 : 2.6
                bodyV+=impulse;rearV+=impulse;frontV+=impulse;jumpCooldown=0.7
                rearContact=false;frontContact=false
            }
            jumpPending=false
        }
        // Controls are actuators: throttle cable/engine and hydraulic pressure
        // build over time rather than applying a full step force in one frame.
        let throttleTarget=throttle ? 1.0:0.0
        let throttleTime=kind == .bmx ? 0.20 : throttle ? 0.22 : 0.12
        throttlePosition += (throttleTarget-throttlePosition)*(1-exp(-dt/throttleTime))
        let brakeTarget=brake ? 1.0:0.0
        brakePressure += (brakeTarget-brakePressure)*(1-exp(-dt/(brake ? 0.12:0.075)))
        let frontTarget=(brake || frontBrake) ? 1.0 : 0.0,rearTarget=(brake || rearBrake) ? 1.0 : 0.0
        frontBrakePressure += (frontTarget-frontBrakePressure)*(1-exp(-dt/(frontTarget>0 ? 0.12:0.075)))
        rearBrakePressure += (rearTarget-rearBrakePressure)*(1-exp(-dt/(rearTarget>0 ? 0.12:0.075)))
        transmission.update(dt:dt,kind:kind,speed:speed,throttle:throttlePosition,drivenWheelRate:rearWheelRate)
        let rearNom=nominal(false),frontNom=nominal(true)
        let lr=lever(false),lf=lever(true)
        let fr=suspensionForce(false,nominal:rearNom,lever:lr,dt:dt)
        let ff=suspensionForce(true,nominal:frontNom,lever:lf,dt:dt)
        // Ground reaction includes the unsprung wheel weight. Unsupported tyres
        // transmit neither propulsion nor braking, even with an engine running.
        let loadLimit=rig.sprungMass*9.81*2.5
        rearNormalLoad=rearContact ? max(0,min(loadLimit,fr+rig.wheelMass*9.81)) : 0
        frontNormalLoad=frontContact ? max(0,min(loadLimit,ff+rig.wheelMass*9.81)) : 0
        // A slipping tyre has slightly less usable grip than a rolling one.
        // Relaxation prevents instant transitions when a wheel lands or unlocks.
        let rearSurface=hazards ? Self.puddleFactor(rearNom.x) : 1,frontSurface=hazards ? Self.puddleFactor(frontNom.x) : 1
        let rearGrip=frictionCoefficient*rearSurface*rearNormalLoad*(1-0.18*min(1,abs(rearSlip)))
        let frontGrip=frictionCoefficient*frontSurface*frontNormalLoad*(1-0.18*min(1,abs(frontSlip)))
        let ratio=speed/kind.topSpeed
        let engineAcceleration=kind.engineAcceleration
        if kind == .bmx {
            // Fixed 2.8:1 BMX gearing: one crank revolution drives 2.8 wheel
            // revolutions. Cadence grows with road speed, with a launch stroke.
            let targetCadence=min(16,max(3.5,speed/(rig.wheelRadius*2.8)))*throttlePosition
            pedalCadence += (targetCadence-pedalCadence)*(1-exp(-dt/0.18))
            // Forward pedalling lowers the forward pedal in y-up coordinates.
            // The renderer and IK consume this very same phase.
            pedalPhase -= pedalCadence*dt
        }
        // A modest twice-per-revolution power pulse peaks with horizontal cranks;
        // dead centres deliver less leverage without stalling the arcade bicycle.
        let pedalPower=kind == .bmx ? 1+0.18*cos(2*pedalPhase) : 1
        // At target road speed the engine still supplies the force needed to
        // balance rolling/aerodynamic resistance. The old zero-force cutoff
        // made every advertised top speed unreachable even on a flat road.
        let targetResistance=0.13+kind.aerodynamicDrag*kind.topSpeed*kind.topSpeed
        let engineCurve=max(0,engineAcceleration-(engineAcceleration-targetResistance)*ratio*ratio)
        let requestedDrive=rig.sprungMass*engineCurve*throttlePosition*pedalPower*transmission.driveMultiplier
        // One linked brake input, 72% front / 28% rear. Each axle is limited by
        // its own contact and normal load. Lifting the front cannot brake in air.
        let requestedFrontBrake=rig.sprungMass*10.5*0.72*frontBrakePressure
        let requestedRearBrake=rig.sprungMass*10.5*0.28*rearBrakePressure
        // ABS keeps each axle just under its grip limit and never locks.
        let limit=absEnabled ? 0.92 : 1.0
        frontBrakeForce=min(requestedFrontBrake,frontGrip*limit)
        rearBrakeForce=min(requestedRearBrake,rearGrip*limit)
        // Brake override: a held accelerator cannot consume the rear tyre's
        // entire grip budget and defeat braking during a wheelie.
        let driveRequest=requestedDrive*(1-max(frontBrakePressure,rearBrakePressure))
        rearDriveForce=min(driveRequest,max(0,rearGrip-rearBrakeForce))
        func brakingSlip(_ requested:Double,_ grip:Double,_ contact:Bool)->Double {
            guard !absEnabled,contact,speed>0.25,requested>grip,grip>0 else { return 0 }
            return -min(1,(requested/grip-1)*0.85)
        }
        let frontTargetSlip=brakingSlip(requestedFrontBrake,frontGrip,frontContact)
        var rearTargetSlip=brakingSlip(requestedRearBrake,rearGrip,rearContact)
        if rearTargetSlip==0 && throttlePosition>0.05 && rearGrip>0 && driveRequest>rearGrip && rearContact {
            rearTargetSlip=min(2,(driveRequest/rearGrip-1)*0.65)
        }
        if !rearContact && throttle && kind != .bmx { rearTargetSlip=1.2*throttlePosition }
        let relaxation=1-exp(-dt/0.07)
        frontSlip += (frontTargetSlip-frontSlip)*relaxation
        rearSlip += (rearTargetSlip-rearSlip)*relaxation
        // Closed-throttle compression drag belongs to the driven rear tyre;
        // bicycles freewheel. Braking shares the same finite tyre force budget.
        let engineDrag=kind == .bmx ? 0.0 : rig.sprungMass*0.42*(1-throttlePosition)*min(1,speed/2)
        let coastForce=min(engineDrag,max(0,rearGrip-rearDriveForce-rearBrakeForce))
        let drive=rearDriveForce/rig.sprungMass
        let availableBraking=(frontBrakeForce+rearBrakeForce+coastForce)/rig.sprungMass
        let supported=rearContact || frontContact
        let slope=Self.slope(origin.x,route:route)
        // Per-vehicle aerodynamics; drag grows with the square of air speed.
        // Tyre contact and grip still bound propulsion and braking.
        let dragCoefficient=kind.aerodynamicDrag
        let drag=speed>0 ? (supported ? 0.13:0)+dragCoefficient*speed*speed : 0
        let freeAcceleration=drive-drag-(supported ? 9.81*sin(atan(slope)) : 0)
        // Include downhill gravity before limiting brake force, so a stopped
        // vehicle stays held when the available tyre grip supports it.
        let braking=min(availableBraking,max(0,speed/dt+freeAcceleration))
        let horizontalAcceleration=freeAcceleration-braking
        if !settling {
            // Uphill with no drive and too little brake force, the bike rolls
            // backwards instead of sticking to the slope. Any brake holds it.
            let slopePull=supported ? 9.81*sin(atan(slope)) : 0
            let hold=0.13+(frontBrakeForce+rearBrakeForce)/rig.sprungMass
            if rollback>0 || (speed<0.001 && slopePull-drive>hold) {
                let a=slopePull-drive-hold-dragCoefficient*rollback*rollback
                rollback=max(0,min(3,rollback+a*dt));speed=0;com.x-=rollback*dt
            } else {
                speed=max(0,min(kind.topSpeed*1.15,speed+horizontalAcceleration*dt));com.x+=speed*dt
            }
        }
        let totalMass=rig.sprungMass
        bodyV += ((fr+ff)/totalMass-9.81)*dt
        // Drive/brake force acts below the centre of mass. Rider weight shift
        // changes load distribution and therefore unloads/reloads the front wheel.
        // Past ~0.55 rad the driving thrust loses its leverage over the pitch axis
        // (the centre of mass nears the rear contact), so a power wheelie levels
        // off instead of looping; the rider still decides how far to take it.
        let liftT=max(0,min(1,(angle-0.55)/0.4)),liftFade=1-liftT*liftT*(3-2*liftT)
        let transfer=totalMass*(drive*0.95*liftFade-braking*0.72)*(rig.centerOfMass.y+rig.wheelRadius)
        // A deliberate front-brake + forward weight transfer loads the front
        // tyre and unloads the rear through chassis torque, never wheel offsets.
        let stoppieIntent=forward && (brake || frontBrake) && frontContact && speed>1.0 && angle<0.12
        let forwardLever=stoppieIntent ? 0.65 : 0.22+0.58*max(0,min(1,angle/0.35))
        let shiftLever=riderShift>0 ? forwardLever : (kind == .commuter || kind == .bmx ? 0.40 : 0.37)
        let riderTorque = -riderShift*totalMass*9.81*shiftLever
        // Trick flips: with T held in the air the rider's weight shift becomes a
        // strong pitch torque and the usual stabilising damping is relaxed, so
        // angular momentum is conserved. Releasing T brings the damping back.
        let trickAir=trickHeld && !crashed && !rearContact && !frontContact && !settling
        let dampingTarget=trickAir ? 0.18 : (stoppieIntent ? 1.6 : forward ? 3.5 : back ? 0.9 : 1.4)
        angularDamping += (dampingTarget-angularDamping)*min(1,dt*10)
        let airTorque=trickAir ? -riderShift*inertia*Self.airTrickAcceleration : 0
        let torque=fr*lr+ff*lf+transfer+riderTorque+airTorque-angularVelocity*inertia*angularDamping
        angularVelocity += torque/inertia*dt
        pitch += angularVelocity*dt
        if abs(pitch)>Double.pi { pitch -= 2*Double.pi*(pitch/(2*Double.pi)).rounded() }
        com.y += bodyV*dt
        rearV += (-9.81-fr/rig.wheelMass)*dt
        frontV += (-9.81-ff/rig.wheelMass)*dt
        rearY += rearV*dt; frontY += frontV*dt
        projectGround(false,dt:dt); projectGround(true,dt:dt)
        for _ in 0..<3 { constrainTravel(false);constrainTravel(true) }
        projectGround(false,dt:dt); projectGround(true,dt:dt)
        if crashed { projectChassisGround() }
        let rearNow=nominal(false),frontNow=nominal(true)
        let rearFloor=Self.ground(rearNow.x,route:route)+rig.wheelRadius
        let frontFloor=Self.ground(frontNow.x,route:route)+rig.wheelRadius
        rearContact=rearY-rearFloor<0.002 && rearV<=speed*Self.slope(rearNow.x,route:route)+0.08
        frontContact=frontY-frontFloor<0.002 && frontV<=speed*Self.slope(frontNow.x,route:route)+0.08
        if !settling {
            let rollingRear=(rearNow.x-rearWheelPosition.x)/(rig.wheelRadius*dt)
            let rollingFront=(frontNow.x-frontWheelPosition.x)/(rig.wheelRadius*dt)
            rearWheelRate=rollingRear*(1+rearSlip)
            frontWheelRate=rollingFront*(1+frontSlip)
            // Free wheels retain angular momentum in flight. The driven rear
            // can spin faster; unsupported brakes affect spin, never translation.
            if !rearContact { rearWheelRate=max(0,rearWheelRate+(throttle && kind != .bmx ? 12*throttlePosition : -rearBrakePressure*20)*dt) }
            rearWheelRotation += rearWheelRate*dt
            frontWheelRotation += frontWheelRate*dt
            let travelled=max(0,origin.x-oldX)
            if !crashed && rearContact && !frontContact && angle>0.16 && speed>1.2 {
                wheelieDistance+=travelled;bestWheelie=max(bestWheelie,wheelieDistance)
            } else { wheelieDistance=0 }
            if isStoppie { stoppieDistance+=travelled;bestStoppie=max(bestStoppie,stoppieDistance) }
            else { stoppieDistance=0 }
            if !crashed { distance=max(distance,origin.x);coins=Int(max(0,distance)/80) }
            // A bike may rotate freely in the air; it crashes when it touches down badly.
            if !crashed && (rearContact || frontContact) && (angle>1.85 || angle < -1.1) { crashed=true;speed *= 0.35;angularVelocity *= 0.6 }
            if !rearContact && !frontContact {
                airTime+=dt;airRotation+=angularVelocity*dt
                airPeak=max(airPeak,rearY-Self.ground(rearNow.x,route:route)-rig.wheelRadius)
            } else if airTime>0 {
                if !crashed && airTime>=0.25 {
                    lastAirTime=airTime;lastAirHeight=airPeak
                    lastFlips=Int((abs(airRotation)+0.9)/(2*Double.pi))
                    landingSerial+=1
                }
                airTime=0;airRotation=0;airPeak=0
            }
            if distance>=Self.finish { com.x+=Self.finish-origin.x;distance=Self.finish;finished=true;speed=0 }
        }
        rearWheelPosition=RideVector(rearNow.x,rearY);frontWheelPosition=RideVector(frontNow.x,frontY)
        rearWasContact=rearContact;frontWasContact=frontContact
        publish()
    }
    private func suspensionForce(_ front:Bool,nominal:RideVector,lever:Double,dt:Double)->Double {
        let y=front ? frontY:rearY,v=front ? frontV:rearV
        let compression=y-nominal.y
        let relativeV=v-(bodyV+angularVelocity*lever)
        let k=spring(front),c=damping(front)
        let grounded=front ? frontContact:rearContact
        let inv=1/rig.sprungMass+lever*lever/inertia+(grounded ? 0:1/rig.wheelMass)
        return (k*compression+(c+k*dt)*relativeV)/(1+(c*dt+k*dt*dt)*inv)
    }
    private func projectGround(_ front:Bool,dt:Double) {
        let n=nominal(front),floor=Self.ground(n.x,route:route)+rig.wheelRadius
        let groundV=speed*Self.slope(n.x,route:route)
        let y=front ? frontY:rearY, v=front ? frontV:rearV
        if y<floor {
            if !(front ? frontWasContact:rearWasContact) { landingImpact=max(landingImpact,max(0,groundV-v)) }
            if front { frontY=floor;frontV=max(frontV,groundV) }
            else { rearY=floor;rearV=max(rearV,groundV) }
        }
    }
    /// Mechanical bump and droop stops exchange position and velocity through
    /// the same mass/inertia Jacobian; they cannot move a wheel below the road.
    private func constrainTravel(_ front:Bool) {
        let n=nominal(front),y=front ? frontY:rearY
        let compression=y-n.y, travel=front ? rig.frontTravel:rig.rearTravel
        let error:Double
        if compression>travel { error=compression-travel }
        else if compression<0 { error=compression }
        else { return }
        let floor=Self.ground(n.x,route:route)+rig.wheelRadius
        let onFloor=y-floor<0.002
        let invWheel=(error>0 && onFloor) ? 0 : 1/rig.wheelMass
        let l=lever(front),invBody=1/rig.sprungMass+l*l/inertia
        let lambda=error/(invBody+invWheel)
        com.y += lambda/rig.sprungMass
        pitch += lambda*l/inertia
        if front { frontY -= lambda*invWheel } else { rearY -= lambda*invWheel }
        let v=front ? frontV:rearV
        let relative=v-(bodyV+angularVelocity*l)
        if relative*error>0 {
            let impulse=relative/(invBody+invWheel)
            bodyV += impulse/rig.sprungMass;angularVelocity += impulse*l/inertia
            if front { frontV -= impulse*invWheel } else { rearV -= impulse*invWheel }
        }
    }
    private func projectChassisGround() {
        for point in [RideVector(0.18,0.20),RideVector(rig.wheelbase*0.55,0.55),RideVector(0.3,0.65)] {
            let world=origin+rotated(point),floor=Self.ground(world.x,route:route)+0.06
            if world.y<floor {
                com.y+=floor-world.y
                if bodyV<0 { bodyV *= -0.08 }
                angularVelocity *= 0.975
            }
        }
    }
    private func publish() {
        chassisPosition=origin
        let r=nominal(false),f=nominal(true)
        rearWheelPosition=RideVector(r.x,rearY);frontWheelPosition=RideVector(f.x,frontY)
        rearCompression=max(0,min(rig.rearTravel,rearY-r.y))
        frontCompression=max(0,min(rig.frontTravel,frontY-f.y))
        height=max(0,rearY-Self.ground(r.x,route:route)-rig.wheelRadius)
    }
    /// A cone/low obstacle kicks the struck unsprung mass; the suspension and
    /// chassis then determine whether the rider absorbs the hit or topples.
    func strikeObstacle(front:Bool,severity:Double) {
        guard !crashed,!finished,severity.isFinite else { return }
        let hit=max(0,min(1.5,severity))
        if front { frontV += 1.8*hit } else { rearV += 1.3*hit }
        speed *= max(0.5,1-0.18*hit)
        angularVelocity += (front ? 0.35:-0.15)*hit
        landingImpact=max(landingImpact,hit*2)
    }
    /// Fixed course sectors; challenge belongs to world distance, never session time.
    static func difficultyStage(at distance:Double)->Int {
        guard distance.isFinite else { return 0 }
        return max(0,min(3,Int(max(0,min(Self.finish,distance))/300)))
    }
    static func stageTitle(at distance:Double)->String {
        ["Iniciación", "Técnica", "Exigente", "Experto"][difficultyStage(at:distance)]
    }
    enum ObstacleKind { case cone, barrel, log }
    /// Deterministic obstacle mix: cones first, then barrels and low logs as the course gets harder.
    static func obstacleKind(at position:Int)->ObstacleKind {
        let r=(position/5)%6
        switch difficultyStage(at:Double(position)) {
        case 0: return .cone
        case 1: return r<4 ? .cone : .barrel
        case 2: return r<2 ? .cone : r<4 ? .barrel : .log
        default: return r%3 == 0 ? .cone : r%3 == 1 ? .barrel : .log
        }
    }
    /// Wet patches (centres, metres) that cut tyre grip while hazards are enabled.
    static let puddlePositions:[Int] = [140,230,315,455,640,790,905,1055]
    static let puddleHalfLength=4.0
    static func puddleFactor(_ x:Double)->Double {
        guard x.isFinite else { return 1 }
        for p in puddlePositions where abs(x-Double(p))<puddleHalfLength {
            let edge=1-abs(x-Double(p))/puddleHalfLength
            return 1-0.45*min(1,edge*3)
        }
        return 1
    }
    static let obstaclePositions:[Int] = [85,180,275]
        + Array(stride(from:335,through:575,by:60))
        + Array(stride(from:625,through:865,by:40))
        + Array(stride(from:925,through:1175,by:25))

    static func ground(_ x:Double,route:Int=0)->Double {
        guard x.isFinite else { return 0 }
        let t=max(0,min(1,(x-10)/25)),fade=t*t*(3-2*t)
        // Smooth envelopes avoid a height or slope discontinuity at sector signs.
        let progress=max(0,min(1,(x-120)/1000))
        let difficulty=progress*progress*(3-2*progress)
        let roughness=1+difficulty*1.8
        let base:Double
        switch route {
        case 1: base=(1.3*sin((x-10)/24)+0.38*sin((x-10)/8))*(1+0.35*difficulty) + (0.035*sin(x*1.8)+0.022*sin(x*3.1))*roughness
        case 2: base=(0.7*sin((x-10)/34)+0.8*pow(sin((x-10)/17),4))*(1+0.45*difficulty) + 0.028*sin(x*2.4)*roughness
        case 3: base=(0.55*sin((x-10)/52)+0.30*sin((x-10)/21))*(1+0.3*difficulty) + 0.02*sin(x*1.7)*roughness
        case 4: base=0.14*sin((x-10)/44)+0.016*sin(x*1.5)*roughness
        default:base=0.20*sin((x-10)/50)+0.018*sin(x*1.4)*roughness
        }
        // Broad rounded ramps become taller and closer together. Each cosine
        // bump joins the road with zero slope, giving a readable take-off/landing.
        // Wider, lower ramps spaced further apart: every take-off has a long, forgiving landing.
        let paved=route == 0 || route == 4
        let rampSpacing=paved ? 42.0 : 40.0
        let centre=(floor((x-180)/rampSpacing)+0.5)*rampSpacing+180
        let offset=abs(x-centre),halfWidth=paved ? 9.0 : 9.5
        let ramp=offset<halfWidth ? (1+cos(offset/halfWidth*Double.pi))*0.5 : 0
        let rampHeight=(paved ? 0.80 : route == 3 ? 0.75 : 0.90)*difficulty
        return fade*(base+ramp*rampHeight)
    }
    static func slope(_ x:Double,route:Int=0)->Double { (ground(x+0.01,route:route)-ground(x-0.01,route:route))/0.02 }
}
