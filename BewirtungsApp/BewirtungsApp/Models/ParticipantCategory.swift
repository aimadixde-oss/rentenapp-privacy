import Foundation

enum ParticipantCategory: String, Codable, CaseIterable, Identifiable {
    case customerSupplier = "Kunden/Lieferanten"
    case otherBusinessPartner = "Sonst. Geschäftspartner"
    case employee = "Mitarbeiter"

    var id: String { rawValue }

    var deductionPercentage: Int {
        switch self {
        case .customerSupplier: return 70
        case .otherBusinessPartner: return 70
        case .employee: return 100
        }
    }

    var displayName: String {
        "\(rawValue) (\(deductionPercentage)%)"
    }
}
