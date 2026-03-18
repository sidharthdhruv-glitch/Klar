import SwiftUI

enum KlarTab: Int, CaseIterable {
    case pulse = 0
    case importHub = 1
    case ledger = 2
    case visualizer = 3
    case settings = 4

    var title: String {
        switch self {
        case .pulse: return "Pulse"
        case .importHub: return "Import"
        case .ledger: return "Ledger"
        case .visualizer: return "Visualizer"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .pulse: return "house"
        case .importHub: return "icloud.and.arrow.down"
        case .ledger: return "list.bullet.rectangle"
        case .visualizer: return "chart.bar.xaxis"
        case .settings: return "gearshape"
        }
    }
}

struct KlarTabBar: View {
    @Binding var selectedTab: KlarTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(KlarTab.allCases, id: \.rawValue) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(KlarColors.tabBarBg)
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private func tabButton(_ tab: KlarTab) -> some View {
        let isActive = selectedTab == tab
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedTab = tab
            }
        } label: {
            Image(systemName: tab.icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(isActive ? KlarColors.accent : .white.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selectedTab)
    }
}
