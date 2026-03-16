import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query private var transactions: [Transaction]

    private var userName: String { MockData.userName }
    private var totalIncome: Double { MockData.totalIncome }
    private var totalExpense: Double { MockData.totalExpense }
    private var totalBalance: Double { MockData.totalBalance }
    private var categorySpend: [(String, Double)] { MockData.categorySpend }
    private var burnRate: Double { MockData.burnRate }
    private var burnAmount: Double { MockData.burnAmount }
    private var budgetLimit: Double { MockData.budgetLimit }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("HEY, \(userName)")
                        .font(KlarFonts.label(13))
                        .tracking(1)
                        .foregroundStyle(KlarColors.secondary)

                    Text("your dashboard")
                        .font(KlarFonts.display(28))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Burn Rate
                BurnRateView(
                    rate: burnRate,
                    spent: burnAmount,
                    budget: budgetLimit
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
                CategoryBreakdownView(categorySpend: categorySpend)
                    .padding(.horizontal, 20)

                // Account Snapshots
                AccountSnapshots(
                    accounts: MockData.accounts,
                    weeklyData: MockData.weeklySpend
                )

                Spacer(minLength: 100)
            }
        }
        .background(KlarColors.background)
    }
}
