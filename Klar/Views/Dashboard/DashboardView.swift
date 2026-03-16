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
                VStack(alignment: .leading, spacing: 4) {
                    Text("HEY, \(userName.uppercased())")
                        .font(KlarFonts.label(13))
                        .tracking(1)
                        .foregroundStyle(KlarColors.secondary)

                    Text("your dashboard")
                        .font(KlarFonts.display(28))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                if transactions.isEmpty {
                    emptyState
                } else {
                    // Burn Rate
                    BurnRateView(
                        rate: burnRate,
                        spent: totalExpense,
                        budget: monthlyBudget
                    )
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
