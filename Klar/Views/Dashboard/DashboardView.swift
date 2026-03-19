import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var accounts: [Account]

    @AppStorage("userName") private var userName = "User"
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

        // Always include current month
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

    private var selectedMonthLabel: String {
        let months = availableMonths
        let index = min(max(selectedMonthOffset, 0), months.count - 1)
        guard !months.isEmpty else { return "" }
        return months[index].label
    }

    private var activeTransactions: [Transaction] {
        let cal = Calendar.current
        let (month, year) = selectedMonth
        return transactions.filter {
            cal.component(.month, from: $0.date) == month &&
            cal.component(.year, from: $0.date) == year
        }
    }

    private var totalIncome: Double {
        activeTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    private var totalExpense: Double {
        activeTransactions.filter { $0.type == .expense }.reduce(0) { $0 + abs($1.amount) }
    }

    private var totalBalance: Double {
        totalIncome - totalExpense
    }

    private var categorySpend: [(String, Double)] {
        var dict: [String: Double] = [:]
        for txn in activeTransactions where txn.type == .expense {
            dict[txn.category, default: 0] += abs(txn.amount)
        }
        return dict.sorted { $0.value > $1.value }
    }

    private var burnRate: Double {
        guard monthlyBudget > 0 else { return 0 }
        return totalExpense / monthlyBudget
    }

    private var weeklySpend: [Double] {
        let cal = Calendar.current
        let now = Date()
        var dailyTotals: [Double] = []
        for daysAgo in stride(from: 6, through: 0, by: -1) {
            let day = cal.date(byAdding: .day, value: -daysAgo, to: now)!
            let dayTotal = activeTransactions.filter { txn in
                txn.type == .expense && cal.isDate(txn.date, inSameDayAs: day)
            }.reduce(0) { $0 + abs($1.amount) }
            dailyTotals.append(dayTotal)
        }
        return dailyTotals
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(KlarColors.accent.opacity(0.15))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "creditcard.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(KlarColors.accent)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("HELLO, \(userName.uppercased())")
                            .font(KlarFonts.display(22))
                            .foregroundStyle(KlarColors.primary)
                        Text("YOUR DASHBOARD")
                            .font(KlarFonts.label(12))
                            .tracking(1)
                            .foregroundStyle(KlarColors.secondary)
                    }

                    Spacer()

                    Circle()
                        .stroke(KlarColors.searchHighlight, lineWidth: 2)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(KlarColors.searchHighlight)
                        )
                }
                .padding(.horizontal, 20)
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
                            Text(selectedMonthLabel)
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

                    // Total Balance Card
                    KlarCard(dashedBorder: true) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("TOTAL BALANCE")
                                    .font(KlarFonts.heading(20))
                                    .foregroundStyle(KlarColors.primary)
                                Spacer()
                                HStack(spacing: 4) {
                                    Text("ALL ACCOUNTS")
                                        .font(KlarFonts.label(11))
                                        .foregroundStyle(KlarColors.secondary)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 10))
                                        .foregroundStyle(KlarColors.secondary)
                                }
                            }

                            HStack(spacing: 12) {
                                AnimatedNumber(
                                    value: totalBalance,
                                    font: KlarFonts.display(28),
                                    color: KlarColors.primary
                                )

                                if totalBalance != 0 {
                                    let pct = totalIncome > 0 ? ((totalBalance) / totalIncome) * 100 : 0
                                    Text(String(format: "%+.1f%%", pct))
                                        .font(KlarFonts.label(13))
                                        .foregroundStyle(KlarColors.positive)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    // Net Flow
                    NetFlowCard(
                        totalIncome: totalIncome,
                        totalExpense: totalExpense,
                        balance: totalBalance,
                        categorySpend: categorySpend
                    )
                    .padding(.horizontal, 20)

                    // Category Breakdown
                    if !categorySpend.isEmpty {
                        CategoryBreakdownView(categorySpend: categorySpend)
                            .padding(.horizontal, 20)
                    }

                    // Burn Rate
                    BurnRateView(
                        rate: burnRate,
                        spent: totalExpense,
                        budget: monthlyBudget
                    )
                    .padding(.horizontal, 20)

                    // Account Snapshots
                    if !accounts.isEmpty {
                        AccountSnapshots(
                            accounts: Array(accounts),
                            weeklyData: weeklySpend
                        )
                    }
                }

                Spacer(minLength: 20)
            }
        }
        .background(KlarColors.background)
        .onAppear {
            autoSelectMonth()
        }
    }

    private func autoSelectMonth() {
        // If current month has no data, auto-select the first month that does
        if activeTransactions.isEmpty && availableMonths.count > 1 {
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

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(KlarColors.inactive)

            Text("No transactions yet")
                .font(KlarFonts.heading(18))
                .foregroundStyle(KlarColors.secondary)

            Text("Import a bank statement from the Import tab to get started.")
                .font(KlarFonts.body(14))
                .foregroundStyle(KlarColors.inactive)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
        .padding(.top, 60)
        .frame(maxWidth: .infinity)
    }
}
