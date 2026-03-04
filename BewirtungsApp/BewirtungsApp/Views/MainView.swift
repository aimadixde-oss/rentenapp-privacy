import SwiftUI
import SwiftData

struct MainView: View {
    @State private var showMenu = false
    @State private var selectedDestination: MenuDestination?
    @State private var showNewExpense = false
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<UserProfile> { _ in true }) private var profiles: [UserProfile]

    enum MenuDestination: Hashable {
        case profile
        case drafts
        case settings
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "doc.text.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.appPrimary)

                Text("Bewirtungskosten")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color.appPrimary)

                Text("Abrechnung gem. §4 Abs. 5 Nr. 2 EStG")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    showNewExpense = true
                } label: {
                    Label("Neue Abrechnung", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appPrimary)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)

                NavigationLink(value: MenuDestination.drafts) {
                    Label("Gespeicherte Entwürfe", systemImage: "doc.on.doc")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appAccent.opacity(0.15))
                        .foregroundStyle(Color.appPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)

                Spacer()
            }
            .background(Color.appBackground)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        NavigationLink(value: MenuDestination.profile) {
                            Label("Profil", systemImage: "person.circle")
                        }
                        NavigationLink(value: MenuDestination.drafts) {
                            Label("Entwürfe", systemImage: "doc.on.doc")
                        }
                        NavigationLink(value: MenuDestination.settings) {
                            Label("Einstellungen", systemImage: "gear")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.title2)
                            .foregroundStyle(Color.appPrimary)
                    }
                }
            }
            .navigationDestination(for: MenuDestination.self) { destination in
                switch destination {
                case .profile:
                    ProfileView()
                case .drafts:
                    DraftsListView()
                case .settings:
                    SettingsView()
                }
            }
            .fullScreenCover(isPresented: $showNewExpense) {
                NavigationStack {
                    ExpenseFormView(report: createNewReport())
                }
            }
        }
    }

    private func createNewReport() -> ExpenseReport {
        let report = ExpenseReport()
        if let profile = profiles.first {
            report.applyProfile(profile)
        }
        return report
    }
}
