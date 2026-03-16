import SwiftUI
import Charts

struct SpendingTrendsView: View {
    @State private var selectedTab = 0

    var body: some View {
        KlarCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "SPENDING TRENDS")

                // Tab selector
                HStack(spacing: 0) {
                    tabButton("THIS MONTH", index: 0)
                    tabButton("THIS WEEK", index: 1)
                }
                .background(KlarColors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Legend
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.white)
                            .frame(width: 16, height: 2)
                        Text("Current Month")
                            .font(KlarFonts.label(10))
                            .foregroundStyle(KlarColors.secondary)
                    }
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 1)
                            .stroke(KlarColors.secondary, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                            .frame(width: 16, height: 2)
                        Text("Last 6 Months Average")
                            .font(KlarFonts.label(10))
                            .foregroundStyle(KlarColors.secondary)
                    }
                }

                // Chart
                Chart {
                    let data = selectedTab == 0 ? MockData.monthlyTrend : Array(MockData.monthlyTrend.prefix(7))
                    let avgData = selectedTab == 0 ? MockData.sixMonthAvg : Array(MockData.sixMonthAvg.prefix(7))

                    ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                        AreaMark(
                            x: .value("Day", index + 1),
                            y: .value("Amount", value)
                        )
                        .foregroundStyle(.white.opacity(0.05))

                        LineMark(
                            x: .value("Day", index + 1),
                            y: .value("Amount", value)
                        )
                        .foregroundStyle(.white)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                    }

                    ForEach(Array(avgData.enumerated()), id: \.offset) { index, value in
                        LineMark(
                            x: .value("Day", index + 1),
                            y: .value("Amount", value),
                            series: .value("Series", "Average")
                        )
                        .foregroundStyle(KlarColors.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: 7)) { value in
                        AxisValueLabel()
                            .foregroundStyle(KlarColors.secondary)
                            .font(.system(size: 10))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(CurrencyHelper.formatCompact(v))
                                    .font(.system(size: 9))
                                    .foregroundStyle(KlarColors.secondary)
                            }
                        }
                    }
                }
                .frame(height: 180)

                // Trend stat
                HStack {
                    Text("TREND:")
                        .font(KlarFonts.label(12))
                        .tracking(1)
                        .foregroundStyle(KlarColors.secondary)
                    Text("-4.5% vs avg.")
                        .font(KlarFonts.label(12))
                        .foregroundStyle(KlarColors.positive)
                }
            }
        }
    }

    private func tabButton(_ title: String, index: Int) -> some View {
        Button {
            withAnimation { selectedTab = index }
        } label: {
            Text(title)
                .font(KlarFonts.label(12))
                .tracking(0.5)
                .foregroundStyle(selectedTab == index ? .white : KlarColors.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selectedTab == index ? KlarColors.surface : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
