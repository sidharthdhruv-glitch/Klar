import SwiftUI

struct NetFlowCard: View {
    let totalIncome: Double
    let totalExpense: Double
    let balance: Double
    let categorySpend: [(String, Double)]

    var body: some View {
        KlarCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "NET FLOW")

                // Balance
                AnimatedNumber(
                    value: balance,
                    font: KlarFonts.display(36),
                    color: .white
                )

                // Inflow/Outflow
                HStack(spacing: 24) {
                    HStack(spacing: 6) {
                        Text("INFLOW")
                            .font(KlarFonts.label(11))
                            .foregroundStyle(KlarColors.secondary)
                        Text(CurrencyHelper.formatSigned(totalIncome))
                            .font(KlarFonts.label(13))
                            .monospacedDigit()
                            .foregroundStyle(KlarColors.positive)
                    }

                    Rectangle()
                        .frame(width: 1, height: 16)
                        .foregroundStyle(KlarColors.barTrack)

                    HStack(spacing: 6) {
                        Text("OUTFLOW")
                            .font(KlarFonts.label(11))
                            .foregroundStyle(KlarColors.secondary)
                        Text(CurrencyHelper.format(-totalExpense))
                            .font(KlarFonts.label(13))
                            .monospacedDigit()
                            .foregroundStyle(KlarColors.negative)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(KlarColors.surfaceElevated)
                .clipShape(Capsule())

                // Mini Sankey
                SankeyDiagram(
                    income: totalIncome,
                    categories: categorySpend.map { name, value in
                        SankeyNode(label: name, value: value, color: KlarColors.categoryColor(for: name))
                    }
                )
                .frame(height: 180)
            }
        }
    }
}
