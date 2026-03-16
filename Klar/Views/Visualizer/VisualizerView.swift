import SwiftUI
import Charts

struct VisualizerView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("THE VISUALIZER")
                        .font(KlarFonts.display(28))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Cash Flow Sankey
                KlarCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("CASH FLOW (MARCH)")
                            .font(KlarFonts.heading(18))
                            .foregroundStyle(.white)

                        SankeyDiagram(
                            income: MockData.totalIncome,
                            categories: MockData.categorySpend.map { name, value in
                                SankeyNode(label: name, value: value, color: KlarColors.categoryColor(for: name))
                            }
                        )
                        .frame(height: 240)

                        // Legend
                        legendRow
                    }
                }
                .padding(.horizontal, 20)

                // Spending Trends
                SpendingTrendsView()
                    .padding(.horizontal, 20)

                // Subscription Audit
                SubscriptionAuditView()
                    .padding(.horizontal, 20)

                Spacer(minLength: 100)
            }
        }
        .background(KlarColors.background)
    }

    private var legendRow: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
        ], spacing: 8) {
            ForEach(MockData.categorySpend.prefix(8), id: \.0) { name, value in
                HStack(spacing: 4) {
                    Circle()
                        .fill(KlarColors.categoryColor(for: name))
                        .frame(width: 6, height: 6)
                    Text(name.uppercased())
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(KlarColors.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}
