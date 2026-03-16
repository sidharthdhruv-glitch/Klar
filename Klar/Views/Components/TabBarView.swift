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
        case .pulse: return "waveform"
        case .importHub: return "square.and.arrow.down"
        case .ledger: return "list.bullet.rectangle"
        case .visualizer: return "chart.bar.xaxis"
        case .settings: return "gearshape"
        }
    }
}

struct KlarTabBar: View {
    @Binding var selectedTab: KlarTab
    @Namespace private var tabAnimation

    var body: some View {
        HStack {
            ForEach(KlarTab.allCases, id: \.rawValue) { tab in
                Spacer()
                tabButton(tab)
                Spacer()
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 28)
        .background(
            KlarColors.tabBarBg
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundStyle(KlarColors.tabBarBorder),
                    alignment: .top
                )
        )
    }

    @ViewBuilder
    private func tabButton(_ tab: KlarTab) -> some View {
        let isActive = selectedTab == tab
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20))
                    .scaleEffect(isActive ? 1.15 : 1.0)
                Text(tab.title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(isActive ? .white : KlarColors.inactive)
            .opacity(isActive ? 1.0 : 0.6)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selectedTab)
    }
}
