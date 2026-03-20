import SwiftUI
import Charts

struct BumpChart: View {
    let rankings: [MonthlyRank]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CATEGORY RANKINGS")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.5)
                .foregroundColor(KlarColors.primary)

            Text("6-month trend")
                .font(.system(size: 12))
                .foregroundColor(KlarColors.secondary)

            Chart(rankings) { item in
                LineMark(
                    x: .value("Month", item.month),
                    y: .value("Rank", item.rank)
                )
                .foregroundStyle(KlarColors.categoryColor(for: item.category))
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .interpolationMethod(.monotone)
                .symbol {
                    Circle()
                        .fill(KlarColors.categoryColor(for: item.category))
                        .frame(width: isLatestMonth(item.month) ? 10 : 8,
                               height: isLatestMonth(item.month) ? 10 : 8)
                }
            }
            .chartYScale(domain: .automatic(includesZero: false, reversed: true))
            .chartYAxis {
                AxisMarks { value in
                    if let rank = value.as(Int.self) {
                        AxisValueLabel {
                            Text("#\(rank)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(KlarChartStyle.axisLabelColor)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                        .font(KlarChartStyle.axisLabelFont)
                        .foregroundStyle(KlarChartStyle.axisLabelColor)
                }
            }
            .chartLegend(position: .bottom, alignment: .leading, spacing: 8) {
                let cats = uniqueCategories()
                HStack(spacing: 16) {
                    ForEach(cats, id: \.self) { cat in
                        HStack(spacing: 4) {
                            Circle().fill(KlarColors.categoryColor(for: cat)).frame(width: 6, height: 6)
                            Text(cat.capitalized)
                                .font(.system(size: 10))
                                .foregroundColor(KlarColors.secondary)
                        }
                    }
                }
            }
            .frame(height: 180)
        }
    }

    private func uniqueCategories() -> [String] {
        Array(Set(rankings.map(\.category))).sorted()
    }

    private func isLatestMonth(_ month: Date) -> Bool {
        guard let latest = rankings.map(\.month).max() else { return false }
        return Calendar.current.isDate(month, equalTo: latest, toGranularity: .month)
    }
}
