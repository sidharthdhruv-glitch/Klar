import SwiftUI
import Charts

struct StackedPoint: Identifiable {
    let id = UUID()
    let date: Date
    let category: String
    let yStart: Double
    let yEnd: Double
}

struct StackedAreaSpending: View {
    let dailyData: [DailySpend]
    let budgetLimit: Double
    @State private var selectedDate: Date?
    @State private var touchX: CGFloat?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SPENDING TRENDS")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.5)
                .foregroundColor(KlarColors.primary)

            Chart {
                ForEach(accumulatedData()) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        yStart: .value("Start", point.yStart),
                        yEnd: .value("End", point.yEnd)
                    )
                    .foregroundStyle(KlarColors.categoryColor(for: point.category).opacity(0.5))
                    .interpolationMethod(.catmullRom)
                }

                RuleMark(y: .value("Budget", budgetLimit))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [6, 4]))
                    .foregroundStyle(Color(hex: "#C9505B").opacity(0.6))
                    .annotation(position: .trailing, alignment: .leading) {
                        Text("Budget")
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: "#C9505B"))
                    }

                if let date = selectedDate {
                    RuleMark(x: .value("Selected", date))
                        .foregroundStyle(KlarColors.primary.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) {
                    AxisValueLabel(format: .dateTime.day())
                        .font(KlarChartStyle.axisLabelFont)
                        .foregroundStyle(KlarChartStyle.axisLabelColor)
                    AxisGridLine()
                        .foregroundStyle(KlarChartStyle.gridLineColor)
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
                    AxisGridLine()
                        .foregroundStyle(KlarChartStyle.gridLineColor)
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let plotFrame = geo[proxy.plotFrame!]
                                    let x = value.location.x - plotFrame.origin.x
                                    guard x >= 0, x <= plotFrame.width else { return }
                                    if let date: Date = proxy.value(atX: value.location.x) {
                                        selectedDate = date
                                        touchX = value.location.x
                                        HapticManager.selection()
                                    }
                                }
                                .onEnded { _ in
                                    selectedDate = nil
                                    touchX = nil
                                }
                        )
                }
            }
            .frame(height: 200)

            if let date = selectedDate {
                let dayData = findDailySpend(for: date)
                if let dayData, !dayData.categories.isEmpty {
                    HStack(spacing: 12) {
                        ForEach(dayData.categories.sorted(by: { $0.amount > $1.amount }).prefix(4)) { cat in
                            VStack(spacing: 2) {
                                Circle().fill(KlarColors.categoryColor(for: cat.category)).frame(width: 6, height: 6)
                                Text(KlarChartStyle.formatAmount(cat.amount, compact: true))
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundColor(KlarColors.primary)
                            }
                        }
                    }
                    .padding(8)
                    .background(KlarColors.cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                    .transition(.opacity)
                }
            }
        }
    }

    private func accumulatedData() -> [StackedPoint] {
        var result: [StackedPoint] = []
        var cumulativeTotals: [String: Double] = [:]

        let allCategories: [String] = {
            var cats = Set<String>()
            for day in dailyData {
                for cat in day.categories { cats.insert(cat.category) }
            }
            return cats.sorted()
        }()

        let sortedDays = dailyData.sorted { $0.date < $1.date }
        for day in sortedDays {
            var catAmounts: [String: Double] = [:]
            for cat in day.categories {
                catAmounts[cat.category, default: 0] += cat.amount
            }

            for cat in allCategories {
                cumulativeTotals[cat, default: 0] += catAmounts[cat] ?? 0
            }

            var yOffset: Double = 0
            for cat in allCategories {
                let cumAmount = cumulativeTotals[cat] ?? 0
                if cumAmount > 0 {
                    result.append(StackedPoint(
                        date: day.date,
                        category: cat,
                        yStart: yOffset,
                        yEnd: yOffset + cumAmount
                    ))
                    yOffset += cumAmount
                }
            }
        }
        return result
    }

    private func findDailySpend(for date: Date) -> DailySpend? {
        dailyData.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
}
