import SwiftUI
import SwiftData
import Charts

struct VisualizerView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var subscriptions: [Subscription]
    @AppStorage("monthlyBudget") private var monthlyBudget: Double = 50000
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

    private var selectedMonthTransactions: [Transaction] {
        let cal = Calendar.current
        let (month, year) = selectedMonth
        return transactions.filter {
            cal.component(.month, from: $0.date) == month &&
            cal.component(.year, from: $0.date) == year
        }
    }

    private var totalIncome: Double {
        selectedMonthTransactions.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
    }

    private var totalExpense: Double {
        selectedMonthTransactions.filter { $0.amount < 0 }.reduce(0) { $0 + abs($1.amount) }
    }

    private var categorySpend: [(String, Double)] {
        var dict: [String: Double] = [:]
        for txn in selectedMonthTransactions where txn.amount < 0 {
            dict[txn.category, default: 0] += abs(txn.amount)
        }
        return dict.sorted { $0.value > $1.value }
    }

    // MARK: - Sankey data
    private var sankeyFlows: [SankeyFlow] {
        var flows: [SankeyFlow] = categorySpend.map { name, amount in
            SankeyFlow(
                category: name,
                label: name,
                amount: amount,
                color: KlarColors.categoryColor(for: name)
            )
        }
        let savings = max(totalIncome - totalExpense, 0)
        if savings > 0 {
            flows.append(SankeyFlow(
                category: nil,
                label: "Saved",
                amount: savings,
                color: KlarColors.accent
            ))
        }
        return flows
    }

    // MARK: - Calendar heatmap data
    private var dailySpendsForMonth: [DailySpend] {
        let cal = Calendar.current
        let (month, year) = selectedMonth
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let firstOfMonth = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: firstOfMonth) else { return [] }

        let expenseTransactions = selectedMonthTransactions.filter { $0.amount < 0 }

        return range.map { day -> DailySpend in
            var dayComps = DateComponents()
            dayComps.year = year
            dayComps.month = month
            dayComps.day = day
            let date = cal.date(from: dayComps) ?? firstOfMonth

            let dayTxns = expenseTransactions.filter { cal.component(.day, from: $0.date) == day }
            let totalAmount = dayTxns.reduce(0.0) { $0 + abs($1.amount) }

            var catDict: [String: Double] = [:]
            for txn in dayTxns {
                catDict[txn.category, default: 0] += abs(txn.amount)
            }
            let categories = catDict.map { CategorySpend(category: $0.key, amount: $0.value) }

            return DailySpend(date: date, amount: totalAmount, categories: categories)
        }
    }

    private var monthStartDate: Date {
        let cal = Calendar.current
        let (month, year) = selectedMonth
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        return cal.date(from: comps) ?? Date()
    }

    // MARK: - Weekly rhythm data
    private var weeklyRhythmData: [(day: String, amount: Double)] {
        let cal = Calendar.current
        let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        var totals: [Int: Double] = [:]
        var counts: [Int: Int] = [:]

        let expenseTransactions = selectedMonthTransactions.filter { $0.amount < 0 }

        for txn in expenseTransactions {
            let weekday = cal.component(.weekday, from: txn.date)
            let mondayBased = (weekday + 5) % 7
            totals[mondayBased, default: 0] += abs(txn.amount)
            counts[mondayBased, default: 0] += 1
        }

        return (0..<7).map { i in
            let avg = counts[i, default: 0] > 0 ? totals[i, default: 0] / Double(counts[i, default: 1]) : 0
            return (day: dayNames[i], amount: avg)
        }
    }

    // MARK: - Month comparison data
    private var monthComparisonCategories: [CategorySpend] {
        let cal = Calendar.current
        let (month, year) = selectedMonth

        var prevComps = DateComponents()
        prevComps.year = year
        prevComps.month = month
        prevComps.day = 1
        let prevDate = cal.date(from: prevComps).flatMap { cal.date(byAdding: .month, value: -1, to: $0) }
        let prevMonth = prevDate.map { cal.component(.month, from: $0) } ?? month
        let prevYear = prevDate.map { cal.component(.year, from: $0) } ?? year

        let prevTransactions = transactions.filter {
            $0.amount < 0 &&
            cal.component(.month, from: $0.date) == prevMonth &&
            cal.component(.year, from: $0.date) == prevYear
        }

        var prevDict: [String: Double] = [:]
        for txn in prevTransactions {
            prevDict[txn.category, default: 0] += abs(txn.amount)
        }

        return categorySpend.map { name, amount in
            CategorySpend(
                category: name,
                amount: amount,
                previousAmount: prevDict[name] ?? 0
            )
        }
    }

    // MARK: - Bump chart data
    private var bumpChartRankings: [MonthlyRank] {
        let cal = Calendar.current
        let (month, year) = selectedMonth
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let currentMonthDate = cal.date(from: comps) else { return [] }

        var rankings: [MonthlyRank] = []

        for monthsBack in 0..<6 {
            guard let targetDate = cal.date(byAdding: .month, value: -monthsBack, to: currentMonthDate) else { continue }
            let m = cal.component(.month, from: targetDate)
            let y = cal.component(.year, from: targetDate)

            let monthTxns = transactions.filter {
                $0.amount < 0 &&
                cal.component(.month, from: $0.date) == m &&
                cal.component(.year, from: $0.date) == y
            }

            var catTotals: [String: Double] = [:]
            for txn in monthTxns {
                catTotals[txn.category, default: 0] += abs(txn.amount)
            }

            let sorted = catTotals.sorted { $0.value > $1.value }
            for (rank, item) in sorted.prefix(5).enumerated() {
                rankings.append(MonthlyRank(
                    month: targetDate,
                    category: item.key,
                    rank: rank + 1,
                    amount: item.value
                ))
            }
        }

        return rankings
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

                    // 1. Sankey Diagram (Hero)
                    if totalIncome > 0 || totalExpense > 0 {
                        KlarCard(dashedBorder: true) {
                            SankeyDiagramView(
                                income: max(totalIncome, totalExpense),
                                flows: sankeyFlows,
                                monthLabel: selectedMonthName
                            )
                        }
                        .padding(.horizontal, 20)
                    }

                    // 2. Calendar Heatmap
                    if !dailySpendsForMonth.isEmpty {
                        KlarCard(dashedBorder: true) {
                            CalendarHeatmap(
                                dailySpends: dailySpendsForMonth,
                                month: monthStartDate
                            )
                        }
                        .padding(.horizontal, 20)
                    }

                    // 3. Stacked Area (Spending Trends)
                    if !dailySpendsForMonth.isEmpty && dailySpendsForMonth.contains(where: { $0.amount > 0 }) {
                        KlarCard(dashedBorder: true) {
                            StackedAreaSpending(
                                dailyData: dailySpendsForMonth,
                                budgetLimit: monthlyBudget
                            )
                        }
                        .padding(.horizontal, 20)
                    }

                    // 4. Weekly Rhythm
                    if weeklyRhythmData.contains(where: { $0.amount > 0 }) {
                        KlarCard(dashedBorder: true) {
                            WeeklyRhythmBars(dayAverages: weeklyRhythmData)
                        }
                        .padding(.horizontal, 20)
                    }

                    // 5. Month-over-Month Comparison
                    if !monthComparisonCategories.isEmpty {
                        KlarCard(dashedBorder: true) {
                            MonthComparisonBars(categories: monthComparisonCategories)
                        }
                        .padding(.horizontal, 20)
                    }

                    // 6. Bump Chart (Category Rankings)
                    if !bumpChartRankings.isEmpty {
                        KlarCard(dashedBorder: true) {
                            BumpChart(rankings: bumpChartRankings)
                        }
                        .padding(.horizontal, 20)
                    }

                    // 7. Subscription Audit (kept)
                    SubscriptionAuditView()
                        .padding(.horizontal, 20)
                }

                Spacer(minLength: 20)
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
}
