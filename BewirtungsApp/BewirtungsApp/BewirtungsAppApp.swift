import SwiftUI
import SwiftData

@main
struct BewirtungsAppApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .modelContainer(for: [
            ExpenseReport.self,
            UserProfile.self,
            SavedParticipant.self
        ])
    }
}
