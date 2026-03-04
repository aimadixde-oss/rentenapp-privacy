import Foundation
import SwiftData

@Model
final class Participant {
    var name: String
    var company: String
    var categoryRaw: String

    var category: ParticipantCategory {
        get { ParticipantCategory(rawValue: categoryRaw) ?? .customerSupplier }
        set { categoryRaw = newValue.rawValue }
    }

    init(name: String = "", company: String = "", category: ParticipantCategory = .customerSupplier) {
        self.name = name
        self.company = company
        self.categoryRaw = category.rawValue
    }
}

@Model
final class SavedParticipant {
    @Attribute(.unique) var name: String
    var company: String
    var categoryRaw: String
    var usageCount: Int

    var category: ParticipantCategory {
        get { ParticipantCategory(rawValue: categoryRaw) ?? .customerSupplier }
        set { categoryRaw = newValue.rawValue }
    }

    init(name: String, company: String = "", category: ParticipantCategory = .customerSupplier) {
        self.name = name
        self.company = company
        self.categoryRaw = category.rawValue
        self.usageCount = 1
    }
}
