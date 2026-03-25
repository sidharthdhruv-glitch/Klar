import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab: KlarTab = .pulse
    @Environment(\.modelContext) private var modelContext
    @State private var hasSeeded = false

    var body: some View {
        VStack(spacing: 0) {
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
            .animation(KlarAnimation.springDefault, value: selectedTab)
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [
                        KlarColors.background.opacity(0),
                        KlarColors.background.opacity(0.8)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 50)
                .allowsHitTesting(false)
            }

            KlarTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
        .background(KlarColors.background)
        .onAppear {
            seedDefaultsIfNeeded()
        }
    }

    private func seedDefaultsIfNeeded() {
        guard !hasSeeded else { return }
        hasSeeded = true

        let catDescriptor = FetchDescriptor<Category>()
        let catCount = (try? modelContext.fetchCount(catDescriptor)) ?? 0
        if catCount == 0 {
            for cat in DefaultData.categories {
                modelContext.insert(Category(name: cat.name, colorHex: cat.colorHex, sfSymbol: cat.sfSymbol))
            }
        }

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
