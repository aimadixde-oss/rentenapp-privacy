import SwiftUI

struct SettingsView: View {
    @State private var ecbAPIKey: String = ""
    @State private var aiAPIKey: String = ""
    @State private var defaultRecipient: String = ""
    @State private var showSaveConfirmation = false

    private let keychain = KeychainService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // API Keys
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "API-Schlüssel", icon: "key.fill")

                    Text("API-Schlüssel werden sicher im iOS Keychain gespeichert.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("ECB Wechselkurs-API")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        SecureField("API-Key (optional)", text: $ecbAPIKey)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("KI-Dienst API (z.B. OpenAI)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        SecureField("API-Key (optional)", text: $aiAPIKey)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .formSectionStyle()

                // Default Email Recipient
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "E-Mail Einstellungen", icon: "envelope.fill")

                    LabeledFormField(
                        label: "Standard-Empfänger (Buchhaltung)",
                        text: $defaultRecipient,
                        keyboardType: .emailAddress
                    )
                }
                .formSectionStyle()

                // Save Button
                Button {
                    saveSettings()
                } label: {
                    Text("Einstellungen speichern")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appPrimary)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.top)

                // Info
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Info", icon: "info.circle")

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bewirtungsapp v1.0")
                            .font(.subheadline)
                        Text("Bewirtungskostenabrechnung gem. §4 Abs. 5 Nr. 2 EStG i. V. m. §9 Abs. 4a EStG")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .formSectionStyle()
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle("Einstellungen")
        .onAppear(perform: loadSettings)
        .alert("Gespeichert", isPresented: $showSaveConfirmation) {
            Button("OK") {}
        } message: {
            Text("Die Einstellungen wurden erfolgreich gespeichert.")
        }
    }

    private func loadSettings() {
        ecbAPIKey = keychain.retrieve(for: .ecbAPIKey) ?? ""
        aiAPIKey = keychain.retrieve(for: .aiServiceAPIKey) ?? ""
    }

    private func saveSettings() {
        if !ecbAPIKey.isEmpty {
            _ = keychain.save(ecbAPIKey, for: .ecbAPIKey)
        } else {
            _ = keychain.delete(for: .ecbAPIKey)
        }

        if !aiAPIKey.isEmpty {
            _ = keychain.save(aiAPIKey, for: .aiServiceAPIKey)
        } else {
            _ = keychain.delete(for: .aiServiceAPIKey)
        }

        showSaveConfirmation = true
    }
}
