import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var showSignatureCapture = false

    private var profile: UserProfile {
        if let existing = profiles.first {
            return existing
        }
        let newProfile = UserProfile()
        modelContext.insert(newProfile)
        try? modelContext.save()
        return newProfile
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Personal Data
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Persönliche Daten", icon: "person.fill")

                    LabeledFormField(label: "Name", text: bindableProfile.name)
                    LabeledFormField(label: "Personal-Nr.", text: bindableProfile.personalNumber)
                    LabeledFormField(label: "Funktion", text: bindableProfile.function)
                    LabeledFormField(label: "Abt. / Reg.", text: bindableProfile.department)
                    LabeledFormField(label: "Werk / NL", text: bindableProfile.plant)
                    LabeledFormField(label: "Subledger", text: bindableProfile.subledger)
                    LabeledFormField(label: "Business Unit", text: bindableProfile.businessUnit)
                }
                .formSectionStyle()

                // Company
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Unternehmen", icon: "building.2.fill")

                    ForEach(Company.allCases) { company in
                        HStack {
                            Image(systemName: profile.selectedCompany == company ? "checkmark.square.fill" : "square")
                                .foregroundStyle(profile.selectedCompany == company ? Color.appPrimary : .gray)
                            Text(company.displayName)
                        }
                        .onTapGesture {
                            profile.selectedCompany = company
                            try? modelContext.save()
                        }
                    }
                }
                .formSectionStyle()

                // Supervisor
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Vorgesetzter", icon: "person.badge.shield.checkmark")

                    LabeledFormField(label: "Name des Vorgesetzten", text: bindableProfile.supervisorName)
                }
                .formSectionStyle()

                // Default recipient
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Standard-Empfänger", icon: "envelope.fill")

                    LabeledFormField(
                        label: "E-Mail (z.B. Buchhaltung)",
                        text: bindableProfile.defaultRecipientEmail,
                        keyboardType: .emailAddress
                    )
                }
                .formSectionStyle()

                // Signature
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Unterschrift", icon: "signature")

                    SignatureDisplayView(
                        signatureData: profile.signatureData,
                        label: "Ihre Unterschrift"
                    ) {
                        showSignatureCapture = true
                    }
                }
                .formSectionStyle()
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle("Profil")
        .sheet(isPresented: $showSignatureCapture) {
            SignatureCaptureView(signatureData: bindableProfile.signatureData)
        }
        .onDisappear {
            try? modelContext.save()
        }
    }

    private var bindableProfile: Bindable<UserProfile> {
        Bindable(profile)
    }
}
