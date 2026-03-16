import SwiftUI
import SwiftData

@main
struct KlarApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
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
