import SwiftUI

struct SankeyNode: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let color: Color
}

struct SankeyDiagram: View {
    let income: Double
    let categories: [SankeyNode]
    @State private var animationProgress: CGFloat = 0

    private var totalSpend: Double {
        categories.reduce(0.0) { $0 + $1.value }
    }

    private var savings: Double {
        max(income - totalSpend, 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Income bar at top
            incomeBar
                .padding(.bottom, 16)

            // Flow connections + category bars
            GeometryReader { geo in
                let barWidth: CGFloat = geo.size.width
                let availableHeight = geo.size.height

                ZStack(alignment: .top) {
                    // Category rows
                    VStack(spacing: 6) {
                        ForEach(Array(categories.enumerated()), id: \.element.id) { index, node in
                            let proportion = income > 0 ? node.value / income : 0
                            let nodeWidth = max(barWidth * CGFloat(proportion) * animationProgress, 0)

                            HStack(spacing: 10) {
                                // Category bar
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(KlarColors.barTrack)
                                        .frame(height: 28)

                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(
                                            LinearGradient(
                                                colors: [node.color, node.color.opacity(0.7)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: nodeWidth, height: 28)
                                }
                                .frame(maxWidth: .infinity)

                                // Label + amount
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(node.label.uppercased())
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(node.color)
                                        .lineLimit(1)
                                    Text(CurrencyHelper.formatCompact(node.value))
                                        .font(.system(size: 10, weight: .semibold))
                                        .monospacedDigit()
                                        .foregroundStyle(KlarColors.secondary)
                                }
                                .frame(width: 72, alignment: .trailing)
                            }
                        }

                        // Savings row (if any)
                        if savings > 0 {
                            let proportion = savings / income
                            let nodeWidth = max(barWidth * CGFloat(proportion) * animationProgress, 0)

                            HStack(spacing: 10) {
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(KlarColors.barTrack)
                                        .frame(height: 28)

                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(
                                            LinearGradient(
                                                colors: [KlarColors.positive, KlarColors.positive.opacity(0.6)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: nodeWidth, height: 28)
                                }
                                .frame(maxWidth: .infinity)

                                VStack(alignment: .trailing, spacing: 1) {
                                    Text("SAVED")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(KlarColors.positive)
                                    Text(CurrencyHelper.formatCompact(savings))
                                        .font(.system(size: 10, weight: .semibold))
                                        .monospacedDigit()
                                        .foregroundStyle(KlarColors.secondary)
                                }
                                .frame(width: 72, alignment: .trailing)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.8)) {
                animationProgress = 1.0
            }
        }
    }

    private var incomeBar: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [KlarColors.positive, KlarColors.positive.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 34)
                    .frame(maxWidth: .infinity)

                Text("  INCOME")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.white)
            }

            Text(CurrencyHelper.formatCompact(income))
                .font(.system(size: 12, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(KlarColors.positive)
                .frame(width: 72, alignment: .trailing)
        }
    }
}
