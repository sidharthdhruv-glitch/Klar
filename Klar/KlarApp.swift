import SwiftUI
import SwiftData

@main
struct KlarApp: App {
    @AppStorage("selectedTheme") private var selectedTheme = "Cream"

    private var colorScheme: ColorScheme? {
        switch selectedTheme {
        case "Cream": return .light
        case "Midnight": return .dark
        default: return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(colorScheme)
        }
        .modelContainer(for: [
            Transaction.self,
            Account.self,
            Category.self,
            Rule.self,
            Subscription.self,
        ])
    }
}
