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

            VStack(spacing: 0) {
                // Gradient fade above tab bar
                LinearGradient(
                    colors: [
                        KlarColors.background.opacity(0),
                        KlarColors.background.opacity(0.6),
                        KlarColors.background
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 40)
                .allowsHitTesting(false)

                KlarTabBar(selectedTab: $selectedTab)
            }
        }
        .ignoresSafeArea(.keyboard)
        .background(KlarColors.background)
        .onAppear {
            seedDefaultsIfNeeded()
        }
    }

    /// Seeds default categories and rules only — no mock transactions.
    private func seedDefaultsIfNeeded() {
        guard !hasSeeded else { return }
        hasSeeded = true

        // Seed default categories if none exist
        let catDescriptor = FetchDescriptor<Category>()
        let catCount = (try? modelContext.fetchCount(catDescriptor)) ?? 0
        if catCount == 0 {
            for cat in DefaultData.categories {
                modelContext.insert(Category(name: cat.name, colorHex: cat.colorHex, sfSymbol: cat.sfSymbol))
            }
        }

        // Seed default rules if none exist
        let ruleDescriptor = FetchDescriptor<Rule>()
        let ruleCount = (try? modelContext.fetchCount(ruleDescriptor)) ?? 0
        if ruleCount == 0 {
            for rule in DefaultData.rules {
                modelContext.insert(Rule(keyword: rule.keyword, targetCategory: rule.targetCategory))
            }
        }

        try? modelContext.save()
    }
}
