import SwiftUI
import SwiftData

struct ExpenseFormView: View {
    @Bindable var report: ExpenseReport
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ExpenseFormViewModel
    @State private var showCamera = false
    @State private var showAccountantSignature = false
    @State private var showSupervisorSignature = false
    @State private var showShareSheet = false
    @State private var exportedFileURL: URL?
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var capturedImage: UIImage?

    init(report: ExpenseReport) {
        self.report = report
        self._viewModel = State(initialValue: ExpenseFormViewModel())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                receiptSection
                headerDataSection
                entertainmentDetailsSection
                participantsSection
                amountsSection
                signatureSection
                actionButtons
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle("Bewirtungsabrechnung")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Schließen") {
                    saveDraft()
                    dismiss()
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Speichern") {
                    saveDraft()
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraView(capturedImage: $capturedImage)
        }
        .sheet(isPresented: $showAccountantSignature) {
            SignatureCaptureView(signatureData: $report.accountantSignatureData)
        }
        .sheet(isPresented: $showSupervisorSignature) {
            SignatureCaptureView(signatureData: $report.supervisorSignatureData)
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportedFileURL {
                ActivityViewRepresentable(activityItems: [url])
            }
        }
        .alert("Hinweis", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
        .onChange(of: capturedImage) { _, newImage in
            if let image = newImage {
                processReceiptImage(image)
            }
        }
    }

    // MARK: - Receipt Section

    private var receiptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Beleg", icon: "camera.fill")

            if let imageData = report.receiptImageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onTapGesture { showCamera = true }
            }

            Button {
                showCamera = true
            } label: {
                Label(
                    report.receiptImageData == nil ? "Beleg fotografieren" : "Neuen Beleg aufnehmen",
                    systemImage: "camera"
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)

            if viewModel.isProcessingOCR {
                HStack {
                    ProgressView()
                    Text("Beleg wird analysiert...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formSectionStyle()
    }

    // MARK: - Header Data Section

    private var headerDataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Kopfdaten", icon: "person.text.rectangle")

            VStack(spacing: 8) {
                // Company selection
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unternehmen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(Company.allCases) { company in
                        HStack {
                            Image(systemName: report.selectedCompany == company ? "checkmark.square.fill" : "square")
                                .foregroundStyle(report.selectedCompany == company ? Color.appPrimary : .gray)
                            Text(company.displayName)
                                .font(.subheadline)
                        }
                        .onTapGesture {
                            report.selectedCompany = company
                        }
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    LabeledFormField(label: "Name", text: $report.name)
                    LabeledFormField(label: "Personal-Nr.", text: $report.personalNumber)
                    LabeledFormField(label: "Abt. / Reg.", text: $report.department)
                    LabeledFormField(label: "Funktion", text: $report.function)
                    LabeledFormField(label: "Werk / NL", text: $report.plant)
                    LabeledFormField(label: "Subledger", text: $report.subledger)
                    LabeledFormField(label: "Business Unit", text: $report.businessUnit)
                }
            }
        }
        .formSectionStyle()
    }

    // MARK: - Entertainment Details Section

    private var entertainmentDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Bewirtungsdetails", icon: "fork.knife")

            DatePicker("Tag der Bewirtung", selection: $report.entertainmentDate, displayedComponents: .date)
                .environment(\.locale, Locale(identifier: "de_DE"))

            LabeledFormField(label: "Restaurant", text: $report.restaurantName)
            LabeledFormField(label: "Adresse", text: $report.restaurantAddress)

            VStack(alignment: .leading, spacing: 4) {
                Text("Anlass der Bewirtung")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $report.occasion)
                    .frame(minHeight: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.3))
                    )
            }
        }
        .formSectionStyle()
    }

    // MARK: - Participants Section

    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Teilnehmer", icon: "person.3.fill")

            ForEach(Array(report.participants.enumerated()), id: \.element.id) { index, participant in
                ParticipantRow(
                    participant: participant,
                    onDelete: {
                        report.participants.remove(at: index)
                    }
                )
            }

            Button {
                let newParticipant = Participant()
                report.participants.append(newParticipant)
            } label: {
                Label("Teilnehmer hinzufügen", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
        }
        .formSectionStyle()
    }

    // MARK: - Amounts Section

    private var amountsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Beträge", icon: "eurosign.circle.fill")

            if report.originalCurrency != "EUR" {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Originalwährung: \(report.originalCurrency)")
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "%.2f \(report.originalCurrency)", report.originalAmount))
                            .font(.subheadline.bold())
                    }

                    HStack {
                        Text("Wechselkurs (\(report.exchangeRateDate)):")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.4f", report.exchangeRate))
                            .font(.caption)
                    }

                    Divider()
                }
            }

            if report.isGermanReceipt {
                HStack {
                    Text("MwSt. 19%")
                        .font(.subheadline)
                    Spacer()
                    TextField("0,00", value: $report.vatRate19, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                        .textFieldStyle(.roundedBorder)
                    Text("€")
                }

                HStack {
                    Text("MwSt. 7%")
                        .font(.subheadline)
                    Spacer()
                    TextField("0,00", value: $report.vatRate7, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                        .textFieldStyle(.roundedBorder)
                    Text("€")
                }
            }

            HStack {
                Text("Gesamtbetrag")
                    .font(.headline)
                Spacer()
                TextField("0,00", value: $report.totalAmount, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                    .textFieldStyle(.roundedBorder)
                Text("€")
                    .font(.headline)
            }
        }
        .formSectionStyle()
    }

    // MARK: - Signature Section

    private var signatureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Unterschriften", icon: "signature")

            VStack(alignment: .leading, spacing: 8) {
                Text("Abrechner")
                    .font(.subheadline.bold())
                LabeledFormField(label: "Name", text: $report.accountantName)
                DatePicker("Datum", selection: $report.accountantDate, displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "de_DE"))
                SignatureDisplayView(
                    signatureData: report.accountantSignatureData,
                    label: "Unterschrift Abrechner"
                ) {
                    showAccountantSignature = true
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Vorgesetzter")
                    .font(.subheadline.bold())
                LabeledFormField(label: "Name", text: $report.supervisorName)
                DatePicker("Datum", selection: $report.supervisorDate, displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "de_DE"))
                SignatureDisplayView(
                    signatureData: report.supervisorSignatureData,
                    label: "Unterschrift Vorgesetzter"
                ) {
                    showSupervisorSignature = true
                }
            }
        }
        .formSectionStyle()
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                exportAndShare()
            } label: {
                Label("Excel exportieren & versenden", systemImage: "envelope.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.appPrimary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Button {
                exportExcelOnly()
            } label: {
                Label("Nur Excel exportieren", systemImage: "arrow.down.doc.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Actions

    private func processReceiptImage(_ image: UIImage) {
        report.receiptImageData = image.jpegData(compressionQuality: 0.8)

        Task {
            viewModel.isProcessingOCR = true
            defer { viewModel.isProcessingOCR = false }

            do {
                let receiptData = try await OCRService.shared.extractReceiptData(from: image)

                await MainActor.run {
                    if !receiptData.restaurantName.isEmpty {
                        report.restaurantName = receiptData.restaurantName
                    }
                    if !receiptData.restaurantAddress.isEmpty {
                        report.restaurantAddress = receiptData.restaurantAddress
                    }
                    if let date = receiptData.date {
                        report.entertainmentDate = date
                    }
                    if receiptData.totalAmount > 0 {
                        report.originalAmount = receiptData.totalAmount
                        report.originalCurrency = receiptData.currency
                        report.isGermanReceipt = receiptData.isGerman
                    }

                    // Convert currency if needed
                    if receiptData.currency != "EUR" {
                        Task {
                            await convertCurrency()
                        }
                    } else {
                        report.totalAmount = receiptData.totalAmount
                        report.amountEUR = receiptData.totalAmount
                        report.exchangeRate = 1.0
                    }
                }
            } catch {
                await MainActor.run {
                    alertMessage = "OCR-Fehler: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }

    private func convertCurrency() async {
        do {
            let result = try await CurrencyService.shared.convertToEUR(
                amount: report.originalAmount,
                fromCurrency: report.originalCurrency,
                on: report.entertainmentDate
            )

            await MainActor.run {
                report.exchangeRate = result.rate
                report.exchangeRateDate = result.date
                report.amountEUR = report.originalAmount * result.rate
                report.totalAmount = report.amountEUR
            }
        } catch {
            await MainActor.run {
                alertMessage = "Währungsumrechnung fehlgeschlagen: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }

    private func saveDraft() {
        report.isDraft = true
        report.updatedAt = Date()
        modelContext.insert(report)
        try? modelContext.save()
    }

    private func exportExcelOnly() {
        do {
            let url = try ExcelExportService.shared.generateExcel(for: report)
            exportedFileURL = url
            showShareSheet = true
        } catch {
            alertMessage = "Export fehlgeschlagen: \(error.localizedDescription)"
            showAlert = true
        }
    }

    private func exportAndShare() {
        do {
            let url = try ExcelExportService.shared.generateExcel(for: report)
            exportedFileURL = url

            // Try email first, fall back to share sheet
            if EmailService.shared.canSendEmail {
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let viewController = windowScene.windows.first?.rootViewController else {
                    showShareSheet = true
                    return
                }

                let subject = "Bewirtungskostenabrechnung \(report.entertainmentDate.germanFormatted) - \(report.restaurantName)"
                let body = """
                Anbei die Bewirtungskostenabrechnung:

                Datum: \(report.entertainmentDate.germanFormatted)
                Restaurant: \(report.restaurantName)
                Betrag: \(report.totalAmount.formattedEUR)

                Mit freundlichen Grüßen
                \(report.accountantName)
                """

                EmailService.shared.composeEmail(
                    to: [],
                    subject: subject,
                    body: body,
                    attachmentURL: url,
                    from: viewController
                ) { sent in
                    if sent {
                        report.isSent = true
                        report.isDraft = false
                        try? modelContext.save()
                    }
                }
            } else {
                showShareSheet = true
            }
        } catch {
            alertMessage = "Export fehlgeschlagen: \(error.localizedDescription)"
            showAlert = true
        }
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .foregroundStyle(Color.appPrimary)
    }
}

struct ParticipantRow: View {
    @Bindable var participant: Participant
    var onDelete: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Query private var savedParticipants: [SavedParticipant]
    @State private var showSuggestions = false

    var filteredSuggestions: [SavedParticipant] {
        guard !participant.name.isEmpty else { return [] }
        return savedParticipants.filter {
            $0.name.localizedCaseInsensitiveContains(participant.name) && $0.name != participant.name
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top) {
                VStack(spacing: 6) {
                    TextField("Name", text: $participant.name)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: participant.name) { _, _ in
                            showSuggestions = !filteredSuggestions.isEmpty
                        }

                    TextField("Firma", text: $participant.company)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(spacing: 6) {
                    Picker("Kategorie", selection: $participant.categoryRaw) {
                        ForEach(ParticipantCategory.allCases) { cat in
                            Text(cat.displayName).tag(cat.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }

            if showSuggestions && !filteredSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(filteredSuggestions) { saved in
                        Button {
                            participant.name = saved.name
                            participant.company = saved.company
                            participant.category = saved.category
                            showSuggestions = false
                        } label: {
                            VStack(alignment: .leading) {
                                Text(saved.name).font(.subheadline)
                                Text(saved.company).font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(.vertical, 4)
    }
}

struct ActivityViewRepresentable: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
