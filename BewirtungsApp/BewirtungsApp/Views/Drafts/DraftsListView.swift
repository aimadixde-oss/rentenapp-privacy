import SwiftUI
import SwiftData

struct DraftsListView: View {
    @Query(
        filter: #Predicate<ExpenseReport> { $0.isDraft },
        sort: \ExpenseReport.updatedAt,
        order: .reverse
    ) private var drafts: [ExpenseReport]
    @Environment(\.modelContext) private var modelContext
    @State private var selectedDraft: ExpenseReport?

    var body: some View {
        Group {
            if drafts.isEmpty {
                ContentUnavailableView(
                    "Keine Entwürfe",
                    systemImage: "doc.on.doc",
                    description: Text("Gespeicherte Entwürfe erscheinen hier.")
                )
            } else {
                List {
                    ForEach(drafts) { draft in
                        DraftRow(draft: draft)
                            .onTapGesture {
                                selectedDraft = draft
                            }
                    }
                    .onDelete(perform: deleteDrafts)
                }
            }
        }
        .navigationTitle("Entwürfe")
        .fullScreenCover(item: $selectedDraft) { draft in
            NavigationStack {
                ExpenseFormView(report: draft)
            }
        }
    }

    private func deleteDrafts(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(drafts[index])
        }
        try? modelContext.save()
    }
}

struct DraftRow: View {
    let draft: ExpenseReport

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(draft.restaurantName.isEmpty ? "Ohne Titel" : draft.restaurantName)
                    .font(.headline)
                Spacer()
                Text(draft.totalAmount.formattedEUR)
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.appPrimary)
            }

            HStack {
                if !draft.occasion.isEmpty {
                    Text(draft.occasion)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(draft.entertainmentDate.germanFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("\(draft.participants.count) Teilnehmer")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("Geändert: \(draft.updatedAt.germanFormatted)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
