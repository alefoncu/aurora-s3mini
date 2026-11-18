import Foundation

// MARK: Secrets: stars hidden above each route, reachable only in the air. Each one carries a page of the pilot's diary.

struct RideSecret: Equatable { let id: String, route: Int, x: Double, note: String }

enum RideSecrets {
    static let notes = [
        "Mi padre decía que el valle se entiende mejor desde el aire.",
        "En la primera curva aprendí que el gas se dosifica, no se aprieta.",
        "Hay una cima donde el motor se calla un segundo. Ahí vuelo.",
        "La sierra no perdona la prisa. Respira antes de cada bajada.",
        "Dejé una pegatina en la roca más alta. Nadie la ha encontrado.",
        "Frenar tarde es valentía; frenar a tiempo es oficio.",
        "Las dunas cambian cada noche; el mapa que dibujé ya no sirve.",
        "Un salto limpio suena a silencio justo antes del golpe.",
        "El viento arrastra la arena y también las dudas.",
        "En la nieve, cada gesto cuenta el doble.",
        "Escuché al hielo crujir y aprendí a soltar el freno.",
        "El caballito perfecto es un equilibrio que dura un suspiro.",
        "La lluvia en la ciudad vuelve brillante hasta el asfalto roto.",
        "Entre los charcos hay un hueco: solo lo ve quien no mira el charco.",
        "Cuando llegue a la última meta, volveré a empezar por la primera.",
    ]
    static func all() -> [RideSecret] {
        (0..<5).flatMap { route in (0..<3).map { i in RideSecret(id: "s.\(route).\(i)", route: route, x: 260 + Double(i) * 340 + Double(route) * 23, note: notes[route * 3 + i]) } }
    }
    static func forRoute(_ route: Int) -> [RideSecret] { all().filter { $0.route == route } }
    /// A secret is caught by passing near it in the air, above a small hop.
    static func isCollected(_ s: RideSecret, bikeX: Double, bikeHeight: Double, airborne: Bool) -> Bool {
        airborne && abs(bikeX - s.x) < 3 && bikeHeight >= 0.3
    }
}

// MARK: Pilot's diary: short entries that unlock with progress.

struct JournalEntry {
    let id: String, title: String, body: String, unlock: String
    let isUnlocked: (RideTotals, Int) -> Bool
}

enum RideJournal {
    static let entries: [JournalEntry] = [
        JournalEntry(id: "j1", title: "Primera salida", body: "Casco puesto, depósito lleno. Hoy no hay récords: solo carretera y ganas.", unlock: "Sal a rodar una vez.") { t, _ in t.runs >= 1 },
        JournalEntry(id: "j2", title: "Primera meta", body: "Cruzar la línea se siente distinto a como lo imaginaba: más tranquilo, y a la vez más grande.", unlock: "Completa una ruta.") { t, _ in t.finishes >= 1 },
        JournalEntry(id: "j3", title: "El taller", body: "Aprendí que una moto se afina como un instrumento. Un clic de suspensión cambia toda la canción.", unlock: "Sal a rodar 5 veces.") { t, _ in t.runs >= 5 },
        JournalEntry(id: "j4", title: "Caídas", body: "Cada caída enseña una cosa. La mía de hoy: el suelo siempre gana, pero se le puede hacer esperar.", unlock: "Cae 3 veces.") { t, _ in t.crashes >= 3 },
        JournalEntry(id: "j5", title: "Caballito", body: "Encontré el punto exacto: ni sobra gas ni falta peso. Duró cuatro segundos y valió todo el verano.", unlock: "200 m de caballito acumulados.") { t, _ in t.wheelieMetres >= 200 },
        JournalEntry(id: "j6", title: "Aire", body: "La primera voltereta aterrizada. Lo recuerdo todo en cámara lenta.", unlock: "Aterriza una voltereta.") { t, _ in t.flips >= 1 },
        JournalEntry(id: "j7", title: "Rival", body: "Tener a alguien a tu lado cambia el ritmo. Me he dado cuenta de que corro mejor cuando me ven.", unlock: "Gana una carrera.") { t, _ in t.raceWins >= 1 },
        JournalEntry(id: "j8", title: "Kilómetros", body: "Diez mil metros no son nada en una carretera y lo son todo en un diario.", unlock: "Recorre 10.000 m.") { t, _ in t.distance >= 10_000 },
        JournalEntry(id: "j9", title: "Sin fin", body: "El modo infinito no tiene meta, y por eso mismo se parece a la vida: se juzga por cómo vas, no por dónde llegas.", unlock: "1.500 m en modo infinito.") { t, _ in t.bestEndless >= 1_500 },
        JournalEntry(id: "j10", title: "Coleccionista de estrellas", body: "Quince estrellas escondidas, quince frases escritas por alguien que ya pasó por aquí. Ahora el diario también es mío.", unlock: "Encuentra los 15 secretos.") { _, s in s >= RideSecrets.all().count },
    ]
    static func unlocked(totals: RideTotals, secrets: Int) -> [JournalEntry] { entries.filter { $0.isUnlocked(totals, secrets) } }
}

// MARK: Workshop puzzles: a fixed vehicle, route and set-up with one goal. Pick the way to solve it.

struct RidePuzzle: Equatable {
    let id: String, title: String, story: String
    let vehicle: BikeKind, route: Int, challenge: RideChallengeKind
    let stiffness: Double, damping: Double, reward: Int
    static let all: [RidePuzzle] = [
        RidePuzzle(id: "p1", title: "El caballito del trial", story: "La Trial tiene tanto par que se levanta sola. Mantén 15 m con la suspensión más dura.", vehicle: .trials, route: 0, challenge: .wheelie, stiffness: 1.3, damping: 1.2, reward: 40),
        RidePuzzle(id: "p2", title: "Invertido bajo la lluvia", story: "El asfalto mojado agarra menos. Dosifica el freno delantero en la ciudad.", vehicle: .commuter, route: 4, challenge: .stoppie, stiffness: 1.0, damping: 1.0, reward: 40),
        RidePuzzle(id: "p3", title: "El salto de la duna", story: "Con la suspensión blanda la arena perdona el aterrizaje. Supera la altura y no te caigas.", vehicle: .scrambler, route: 2, challenge: .jump, stiffness: 0.7, damping: 0.8, reward: 30),
        RidePuzzle(id: "p4", title: "Contrarreloj en la sierra", story: "Una Sport rígida y rápida: 1.200 m en 4 minutos sin perder tracción en las curvas.", vehicle: .sport, route: 1, challenge: .timeTrial, stiffness: 1.3, damping: 0.9, reward: 50),
        RidePuzzle(id: "p5", title: "Caballito silencioso", story: "La Volt E-8 no hace ruido que te avise. Llega a 15 m de caballito en la nieve.", vehicle: .electric, route: 3, challenge: .wheelie, stiffness: 1.0, damping: 1.1, reward: 40),
        RidePuzzle(id: "p6", title: "BMX a contrarreloj", story: "Sin motor ni marchas: solo tú. Completa la ruta del valle en menos de 4 minutos.", vehicle: .bmx, route: 0, challenge: .timeTrial, stiffness: 1.0, damping: 1.0, reward: 50),
    ]
}

// MARK: Local leaderboards per route. Game Center needs a signed, provisioned build; these work for everyone and keep the same shape.

struct RideBoardEntry: Codable, Equatable { let score: Int, distance: Int, time: Double, vehicle: String, date: Date }

enum RideLeaderboard {
    static let size = 10
    static func key(route: Int) -> String { "board.\(route)" }
    static func load(_ p: UserDefaults, route: Int) -> [RideBoardEntry] {
        guard let data = p.data(forKey: key(route: route)), let list = try? JSONDecoder().decode([RideBoardEntry].self, from: data) else { return [] }
        return list
    }
    /// Insert an entry, keep the best ten by score, and return the new rank (1-based) or nil when it did not make the board.
    @discardableResult
    static func submit(_ p: UserDefaults, route: Int, _ entry: RideBoardEntry) -> Int? {
        guard entry.score > 0 else { return nil }
        var list = load(p, route: route)
        list.append(entry); list.sort { $0.score != $1.score ? $0.score > $1.score : $0.date < $1.date }
        let rank = list.firstIndex(of: entry).map { $0 + 1 }
        list = Array(list.prefix(size))
        if let data = try? JSONEncoder().encode(list) { p.set(data, forKey: key(route: route)) }
        guard let rank, rank <= size else { return nil }
        return rank
    }
}
