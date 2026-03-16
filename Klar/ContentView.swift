import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab: KlarTab = .pulse
    @Environment(\.modelContext) private var modelContext
    @State private var hasSeeded = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .pulse:
                    DashboardView()
                case .importHub:
                    ImportHubView()
                case .ledger:
                    LedgerView()
                case .visualizer:
                    VisualizerView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity.combined(with: .scale(scale: 0.98)))

            KlarTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
        .background(KlarColors.background)
        .onAppear {
            seedMockDataIfNeeded()
        }
    }

    private func seedMockDataIfNeeded() {
        guard !hasSeeded else { return }
        hasSeeded = true

        let descriptor = FetchDescriptor<Transaction>()
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        for txn in MockData.transactions {
            modelContext.insert(txn)
        }
        for account in MockData.accounts {
            modelContext.insert(account)
        }
        for category in MockData.categories {
            modelContext.insert(category)
        }
        for rule in MockData.rules {
            modelContext.insert(rule)
        }
        for sub in MockData.subscriptions {
            modelContext.insert(sub)
        }

        try? modelContext.save()
    }
}
