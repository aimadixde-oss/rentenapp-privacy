import Foundation

enum Company: String, Codable, CaseIterable, Identifiable {
    case froneriIceCreamDeutschland = "FRONERI Ice Cream Deutschland GmbH"
    case froneriSchoeller = "FRONERI Schöller GmbH"

    var id: String { rawValue }

    var displayName: String { rawValue }
}
