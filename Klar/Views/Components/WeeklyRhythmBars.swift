import SwiftUI
import Charts

struct WeeklyRhythmBars: View {
    let dayAverages: [(day: String, amount: Double)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WEEKLY RHYTHM")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.5)
                .foregroundColor(KlarColors.primary)

            let maxAmount = dayAverages.map(\.amount).max() ?? 1
            let avgAmount = dayAverages.map(\.amount).reduce(0, +) / max(Double(dayAverages.count), 1)

            Chart {
                ForEach(dayAverages, id: \.day) { item in
                    BarMark(
                        x: .value("Day", item.day),
                        y: .value("Amount", item.amount)
                    )
                    .foregroundStyle(barColor(for: item.amount, max: maxAmount))
                    .cornerRadius(4)
                    .annotation(position: .top) {
                        if item.amount == dayAverages.map(\.amount).max() ||
                           item.amount == dayAverages.map(\.amount).min() {
                            Text(KlarChartStyle.formatAmount(item.amount, compact: true))
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundColor(barLabelColor(for: item.amount, max: maxAmount))
                        }
                    }
                }

                RuleMark(y: .value("Average", avgAmount))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(KlarColors.secondary.opacity(0.5))
                    .annotation(position: .trailing, alignment: .leading) {
                        Text("avg")
                            .font(.system(size: 9))
                            .foregroundColor(KlarColors.secondary)
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
            .frame(height: 150)

            if let heaviest = dayAverages.max(by: { $0.amount < $1.amount }),
               let lightest = dayAverages.min(by: { $0.amount < $1.amount }),
               lightest.amount > 0 {
                let ratio = Int(heaviest.amount / lightest.amount)
                if ratio > 1 {
                    Text("You spend \(ratio)x more on \(heaviest.day)s than \(lightest.day)s")
                        .font(.system(size: 12))
                        .foregroundColor(KlarColors.secondary)
                }
            }
        }
    }

    private func barColor(for amount: Double, max: Double) -> Color {
        guard max > 0 else { return Color(hex: "#E8D9A8") }
        let ratio = amount / max
        if ratio > 0.8 { return Color(hex: "#C9505B").opacity(0.85) }
        if ratio > 0.5 { return Color(hex: "#C8A84E") }
        return Color(hex: "#E8D9A8")
    }

    private func barLabelColor(for amount: Double, max: Double) -> Color {
        guard max > 0 else { return KlarColors.secondary }
        let ratio = amount / max
        if ratio > 0.8 { return Color(hex: "#C9505B") }
        return KlarColors.secondary
    }
}
