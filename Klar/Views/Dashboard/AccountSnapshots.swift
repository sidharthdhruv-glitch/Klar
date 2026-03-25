import SwiftUI
import Charts

struct AccountSnapshotCard: View {
    let account: Account
    let weeklyData: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(account.name.uppercased())
                .font(KlarFonts.label(11))
                .tracking(1)
                .foregroundStyle(KlarColors.secondary)

            Text(CurrencyHelper.format(account.balance))
                .font(KlarFonts.heading(18))
                .monospacedDigit()
                .foregroundStyle(KlarColors.primary)

            SparklineView(data: weeklyData, height: 24)
                .frame(width: 120)
        }
        .padding(14)
        .frame(width: 160)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(KlarColors.border.opacity(0.5), lineWidth: 0.5)
        )
    }
}

struct AccountSnapshots: View {
    let accounts: [Account]
    let weeklyData: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "ACCOUNTS")
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(accounts, id: \.name) { account in
                        AccountSnapshotCard(account: account, weeklyData: weeklyData)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

struct AccountSnapshotsFromTransactions: View {
    let accountBalances: [(name: String, type: AccountType, balance: Double)]
    let weeklyData: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "ACCOUNTS")
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(accountBalances, id: \.name) { item in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: item.type == .savings ? "banknote" : item.type == .credit ? "creditcard" : "wallet.pass")
                                    .font(.system(size: 10))
                                    .foregroundStyle(KlarColors.secondary)
                                Text(item.name.uppercased())
                                    .font(KlarFonts.label(11))
                                    .tracking(1)
                                    .foregroundStyle(KlarColors.secondary)
                            }

                            Text(CurrencyHelper.format(item.balance))
                                .font(KlarFonts.heading(18))
                                .monospacedDigit()
                                .foregroundStyle(item.balance >= 0 ? KlarColors.primary : KlarColors.negative)

                            SparklineView(data: weeklyData, height: 24)
                                .frame(width: 120)
                        }
                        .padding(14)
                        .frame(width: 160)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(KlarColors.border.opacity(0.5), lineWidth: 0.5)
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

struct AccountSnapshotsWithSparklines: View {
    let accountBalances: [(name: String, type: AccountType, balance: Double)]
    let transactions: [Transaction]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "ACCOUNTS")
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(accountBalances, id: \.name) { item in
                        let sparkData = accountSparklineData(for: item.name)

                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: item.type == .savings ? "banknote" : item.type == .credit ? "creditcard" : "wallet.pass")
                                    .font(.system(size: 10))
                                    .foregroundStyle(KlarColors.secondary)
                                Text(item.name.uppercased())
                                    .font(KlarFonts.label(11))
                                    .tracking(1)
                                    .foregroundStyle(KlarColors.secondary)
                            }

                            HStack {
                                Text(CurrencyHelper.format(item.balance))
                                    .font(KlarFonts.heading(18))
                                    .monospacedDigit()
                                    .foregroundStyle(item.balance >= 0 ? KlarColors.primary : KlarColors.negative)

                                Spacer()

                                if sparkData.count > 1 {
                                    SparklineView(data: sparkData, height: 24)
                                        .frame(width: 60)
                                }
                            }
                        }
                        .padding(14)
                        .frame(width: 180)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(KlarColors.border.opacity(0.5), lineWidth: 0.5)
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func accountSparklineData(for accountName: String) -> [Double] {
        let cal = Calendar.current
        let now = Date()
        var dailyTotals: [Double] = []
        var runningBalance: Double = 0

        let accountTxns = transactions
            .filter { $0.account == accountName }
            .sorted { $0.date < $1.date }

        for daysAgo in stride(from: 6, through: 0, by: -1) {
            let day = cal.date(byAdding: .day, value: -daysAgo, to: now)!
            let dayChange = accountTxns.filter { cal.isDate($0.date, inSameDayAs: day) }
                .reduce(0.0) { $0 + $1.amount }
            runningBalance += dayChange
            dailyTotals.append(runningBalance)
        }

        return dailyTotals
    }
}
