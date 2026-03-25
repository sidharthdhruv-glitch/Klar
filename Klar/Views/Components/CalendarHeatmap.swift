import SwiftUI

struct CalendarHeatmap: View {
    let dailySpends: [DailySpend]
    let month: Date

    @State private var selectedDay: DailySpend?
    @State private var isVisible = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    private var maxSpend: Double {
        dailySpends.map(\.amount).max() ?? 1
    }

    private func colorForAmount(_ amount: Double) -> Color {
        let ratio = maxSpend > 0 ? amount / maxSpend : 0
        if ratio < 0.01 { return KlarColors.barTrack }
        if ratio < 0.25 { return KlarColors.food.opacity(0.4) }
        if ratio < 0.50 { return KlarColors.accent.opacity(0.6) }
        if ratio < 0.75 { return KlarColors.accent.opacity(0.8) }
        return KlarColors.negative
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SPENDING CALENDAR")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(1.5)
                    .foregroundColor(KlarColors.primary)
                Spacer()
                HStack(spacing: 3) {
                    Text("Less").font(.system(size: 9)).foregroundColor(KlarColors.secondary)
                    ForEach([0.0, 0.15, 0.4, 0.65, 0.9], id: \.self) { ratio in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(colorForAmount(ratio * maxSpend))
                            .frame(width: 12, height: 12)
                    }
                    Text("More").font(.system(size: 9)).foregroundColor(KlarColors.secondary)
                }
            }

            HStack(spacing: 4) {
                ForEach(dayLabels, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(KlarColors.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 4) {
                let firstWeekday = Calendar.current.component(.weekday, from: startOfMonth(month))
                let offset = (firstWeekday + 5) % 7

                ForEach(0..<offset, id: \.self) { _ in
                    Color.clear.frame(height: 28)
                }

                ForEach(Array(dailySpends.enumerated()), id: \.element.id) { index, day in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colorForAmount(day.amount))
                        .frame(height: 28)
                        .overlay(
                            Text("\(Calendar.current.component(.day, from: day.date))")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(day.amount > 0 ? KlarColors.primary.opacity(0.6) : KlarColors.secondary.opacity(0.4))
                        )
                        .overlay(
                            selectedDay?.id == day.id ?
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(KlarColors.primary, lineWidth: 1.5) : nil
                        )
                        .scaleEffect(isVisible ? 1 : 0.5)
                        .opacity(isVisible ? 1 : 0)
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.7)
                            .delay(Double(index) * 0.015),
                            value: isVisible
                        )
                        .onTapGesture {
                            withAnimation(KlarChartStyle.chartInteractionAnimation) {
                                selectedDay = selectedDay?.id == day.id ? nil : day
                            }
                            HapticManager.light()
                        }
                }
            }

            // Insights
            insightsRow

            if let selected = selectedDay {
                SelectedDayDetail(day: selected)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            withAnimation {
                isVisible = true
            }
        }
    }

    private var insightsRow: some View {
        HStack(spacing: 16) {
            if let heaviestDay = dailySpends.max(by: { $0.amount < $1.amount }), heaviestDay.amount > 0 {
                InsightChip(
                    icon: "flame.fill",
                    text: "Heaviest: \(dayOfWeekName(heaviestDay.date))",
                    detail: KlarChartStyle.formatAmount(heaviestDay.amount),
                    color: KlarColors.negative
                )
            }

            let streakDays = longestNoSpendStreak(dailySpends)
            if streakDays > 1 {
                InsightChip(
                    icon: "trophy.fill",
                    text: "\(streakDays)-day no-spend streak",
                    detail: nil,
                    color: KlarColors.positive
                )
            }
        }
    }

    private func startOfMonth(_ date: Date) -> Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date))!
    }

    private func dayOfWeekName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private func longestNoSpendStreak(_ days: [DailySpend]) -> Int {
        var maxStreak = 0, currentStreak = 0
        for day in days {
            if day.amount == 0 { currentStreak += 1; maxStreak = max(maxStreak, currentStreak) }
            else { currentStreak = 0 }
        }
        return maxStreak
    }
}

struct InsightChip: View {
    let icon: String
    let text: String
    let detail: String?
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10)).foregroundColor(color)
            Text(text).font(.system(size: 11, weight: .medium)).foregroundColor(KlarColors.primary)
            if let detail {
                Text(detail).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundColor(color)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(KlarColors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct SelectedDayDetail: View {
    let day: DailySpend

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let formatter = DateFormatter()
            let _ = formatter.dateFormat = "EEEE, MMM d"
            Text(formatter.string(from: day.date))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(KlarColors.primary)
            Text("Total: \(KlarChartStyle.formatAmount(day.amount))")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(KlarColors.primary)

            ForEach(day.categories.sorted(by: { $0.amount > $1.amount }).prefix(3)) { cat in
                HStack {
                    CategoryPill(name: cat.category, color: KlarColors.categoryColor(for: cat.category))
                    Spacer()
                    Text(KlarChartStyle.formatAmount(cat.amount))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(KlarColors.primary)
                }
            }
        }
        .padding(16)
        .background(KlarColors.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(KlarColors.border, lineWidth: 1))
    }
}
