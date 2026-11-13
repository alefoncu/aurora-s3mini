import Foundation

typealias RideVector = SIMD2<Double>

/// One geometry shared by physics, artwork and rider contacts. Metres, y upwards.
struct VehicleRig {
    let riderTorsoTilt:Double
    let wheelbase:Double
    let wheelRadius:Double
    let drawingUnitsPerMetre:Double
    let centerOfMass:RideVector
    let rearSuspensionMount:RideVector
    let frontSuspensionMount:RideVector
    let swingPivot:RideVector
    let seat:RideVector
    let grip:RideVector
    let footPeg:RideVector
    let crank:RideVector
    let frontTravel:Double
    let rearTravel:Double
    let sprungMass:Double
    let wheelMass:Double
    var frontAxle:RideVector { RideVector(wheelbase,0) }
    var rearAxle:RideVector { .zero }
}

enum BikeKind:String,CaseIterable {
    case commuter,motocross,sport,bmx,scooter,scrambler,trials,hyperbike,cruiser,electric
    var title:String {
        switch self { case .commuter:return "Street 125"; case .motocross:return "Enduro 250"; case .sport:return "Sport 600"; case .bmx:return "BMX";case .scooter:return "Scooter 80";case .scrambler:return "Scrambler 400";case .trials:return "Trial 200";case .hyperbike:return "Hyper R 1000";case .cruiser:return "Cruiser 750";case .electric:return "Volt E-8" }
    }
    var subtitle:String {
        switch self {
        case .commuter:return "Uso diario";case .motocross:return "Campo y saltos";case .sport:return "Alta potencia";case .bmx:return "Sin motor"
        case .scooter:return "Ligero y urbano";case .scrambler:return "Asfalto y tierra";case .trials:return "Equilibrio y técnica";case .hyperbike:return "Superdeportiva";case .cruiser:return "Crucero relajado";case .electric:return "Eléctrica y silenciosa"
        }
    }
    var garageDetail:String {
        switch self {
        case .commuter:return "Street · 125 cc";case .motocross:return "Off-road · 250 cc";case .sport:return "Sport · 600 cc";case .bmx:return "Bicicleta · BMX"
        case .scooter:return "Automático · 80 cc";case .scrambler:return "Mixta · 400 cc";case .trials:return "Técnica · 200 cc";case .hyperbike:return "Superbike · 1.000 cc";case .cruiser:return "Custom · 750 cc";case .electric:return "Eléctrica · 8 kW"
        }
    }
    var supportsPassenger:Bool { self != .bmx && self != .trials && self != .hyperbike }
    /// Engine voice for the audio engine (0...7); the electric bike has none and is silent anyway.
    var engineVoice:Int { switch self { case .cruiser:return 1; case .electric:return 4; default:return BikeKind.allCases.firstIndex(of:self) ?? 0 } }
    var isElectric:Bool { self == .electric }
    var outfitStyle:BikeKind {
        switch self { case .scooter,.scrambler,.cruiser,.electric:return .commuter;case .trials:return .motocross;case .hyperbike:return .sport;default:return self }
    }
    var audioProfile:Int {
        switch self { case .commuter,.scooter,.scrambler:return 0;case .motocross,.trials,.cruiser:return 1;case .sport,.hyperbike:return 2;case .bmx,.electric:return 3 }   // the electric bike has no combustion voice
    }
    var engineAcceleration:Double {
        switch self { case .commuter:return 4.3;case .motocross:return 5.2;case .sport:return 6.3;case .bmx:return 2.0;case .scooter:return 3.5;case .scrambler:return 4.8;case .trials:return 4.5;case .hyperbike:return 7.0;case .cruiser:return 4.0;case .electric:return 6.0 }
    }
    var outfitDescription:String {
        switch self {
        case .commuter,.scooter,.scrambler,.cruiser,.electric:return "Urbano · chaqueta textil, vaqueros y zapatillas"
        case .motocross,.trials:return "Enduro · gafas, protecciones y botas altas"
        case .sport,.hyperbike:return "Circuito · mono de cuero, guantes y botas"
        case .bmx:return "BMX · camiseta, rodilleras y casco abierto"
        }
    }
    /// Flat-road target in m/s. Engine force balances drag at this speed.
    var topSpeed:Double {
        switch self {
        case .commuter:return 110/3.6;case .motocross:return 125/3.6
        case .sport:return 240/3.6;case .bmx:return 35/3.6
        case .scooter:return 85/3.6;case .scrambler:return 165/3.6
        case .trials:return 80/3.6;case .hyperbike:return 295/3.6
        case .cruiser:return 150/3.6;case .electric:return 130/3.6
        }
    }
    var aerodynamicDrag:Double {
        switch self {
        case .hyperbike:return 0.00065;case .sport:return 0.0009
        case .scrambler:return 0.0017;case .scooter:return 0.0022;case .cruiser:return 0.0029
        case .trials:return 0.0024;case .bmx:return 0.004;default:return 0.002
        }
    }
    var wheelbase:Double { rig.wheelbase }
    var rig:VehicleRig {
        let front:Double, radius:Double, length:Double
        let seat:RideVector,grip:RideVector,peg:RideVector
        let frontTravel:Double,rearTravel:Double,mass:Double,wheelMass:Double
        switch self {
        case .commuter:
            front=106; radius=23; length=1.32
            seat=RideVector(30,45); grip=RideVector(84,67); peg=RideVector(42,11)
            frontTravel=0.16; rearTravel=0.13; mass=170; wheelMass=9
        case .motocross:
            front=111; radius=26; length=1.45
            seat=RideVector(29,57); grip=RideVector(82,82); peg=RideVector(43,17)
            frontTravel=0.29; rearTravel=0.28; mass=155; wheelMass=8
        case .sport:
            front=110; radius=24; length=1.42
            seat=RideVector(29,50); grip=RideVector(84,60); peg=RideVector(39,11)
            frontTravel=0.12; rearTravel=0.12; mass=230; wheelMass=11
        case .bmx:
            front=94; radius=24; length=1.05
            seat=RideVector(29,49); grip=RideVector(77,81); peg=RideVector(44,0)
            frontTravel=0.025; rearTravel=0.025; mass=82; wheelMass=1.2
        case .scooter:
            front=100; radius=20; length=1.22
            seat=RideVector(27,43);grip=RideVector(79,67);peg=RideVector(59,4)
            frontTravel=0.10;rearTravel=0.10;mass=145;wheelMass=6
        case .scrambler:
            front=112; radius=26; length=1.43
            seat=RideVector(30,49);grip=RideVector(85,72);peg=RideVector(44,13)
            frontTravel=0.20;rearTravel=0.18;mass=205;wheelMass=10
        case .trials:
            front=108;radius=27;length=1.32
            seat=RideVector(34,61);grip=RideVector(83,80);peg=RideVector(44,16)
            frontTravel=0.24;rearTravel=0.22;mass=135;wheelMass=6
        case .hyperbike:
            front=114;radius=25;length=1.46
            seat=RideVector(31,51);grip=RideVector(87,59);peg=RideVector(41,12)
            frontTravel=0.13;rearTravel=0.12;mass=250;wheelMass=11
        case .cruiser:
            // Long, low and heavy: low seat, high bars, feet forward.
            front=112;radius=25;length=1.62
            seat=RideVector(28,38);grip=RideVector(84,76);peg=RideVector(62,9)
            frontTravel=0.12;rearTravel=0.10;mass=290;wheelMass=12
        case .electric:
            front=104;radius=23;length=1.30
            seat=RideVector(30,46);grip=RideVector(80,66);peg=RideVector(44,10)
            frontTravel=0.15;rearTravel=0.14;mass=150;wheelMass=8
        }
        let u=front/length
        return VehicleRig(riderTorsoTilt:self == .hyperbike ? 0.70 : self == .sport ? 0.64 : self == .bmx ? 0.36 : (self == .motocross || self == .trials) ? 0.27 : self == .cruiser ? 0.06 : 0.15,wheelbase:length,wheelRadius:radius/u,drawingUnitsPerMetre:u,
            centerOfMass:RideVector(length*0.45, self == .bmx ? 0.60 : self == .cruiser ? 0.46 : 0.52),
            rearSuspensionMount:RideVector(27/u, ((self == .motocross || self == .trials) ? 47 : 36)/u),
            frontSuspensionMount:RideVector((front-25)/u,((self == .motocross || self == .trials) ? 76 : self == .scrambler ? 65 : 57)/u),
            swingPivot:RideVector(43/u,10/u),seat:seat/u,grip:grip/u,footPeg:peg/u,
            crank:RideVector(45/u,0),frontTravel:frontTravel,rearTravel:rearTravel,
            sprungMass:mass,wheelMass:wheelMass)
    }
}

enum RideScene { static let metresToPixels=108.0 }
