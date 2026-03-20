import SwiftUI
import Charts

struct ChartDataPoint: Identifiable {
    let id: Int
    let day: Int
    let amount: Double
}

struct SpendingTrendsView: View {
    let transactions: [Transaction]
    var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedTab = 0

    private var isCurrentMonth: Bool {
        let cal = Calendar.current
        let now = Date()
        return selectedMonth == cal.component(.month, from: now) &&
               selectedYear == cal.component(.year, from: now)
    }

    private var dailySpending: [ChartDataPoint] {
        let cal = Calendar.current

        let monthExpenses = transactions.filter {
            $0.amount < 0 &&
            cal.component(.month, from: $0.date) == selectedMonth &&
            cal.component(.year, from: $0.date) == selectedYear
        }

        var dayTotals: [Int: Double] = [:]
        for txn in monthExpenses {
            let day = cal.component(.day, from: txn.date)
            dayTotals[day, default: 0] += abs(txn.amount)
        }

        let maxDay: Int
        if isCurrentMonth {
            maxDay = cal.component(.day, from: Date())
        } else {
            var comps = DateComponents()
            comps.year = selectedYear
            comps.month = selectedMonth
            comps.day = 1
            if let firstOfMonth = cal.date(from: comps),
               let range = cal.range(of: .day, in: .month, for: firstOfMonth) {
                maxDay = range.count
            } else {
                maxDay = dayTotals.keys.max() ?? 28
            }
        }

        guard maxDay >= 1 else { return [] }
        return (1...maxDay).map { day in
            ChartDataPoint(id: day, day: day, amount: dayTotals[day] ?? 0)
        }
    }

    private var cumulativeSpending: [ChartDataPoint] {
        var cumulative: Double = 0
        return dailySpending.enumerated().map { index, entry in
            cumulative += entry.amount
            return ChartDataPoint(id: index, day: entry.day, amount: cumulative)
        }
    }

    private var averageLineData: [ChartDataPoint] {
        let cal = Calendar.current

        var selectedComps = DateComponents()
        selectedComps.year = selectedYear
        selectedComps.month = selectedMonth
        selectedComps.day = 1
        let selectedDate = cal.date(from: selectedComps) ?? Date()

        var monthlyDailyTotals: [[Int: Double]] = []

        for monthsBack in 1...6 {
            guard let targetDate = cal.date(byAdding: .month, value: -monthsBack, to: selectedDate) else { continue }
            let m = cal.component(.month, from: targetDate)
            let y = cal.component(.year, from: targetDate)

            let monthExpenses = transactions.filter {
                $0.amount < 0 &&
                cal.component(.month, from: $0.date) == m &&
                cal.component(.year, from: $0.date) == y
            }

            var dayTotals: [Int: Double] = [:]
            for txn in monthExpenses {
                let day = cal.component(.day, from: txn.date)
                dayTotals[day, default: 0] += abs(txn.amount)
            }
            monthlyDailyTotals.append(dayTotals)
        }

        guard !monthlyDailyTotals.isEmpty else {
            return cumulativeSpending
        }

        let maxDay = dailySpending.count
        guard maxDay >= 1 else { return [] }
        var result: [ChartDataPoint] = []
        var cumAvg: Double = 0

        for day in 1...maxDay {
            var total: Double = 0
            var count: Double = 0
            for monthData in monthlyDailyTotals {
                total += monthData[day] ?? 0
                count += 1
            }
            cumAvg += count > 0 ? total / count : 0
            result.append(ChartDataPoint(id: day, day: day, amount: cumAvg))
        }

        return result
    }

    private var weeklyData: [ChartDataPoint] {
        let cal = Calendar.current

        let referenceDate: Date
        if isCurrentMonth {
            referenceDate = Date()
        } else {
            var comps = DateComponents()
            comps.year = selectedYear
            comps.month = selectedMonth
            comps.day = 1
            if let firstOfMonth = cal.date(from: comps),
               let range = cal.range(of: .day, in: .month, for: firstOfMonth) {
                comps.day = range.count
                referenceDate = cal.date(from: comps) ?? Date()
            } else {
                referenceDate = Date()
            }
        }

        var result: [ChartDataPoint] = []
        for daysAgo in stride(from: 6, through: 0, by: -1) {
            let day = cal.date(byAdding: .day, value: -daysAgo, to: referenceDate)!
            let dayTotal = transactions.filter { txn in
                txn.amount < 0 && cal.isDate(txn.date, inSameDayAs: day)
            }.reduce(0) { $0 + abs($1.amount) }
            let index = 7 - daysAgo
            result.append(ChartDataPoint(id: index, day: index, amount: dayTotal))
        }
        return result
    }

    private var trendPercentage: Double {
        let currentTotal = cumulativeSpending.last?.amount ?? 0
        let avgTotal = averageLineData.last?.amount ?? 0
        guard avgTotal > 0 else { return 0 }
        return ((currentTotal - avgTotal) / avgTotal) * 100
    }

    var body: some View {
        KlarCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "SPENDING TRENDS")

                HStack(spacing: 0) {
                    tabButton("THIS MONTH", index: 0)
                    tabButton("THIS WEEK", index: 1)
                }
                .background(KlarColors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(KlarColors.accent)
                            .frame(width: 16, height: 2)
                        Text("Current Month")
                            .font(KlarFonts.label(10))
                            .foregroundStyle(KlarColors.secondary)
                    }
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 1)
                            .stroke(KlarColors.dropZone, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                            .frame(width: 16, height: 2)
                        Text("Last 6 Months Average")
                            .font(KlarFonts.label(10))
                            .foregroundStyle(KlarColors.secondary)
                    }
                }

                if selectedTab == 0 {
                    monthlyChart
                } else {
                    weeklyChart
                }

                HStack {
                    Text("TREND:")
                        .font(KlarFonts.label(12))
                        .tracking(1)
                        .foregroundStyle(KlarColors.secondary)
                    Text(String(format: "%.1f%% vs avg.", trendPercentage))
                        .font(KlarFonts.label(12))
                        .foregroundStyle(trendPercentage <= 0 ? KlarColors.positive : KlarColors.negative)
                }
            }
        }
    }

    private var monthlyChart: some View {
        Chart {
            ForEach(cumulativeSpending) { entry in
                AreaMark(
                    x: .value("Day", entry.day),
                    y: .value("Amount", entry.amount)
                )
                .foregroundStyle(KlarColors.accent.opacity(0.08))

                LineMark(
                    x: .value("Day", entry.day),
                    y: .value("Amount", entry.amount)
                )
                .foregroundStyle(KlarColors.accent)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
            }

            ForEach(averageLineData) { entry in
                LineMark(
                    x: .value("Day", entry.day),
                    y: .value("Amount", entry.amount),
                    series: .value("Series", "Average")
                )
                .foregroundStyle(KlarColors.dropZone)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: 7)) { _ in
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
    }

    private var weeklyChart: some View {
        Chart {
            ForEach(weeklyData) { entry in
                BarMark(
                    x: .value("Day", entry.day),
                    y: .value("Amount", entry.amount)
                )
                .foregroundStyle(KlarColors.primary.opacity(0.6))
                .cornerRadius(4)
            }
        }
        .chartXAxis {
            AxisMarks { value in
                let label: String = {
                    guard let v = value.as(Int.self) else { return "" }
                    let cal = Calendar.current
                    guard let day = cal.date(byAdding: .day, value: -(7 - v), to: Date()) else { return "" }
                    let f = DateFormatter()
                    f.dateFormat = "EEE"
                    return f.string(from: day)
                }()
                AxisValueLabel(label)
                    .font(.system(size: 9))
                    .foregroundStyle(KlarColors.secondary)
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
    }

    private func tabButton(_ title: String, index: Int) -> some View {
        Button {
            withAnimation(KlarAnimation.springDefault) { selectedTab = index }
            HapticManager.light()
        } label: {
            Text(title)
                .font(KlarFonts.label(12))
                .tracking(0.5)
                .foregroundStyle(selectedTab == index ? KlarColors.primary : KlarColors.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selectedTab == index ? KlarColors.surface : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
