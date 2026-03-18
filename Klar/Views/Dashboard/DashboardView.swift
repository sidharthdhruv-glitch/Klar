import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var accounts: [Account]

    @AppStorage("userName") private var userName = "User"
    @AppStorage("monthlyBudget") private var monthlyBudget: Double = 50000

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

    private var totalExpense: Double {
        currentMonthTransactions.filter { $0.type == .expense }.reduce(0) { $0 + abs($1.amount) }
    }

    private var totalBalance: Double {
        totalIncome - totalExpense
    }

    private var categorySpend: [(String, Double)] {
        var dict: [String: Double] = [:]
        for txn in currentMonthTransactions where txn.type == .expense {
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
            let dayTotal = transactions.filter { txn in
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

                Spacer(minLength: 100)
            }
        }
        .background(KlarColors.background)
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
