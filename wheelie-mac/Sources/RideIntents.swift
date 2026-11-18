import AppIntents
import Cocoa

/// Shortcuts, Spotlight and Siri actions. They run inside the app, so they reuse the same links and stores as the Dock menu.
@available(macOS 13.0, *)
enum RideVehicleChoice: String, AppEnum {
    case commuter, motocross, sport, bmx, scooter, scrambler, trials, hyperbike, cruiser, electric
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Vehículo")
    static var caseDisplayRepresentations: [RideVehicleChoice: DisplayRepresentation] = [
        .commuter: "Street 125", .motocross: "Enduro 250", .sport: "Sport 600", .bmx: "BMX", .scooter: "Scooter 80",
        .scrambler: "Scrambler 400", .trials: "Trial 200", .hyperbike: "Hyper R 1000", .cruiser: "Cruiser 750", .electric: "Volt E-8",
    ]
}

@available(macOS 13.0, *)
enum RideRouteChoice: Int, AppEnum {
    case valley, sierra, dunes, snow, city
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Ruta")
    static var caseDisplayRepresentations: [RideRouteChoice: DisplayRepresentation] = [
        .valley: "Valle", .sierra: "Sierra", .dunes: "Dunas", .snow: "Nieve", .city: "Ciudad lluvia",
    ]
}

@available(macOS 13.0, *)
struct StartRideIntent: AppIntent {
    static var title: LocalizedStringResource = "Salir a rodar"
    static var description = IntentDescription("Empieza una ruta con la moto y la ruta que elijas.")
    static var openAppWhenRun = true
    @Parameter(title: "Vehículo") var vehicle: RideVehicleChoice?
    @Parameter(title: "Ruta") var route: RideRouteChoice?

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        var query = [String]()
        if let vehicle { query.append("vehicle=\(vehicle.rawValue)") }
        if let route { query.append("route=\(route.rawValue)") }
        if let url = URL(string: "wheelieride://start" + (query.isEmpty ? "" : "?" + query.joined(separator: "&"))) { (NSApp.delegate as? AppDelegate)?.handleLink(url) }
        return .result(dialog: "¡A rodar!")
    }
}

@available(macOS 13.0, *)
struct TodayMissionsIntent: AppIntent {
    static var title: LocalizedStringResource = "Misiones de hoy"
    static var description = IntentDescription("Lista las tres misiones diarias y la semanal.")
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let missions = RideMissions(preferences: .standard)
        let text = (missions.daily.map { "• \($0.title) (+\($0.reward))" } + ["Semanal: \(missions.weekly.title) (+\(missions.weekly.reward))"]).joined(separator: "\n")
        return .result(dialog: IntentDialog(stringLiteral: text))
    }
}

@available(macOS 13.0, *)
struct BestScoreIntent: AppIntent {
    static var title: LocalizedStringResource = "Mi mejor puntuación"
    static var description = IntentDescription("Dice tu mejor puntuación y los metros recorridos en total.")
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let totals = RideStats(preferences: .standard).totals
        return .result(dialog: IntentDialog(stringLiteral: "Tu mejor puntuación es \(totals.bestScore) y has recorrido \(Int(totals.distance)) metros en \(totals.runs) salidas."))
    }
}

@available(macOS 13.0, *)
struct OpenPilotCenterIntent: AppIntent {
    static var title: LocalizedStringResource = "Abrir el Centro del piloto"
    static var description = IntentDescription("Abre el diario, los retos de taller, los marcadores y los secretos.")
    static var openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult {
        (NSApp.delegate as? AppDelegate)?.showPilotCenter()
        return .result()
    }
}

@available(macOS 13.0, *)
struct RideShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartRideIntent(), phrases: ["Salir a rodar con \(.applicationName)", "Empezar una ruta en \(.applicationName)"], shortTitle: "Salir a rodar", systemImageName: "figure.outdoor.cycle")
        AppShortcut(intent: TodayMissionsIntent(), phrases: ["Misiones de hoy en \(.applicationName)"], shortTitle: "Misiones de hoy", systemImageName: "checklist")
        AppShortcut(intent: BestScoreIntent(), phrases: ["Mi mejor puntuación en \(.applicationName)"], shortTitle: "Mi mejor puntuación", systemImageName: "star")
        AppShortcut(intent: OpenPilotCenterIntent(), phrases: ["Abrir el Centro del piloto de \(.applicationName)"], shortTitle: "Centro del piloto", systemImageName: "book")
    }
}
