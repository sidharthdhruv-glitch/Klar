import SwiftUI

struct WaterfallChart: View {
    let income: Double
    let expenses: [CategorySpend]
    let savings: Double

    @State private var isVisible = false

    private var steps: [WaterfallStep] {
        var result: [WaterfallStep] = []

        result.append(WaterfallStep(
            label: "Income",
            amount: income,
            runningTotal: income,
            type: .income
        ))

        var running = income
        let sortedExpenses = expenses.sorted { $0.amount > $1.amount }
        for expense in sortedExpenses where expense.amount > 0 {
            running -= expense.amount
            result.append(WaterfallStep(
                label: expense.category,
                amount: expense.amount,
                runningTotal: running,
                type: .expense,
                category: expense.category
            ))
        }

        result.append(WaterfallStep(
            label: "Saved",
            amount: max(savings, 0),
            runningTotal: max(savings, 0),
            type: .balance
        ))

        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("MONEY FLOW")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.5)
                .foregroundColor(KlarColors.primary)
                .padding(.bottom, 16)

            GeometryReader { geo in
                let barWidth = max(20, (geo.size.width - CGFloat(steps.count - 1) * 8) / CGFloat(steps.count))
                let maxValue = max(income, 1)
                let labelAreaHeight: CGFloat = 32
                let chartHeight = geo.size.height - labelAreaHeight

                VStack(spacing: 0) {
                    // Chart area
                    ZStack(alignment: .bottomLeading) {
                        // Bars
                        HStack(alignment: .bottom, spacing: 8) {
                            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                                let barHeight = barHeight(for: step, maxValue: maxValue, chartHeight: chartHeight)
                                let bottomPad = bottomPadding(for: step, maxValue: maxValue, chartHeight: chartHeight)

                                VStack(spacing: 2) {
                                    // Amount label above bar
                                    Text(KlarChartStyle.formatAmount(step.amount, compact: true))
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .foregroundColor(step.type.labelColor)
                                        .opacity(isVisible ? 1 : 0)
                                        .animation(
                                            .easeOut(duration: 0.3).delay(Double(index) * 0.1 + 0.5),
                                            value: isVisible
                                        )

                                    // The bar itself
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill((step.category.map { KlarColors.categoryColor(for: $0) } ?? step.type.color).opacity(step.type == .expense ? 0.8 : 0.9))
                                        .frame(width: barWidth, height: isVisible ? barHeight : 0)
                                        .animation(
                                            .spring(response: 0.7, dampingFraction: 0.75).delay(Double(index) * 0.1),
                                            value: isVisible
                                        )

                                    // Space below bar to position it correctly
                                    if bottomPad > 0 {
                                        Spacer()
                                            .frame(height: isVisible ? bottomPad : 0)
                                            .animation(
                                                .spring(response: 0.7, dampingFraction: 0.75).delay(Double(index) * 0.1),
                                                value: isVisible
                                            )
                                    }
                                }
                                .frame(height: chartHeight)
                            }
                        }

                        // Connector lines
                        if isVisible {
                            ForEach(0..<max(steps.count - 1, 0), id: \.self) { index in
                                let step = steps[index]
                                let xStart = CGFloat(index) * (barWidth + 8) + barWidth
                                let xEnd = CGFloat(index + 1) * (barWidth + 8)
                                let yFromBottom = chartHeight * CGFloat(step.runningTotal / maxValue)

                                Path { path in
                                    path.move(to: CGPoint(x: xStart, y: chartHeight - yFromBottom))
                                    path.addLine(to: CGPoint(x: xEnd, y: chartHeight - yFromBottom))
                                }
                                .stroke(KlarColors.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                            }
                        }
                    }
                    .frame(height: chartHeight)

                    // Labels row
                    HStack(spacing: 8) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                            Text(step.label.prefix(6).uppercased())
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(KlarColors.secondary)
                                .lineLimit(1)
                                .frame(width: barWidth)
                        }
                    }
                    .frame(height: labelAreaHeight)
                }
            }
            .frame(height: 180)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }

    private func barHeight(for step: WaterfallStep, maxValue: Double, chartHeight: CGFloat) -> CGFloat {
        guard maxValue > 0 else { return 4 }
        return max(4, chartHeight * CGFloat(step.amount / maxValue))
    }

    private func bottomPadding(for step: WaterfallStep, maxValue: Double, chartHeight: CGFloat) -> CGFloat {
        guard maxValue > 0 else { return 0 }
        switch step.type {
        case .income:
            return 0
        case .expense:
            return chartHeight * CGFloat(step.runningTotal / maxValue)
        case .balance:
            return 0
        }
    }
}

struct WaterfallStep {
    let label: String
    let amount: Double
    let runningTotal: Double
    let type: StepType
    var category: String? = nil

    enum StepType {
        case income, expense, balance

        var color: Color {
            switch self {
            case .income: return KlarColors.positive
            case .expense: return KlarColors.negative
            case .balance: return KlarColors.accent
            }
        }

        var labelColor: Color {
            switch self {
            case .income: return KlarColors.positive
            case .expense: return KlarColors.negative
            case .balance: return KlarColors.accent
            }
        }
    }
}
