import Foundation
import SwiftData

@Model
final class UserProfile {
    var name: String
    var personalNumber: String
    var department: String
    var function: String
    var plant: String
    var subledger: String
    var businessUnit: String
    var selectedCompanyRaw: String
    var supervisorName: String
    var defaultRecipientEmail: String
    @Attribute(.externalStorage) var signatureData: Data?

    var selectedCompany: Company? {
        get { Company(rawValue: selectedCompanyRaw) }
        set { selectedCompanyRaw = newValue?.rawValue ?? "" }
    }

    init(
        name: String = "",
        personalNumber: String = "",
        department: String = "",
        function: String = "",
        plant: String = "",
        subledger: String = "",
        businessUnit: String = "",
        selectedCompany: Company? = nil,
        supervisorName: String = "",
        defaultRecipientEmail: String = "",
        signatureData: Data? = nil
    ) {
        self.name = name
        self.personalNumber = personalNumber
        self.department = department
        self.function = function
        self.plant = plant
        self.subledger = subledger
        self.businessUnit = businessUnit
        self.selectedCompanyRaw = selectedCompany?.rawValue ?? ""
        self.supervisorName = supervisorName
        self.defaultRecipientEmail = defaultRecipientEmail
        self.signatureData = signatureData
    }
}
