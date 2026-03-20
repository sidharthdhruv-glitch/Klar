import SwiftUI

enum KlarTab: Int, CaseIterable, Identifiable {
    case pulse = 0
    case importHub = 1
    case ledger = 2
    case visualizer = 3
    case settings = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .pulse: return "Pulse"
        case .importHub: return "Import"
        case .ledger: return "Ledger"
        case .visualizer: return "Visualizer"
        case .settings: return "Settings"
        }
    }

    func icon(isSelected: Bool) -> String {
        switch self {
        case .pulse: return isSelected ? "house.fill" : "house"
        case .importHub: return isSelected ? "icloud.and.arrow.down.fill" : "icloud.and.arrow.down"
        case .ledger: return isSelected ? "list.bullet.rectangle.fill" : "list.bullet.rectangle"
        case .visualizer: return isSelected ? "chart.bar.xaxis" : "chart.bar.xaxis"
        case .settings: return isSelected ? "gearshape.fill" : "gearshape"
        }
    }
}

struct KlarTabBar: View {
    @Binding var selectedTab: KlarTab
    @Namespace private var tabAnimation

    var body: some View {
        HStack(spacing: 0) {
            ForEach(KlarTab.allCases) { tab in
                Button {
                    withAnimation(KlarAnimation.springDefault) {
                        selectedTab = tab
                    }
                    HapticManager.light()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon(isSelected: selectedTab == tab))
                            .font(.system(size: 20, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundColor(selectedTab == tab ? KlarColors.accent : .white.opacity(0.5))
                            .symbolEffect(.bounce, value: selectedTab == tab)

                        if selectedTab == tab {
                            Circle()
                                .fill(KlarColors.accent)
                                .frame(width: 4, height: 4)
                                .matchedGeometryEffect(id: "tabIndicator", in: tabAnimation)
                        } else {
                            Circle()
                                .fill(.clear)
                                .frame(width: 4, height: 4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }
}
