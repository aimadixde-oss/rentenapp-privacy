import Foundation
import SwiftData

@Model
final class ExpenseReport {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var isDraft: Bool
    var isSent: Bool

    // Header data
    var name: String
    var personalNumber: String
    var department: String
    var function: String
    var plant: String
    var subledger: String
    var businessUnit: String
    var selectedCompanyRaw: String

    // Entertainment details
    var entertainmentDate: Date
    var restaurantName: String
    var restaurantAddress: String
    var occasion: String

    // Participants
    @Relationship(deleteRule: .cascade) var participants: [Participant]

    // Amounts
    var originalCurrency: String
    var originalAmount: Double
    var exchangeRate: Double
    var exchangeRateDate: String
    var amountEUR: Double
    var vatRate19: Double
    var vatRate7: Double
    var totalAmount: Double
    var isGermanReceipt: Bool

    // Signature data
    var accountantName: String
    var accountantDate: Date
    @Attribute(.externalStorage) var accountantSignatureData: Data?
    var supervisorName: String
    var supervisorDate: Date
    @Attribute(.externalStorage) var supervisorSignatureData: Data?

    // Receipt image
    @Attribute(.externalStorage) var receiptImageData: Data?

    var selectedCompany: Company? {
        get { Company(rawValue: selectedCompanyRaw) }
        set { selectedCompanyRaw = newValue?.rawValue ?? "" }
    }

    var formattedFileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: entertainmentDate)
        let safeName = restaurantName
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
        return "\(dateStr)_\(safeName).xlsx"
    }

    init() {
        self.id = UUID()
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isDraft = true
        self.isSent = false
        self.name = ""
        self.personalNumber = ""
        self.department = ""
        self.function = ""
        self.plant = ""
        self.subledger = ""
        self.businessUnit = ""
        self.selectedCompanyRaw = ""
        self.entertainmentDate = Date()
        self.restaurantName = ""
        self.restaurantAddress = ""
        self.occasion = ""
        self.participants = []
        self.originalCurrency = "EUR"
        self.originalAmount = 0
        self.exchangeRate = 1.0
        self.exchangeRateDate = ""
        self.amountEUR = 0
        self.vatRate19 = 0
        self.vatRate7 = 0
        self.totalAmount = 0
        self.isGermanReceipt = true
        self.accountantName = ""
        self.accountantDate = Date()
        self.accountantSignatureData = nil
        self.supervisorName = ""
        self.supervisorDate = Date()
        self.supervisorSignatureData = nil
        self.receiptImageData = nil
    }

    func applyProfile(_ profile: UserProfile) {
        self.name = profile.name
        self.personalNumber = profile.personalNumber
        self.department = profile.department
        self.function = profile.function
        self.plant = profile.plant
        self.subledger = profile.subledger
        self.businessUnit = profile.businessUnit
        self.selectedCompanyRaw = profile.selectedCompanyRaw
        self.accountantName = profile.name
        self.supervisorName = profile.supervisorName
        if let sigData = profile.signatureData {
            self.accountantSignatureData = sigData
        }
    }
}
