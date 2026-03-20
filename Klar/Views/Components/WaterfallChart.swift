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
                let chartHeight = geo.size.height - 30

                ZStack(alignment: .bottom) {
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            VStack(spacing: 4) {
                                Text(KlarChartStyle.formatAmount(step.amount, compact: true))
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundColor(step.type.labelColor)
                                    .opacity(isVisible ? 1 : 0)
                                    .animation(
                                        .easeOut(duration: 0.3).delay(Double(index) * 0.1 + 0.5),
                                        value: isVisible
                                    )

                                Spacer(minLength: 0)

                                WaterfallBar(
                                    step: step,
                                    maxValue: maxValue,
                                    chartHeight: chartHeight,
                                    barWidth: barWidth,
                                    isVisible: isVisible,
                                    delay: Double(index) * 0.1
                                )

                                Text(step.label.prefix(6).uppercased())
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(KlarColors.secondary)
                                    .lineLimit(1)
                                    .frame(width: barWidth)
                            }
                        }
                    }

                    // Connector lines
                    if isVisible {
                        ForEach(0..<max(steps.count - 1, 0), id: \.self) { index in
                            let step = steps[index]
                            let nextStep = steps[index + 1]
                            let xStart = CGFloat(index) * (barWidth + 8) + barWidth
                            let xEnd = CGFloat(index + 1) * (barWidth + 8)

                            let yPosition: CGFloat = {
                                switch step.type {
                                case .income:
                                    return chartHeight * CGFloat(1 - step.runningTotal / maxValue)
                                case .expense:
                                    return chartHeight * CGFloat(1 - step.runningTotal / maxValue)
                                case .balance:
                                    return chartHeight * CGFloat(1 - step.runningTotal / maxValue)
                                }
                            }()

                            Path { path in
                                path.move(to: CGPoint(x: xStart, y: yPosition + 30))
                                path.addLine(to: CGPoint(x: xEnd, y: yPosition + 30))
                            }
                            .stroke(KlarColors.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                        }
                    }
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
            case .income: return Color(hex: "#2D6A4F")
            case .expense: return Color(hex: "#C9505B")
            case .balance: return Color(hex: "#3A6EA5")
            }
        }

        var labelColor: Color {
            switch self {
            case .income: return Color(hex: "#2D6A4F")
            case .expense: return Color(hex: "#C9505B")
            case .balance: return Color(hex: "#3A6EA5")
            }
        }
    }
}

struct WaterfallBar: View {
    let step: WaterfallStep
    let maxValue: Double
    let chartHeight: CGFloat
    let barWidth: CGFloat
    let isVisible: Bool
    let delay: Double

    var body: some View {
        let targetHeight: CGFloat = {
            guard maxValue > 0 else { return 4 }
            switch step.type {
            case .income:
                return chartHeight * CGFloat(step.amount / maxValue)
            case .expense:
                return max(4, chartHeight * CGFloat(step.amount / maxValue))
            case .balance:
                return max(4, chartHeight * CGFloat(step.amount / maxValue))
            }
        }()

        let targetOffset: CGFloat = {
            guard maxValue > 0 else { return 0 }
            switch step.type {
            case .income: return 0
            case .expense:
                return chartHeight * CGFloat(1 - (step.runningTotal + step.amount) / maxValue)
            case .balance: return chartHeight - targetHeight
            }
        }()

        let barColor: Color = step.category.map { KlarColors.categoryColor(for: $0) } ?? step.type.color

        RoundedRectangle(cornerRadius: 4)
            .fill(barColor.opacity(step.type == .expense ? 0.8 : 0.9))
            .frame(width: barWidth, height: isVisible ? targetHeight : 0)
            .offset(y: isVisible ? targetOffset : chartHeight)
            .animation(
                .spring(response: 0.7, dampingFraction: 0.75).delay(delay),
                value: isVisible
            )
    }
}
