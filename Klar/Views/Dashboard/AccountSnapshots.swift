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

            Chart {
                ForEach(Array(weeklyData.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("Day", index),
                        y: .value("Amount", value)
                    )
                    .foregroundStyle(KlarColors.positive)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))

                    AreaMark(
                        x: .value("Day", index),
                        y: .value("Amount", value)
                    )
                    .foregroundStyle(KlarColors.positive.opacity(0.1))
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 40)
        }
        .padding(14)
        .frame(width: 160)
        .background(KlarColors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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

                            Chart {
                                ForEach(Array(weeklyData.enumerated()), id: \.offset) { index, value in
                                    LineMark(
                                        x: .value("Day", index),
                                        y: .value("Amount", value)
                                    )
                                    .foregroundStyle(KlarColors.positive)
                                    .lineStyle(StrokeStyle(lineWidth: 1.5))

                                    AreaMark(
                                        x: .value("Day", index),
                                        y: .value("Amount", value)
                                    )
                                    .foregroundStyle(KlarColors.positive.opacity(0.1))
                                }
                            }
                            .chartXAxis(.hidden)
                            .chartYAxis(.hidden)
                            .frame(height: 40)
                        }
                        .padding(14)
                        .frame(width: 160)
                        .background(KlarColors.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}
