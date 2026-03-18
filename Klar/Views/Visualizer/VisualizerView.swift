import SwiftUI
import SwiftData
import Charts

struct VisualizerView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var subscriptions: [Subscription]
    @State private var selectedMonthOffset: Int = 0

    private var availableMonths: [(month: Int, year: Int, label: String)] {
        let cal = Calendar.current
        var seen: Set<String> = []
        var result: [(month: Int, year: Int, label: String)] = []
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"

        for txn in transactions {
            let m = cal.component(.month, from: txn.date)
            let y = cal.component(.year, from: txn.date)
            let key = "\(y)-\(m)"
            if !seen.contains(key) {
                seen.insert(key)
                var comps = DateComponents()
                comps.year = y
                comps.month = m
                comps.day = 1
                let label = cal.date(from: comps).map { f.string(from: $0).uppercased() } ?? key
                result.append((month: m, year: y, label: label))
            }
        }

        result.sort { ($0.year, $0.month) > ($1.year, $1.month) }

        let nowM = cal.component(.month, from: Date())
        let nowY = cal.component(.year, from: Date())
        if !result.contains(where: { $0.month == nowM && $0.year == nowY }) {
            var comps = DateComponents()
            comps.year = nowY
            comps.month = nowM
            comps.day = 1
            let label = cal.date(from: comps).map { f.string(from: $0).uppercased() } ?? "\(nowY)-\(nowM)"
            result.insert((month: nowM, year: nowY, label: label), at: 0)
        }

        return result
    }

    private var selectedMonth: (month: Int, year: Int) {
        let months = availableMonths
        let index = min(max(selectedMonthOffset, 0), months.count - 1)
        guard !months.isEmpty else {
            let cal = Calendar.current
            return (cal.component(.month, from: Date()), cal.component(.year, from: Date()))
        }
        return (months[index].month, months[index].year)
    }

    private var selectedMonthName: String {
        let months = availableMonths
        let index = min(max(selectedMonthOffset, 0), months.count - 1)
        guard !months.isEmpty else { return "NO DATA" }
        return months[index].label
    }

    private var selectedMonthShortName: String {
        let months = availableMonths
        let index = min(max(selectedMonthOffset, 0), months.count - 1)
        guard !months.isEmpty else { return "" }
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        var comps = DateComponents()
        comps.year = months[index].year
        comps.month = months[index].month
        comps.day = 1
        return Calendar.current.date(from: comps).map { f.string(from: $0).uppercased() } ?? ""
    }

    private var selectedMonthTransactions: [Transaction] {
        let cal = Calendar.current
        let (month, year) = selectedMonth
        return transactions.filter {
            cal.component(.month, from: $0.date) == month &&
            cal.component(.year, from: $0.date) == year
        }
    }

    private var totalIncome: Double {
        selectedMonthTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    private var categorySpend: [(String, Double)] {
        var dict: [String: Double] = [:]
        for txn in selectedMonthTransactions where txn.type == .expense {
            dict[txn.category, default: 0] += abs(txn.amount)
        }
        return dict.sorted { $0.value > $1.value }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack(spacing: 0) {
                    Text("THE ")
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .italic()
                        .foregroundStyle(KlarColors.secondary)
                    Text("VISUALIZER")
                        .font(KlarFonts.display(28))
                        .foregroundStyle(KlarColors.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 16)

                if transactions.isEmpty {
                    emptyState
                } else {

                    // Month Selector
                    if availableMonths.count > 1 {
                        HStack {
                            Button {
                                withAnimation {
                                    selectedMonthOffset = min(selectedMonthOffset + 1, availableMonths.count - 1)
                                }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(selectedMonthOffset < availableMonths.count - 1 ? KlarColors.primary : KlarColors.inactive)
                            }
                            .disabled(selectedMonthOffset >= availableMonths.count - 1)

                            Spacer()
                            Text(selectedMonthName)
                                .font(KlarFonts.heading(16))
                                .foregroundStyle(KlarColors.primary)
                            Spacer()

                            Button {
                                withAnimation {
                                    selectedMonthOffset = max(selectedMonthOffset - 1, 0)
                                }
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(selectedMonthOffset > 0 ? KlarColors.primary : KlarColors.inactive)
                            }
                            .disabled(selectedMonthOffset <= 0)
                        }
                        .padding(.horizontal, 20)
                    }

                    // Cash Flow Sankey
                    KlarCard(dashedBorder: true) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("CASH FLOW (\(selectedMonthShortName))")
                                .font(KlarFonts.heading(18))
                                .foregroundStyle(KlarColors.primary)

                            if totalIncome > 0 && !categorySpend.isEmpty {
                                SankeyDiagram(
                                    income: totalIncome,
                                    categories: categorySpend.map { name, value in
                                        SankeyNode(label: name, value: value, color: KlarColors.categoryColor(for: name))
                                    }
                                )
                                .frame(height: 240)
                            } else if !categorySpend.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(categorySpend.prefix(6), id: \.0) { name, value in
                                        HStack {
                                            Circle()
                                                .fill(KlarColors.categoryColor(for: name))
                                                .frame(width: 8, height: 8)
                                            Text(name)
                                                .font(KlarFonts.body(13))
                                                .foregroundStyle(KlarColors.primary)
                                            Spacer()
                                            Text(CurrencyHelper.format(-value))
                                                .font(KlarFonts.label(13))
                                                .monospacedDigit()
                                                .foregroundStyle(KlarColors.negative)
                                        }
                                    }
                                }
                            }

                            if totalIncome > 0 {
                                Text("TOTAL INCOME (+\(CurrencyHelper.format(totalIncome)))")
                                    .font(KlarFonts.label(12))
                                    .foregroundStyle(KlarColors.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }

                            legendRow
                        }
                    }
                    .padding(.horizontal, 20)

                    // Spending Trends
                    SpendingTrendsView(
                        transactions: Array(transactions),
                        selectedMonth: selectedMonth.month,
                        selectedYear: selectedMonth.year
                    )
                    .padding(.horizontal, 20)

                    // Subscription Audit
                    SubscriptionAuditView()
                        .padding(.horizontal, 20)
                }

                Spacer(minLength: 100)
            }
        }
        .background(KlarColors.background)
        .onAppear {
            autoSelectMonth()
        }
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

    private func autoSelectMonth() {
        if selectedMonthOffset == 0 && selectedMonthTransactions.isEmpty && availableMonths.count > 1 {
            let cal = Calendar.current
            for (index, monthInfo) in availableMonths.enumerated() {
                let hasData = transactions.contains {
                    cal.component(.month, from: $0.date) == monthInfo.month &&
                    cal.component(.year, from: $0.date) == monthInfo.year
                }
                if hasData {
                    selectedMonthOffset = index
                    break
                }
            }
        }
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
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(KlarColors.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}
