import Foundation

/// Styles bought with coins. Base colours stay free (the colour wells); styles add details on top.
enum HelmetStyle: Int, CaseIterable {
    case standard, stripe, flames, gold
    var title: String { ["Estándar", "Franja central", "Llamas", "Visera dorada"][rawValue] }
    var cost: Int { [0, 30, 50, 70][rawValue] }
}
enum JacketStyle: Int, CaseIterable {
    case standard, reflective, racing, twoTone
    var title: String { ["Estándar", "Bandas reflectantes", "Rayas de carreras", "Bicolor"][rawValue] }
    var cost: Int { [0, 25, 40, 60][rawValue] }
}
enum Livery: Int, CaseIterable {
    case none, number, stripes, checker
    var title: String { ["Sin decoración", "Dorsal con número", "Rayas deportivas", "Cuadros de meta"][rawValue] }
    var cost: Int { [0, 35, 45, 60][rawValue] }
}
