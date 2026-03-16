import SwiftUI
import SwiftData
import Charts

struct VisualizerView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var subscriptions: [Subscription]

    private var currentMonthName: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        return f.string(from: Date()).uppercased()
    }

    private var currentMonthTransactions: [Transaction] {
        let cal = Calendar.current
        let now = Date()
        let month = cal.component(.month, from: now)
        let year = cal.component(.year, from: now)
        return transactions.filter {
            cal.component(.month, from: $0.date) == month &&
            cal.component(.year, from: $0.date) == year
        }
    }

    private var totalIncome: Double {
        currentMonthTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    private var categorySpend: [(String, Double)] {
        var dict: [String: Double] = [:]
        for txn in currentMonthTransactions where txn.type == .expense {
            dict[txn.category, default: 0] += abs(txn.amount)
        }
        return dict.sorted { $0.value > $1.value }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("THE VISUALIZER")
                        .font(KlarFonts.display(28))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                if transactions.isEmpty {
                    emptyState
                } else {
                    // Cash Flow Sankey
                    KlarCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("CASH FLOW (\(currentMonthName))")
                                .font(KlarFonts.heading(18))
                                .foregroundStyle(.white)

                            if totalIncome > 0 && !categorySpend.isEmpty {
                                SankeyDiagram(
                                    income: totalIncome,
                                    categories: categorySpend.map { name, value in
                                        SankeyNode(label: name, value: value, color: KlarColors.categoryColor(for: name))
                                    }
                                )
                                .frame(height: 240)
                            }

                            legendRow
                        }
                    }
                    .padding(.horizontal, 20)

                    // Spending Trends
                    SpendingTrendsView(transactions: Array(transactions))
                        .padding(.horizontal, 20)

                    // Subscription Audit
                    SubscriptionAuditView()
                        .padding(.horizontal, 20)
                }

                Spacer(minLength: 100)
            }
        }
        .background(KlarColors.background)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundStyle(KlarColors.inactive)
            Text("No data to visualize")
                .font(KlarFonts.heading(18))
                .foregroundStyle(KlarColors.secondary)
            Text("Import transactions to see your spending visualized here.")
                .font(KlarFonts.body(14))
                .foregroundStyle(KlarColors.inactive)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
        .padding(.top, 60)
        .frame(maxWidth: .infinity)
    }

    private var legendRow: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
        ], spacing: 8) {
            ForEach(categorySpend.prefix(8), id: \.0) { name, value in
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
