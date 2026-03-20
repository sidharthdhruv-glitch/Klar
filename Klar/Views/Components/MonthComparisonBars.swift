import SwiftUI
import Charts

struct MonthComparisonBars: View {
    let categories: [CategorySpend]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("VS LAST MONTH")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(1.5)
                    .foregroundColor(KlarColors.primary)
                Spacer()
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(KlarColors.secondary.opacity(0.25))
                            .frame(width: 10, height: 10)
                        Text("Last month")
                            .font(.system(size: 9))
                            .foregroundColor(KlarColors.secondary)
                    }
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(KlarColors.secondary)
                            .frame(width: 10, height: 10)
                        Text("This month")
                            .font(.system(size: 9))
                            .foregroundColor(KlarColors.secondary)
                    }
                }
            }

            Chart {
                ForEach(categories) { item in
                    BarMark(
                        x: .value("Category", item.category),
                        y: .value("Amount", item.previousAmount)
                    )
                    .foregroundStyle(KlarColors.categoryColor(for: item.category).opacity(0.2))
                    .position(by: .value("Period", "Last"))
                    .cornerRadius(4)

                    BarMark(
                        x: .value("Category", item.category),
                        y: .value("Amount", item.amount)
                    )
                    .foregroundStyle(KlarColors.categoryColor(for: item.category))
                    .position(by: .value("Period", "This"))
                    .cornerRadius(4)
                    .annotation(position: .top) {
                        let delta = item.previousAmount > 0
                            ? ((item.amount - item.previousAmount) / item.previousAmount) * 100
                            : 0
                        if abs(delta) > 5 {
                            Text(String(format: "%+.0f%%", delta))
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundColor(delta > 0 ? Color(hex: "#C9505B") : Color(hex: "#2D6A4F"))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(KlarChartStyle.axisLabelColor)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    if let amount = value.as(Double.self) {
                        AxisValueLabel {
                            Text(KlarChartStyle.formatAmount(amount, compact: true))
                                .font(KlarChartStyle.axisLabelFont)
                                .foregroundStyle(KlarChartStyle.axisLabelColor)
                        }
                    }
                }
            }
            .frame(height: 180)
        }
    }
}
