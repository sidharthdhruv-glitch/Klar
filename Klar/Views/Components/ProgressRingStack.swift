import SwiftUI

struct ProgressRingStack: View {
    let categories: [CategorySpend]
    let totalBudget: Double
    let totalSpent: Double

    @State private var ringProgress: [UUID: CGFloat] = [:]
    @State private var tappedCategory: String?

    private var topCategories: [CategorySpend] {
        Array(categories.sorted { $0.amount > $1.amount }.prefix(4))
    }

    private var overallPercent: Int {
        guard totalBudget > 0 else { return 0 }
        return Int(totalSpent / totalBudget * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("BUDGET")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.5)
                .foregroundColor(KlarColors.primary)

            HStack(spacing: 24) {
                // Rings
                ZStack {
                    ForEach(Array(topCategories.enumerated()), id: \.element.id) { index, item in
                        let radius: CGFloat = CGFloat(85 - index * 22)
                        let progress = item.budget > 0 ? item.amount / item.budget : 0
                        let isTapped = tappedCategory == item.category

                        Circle()
                            .stroke(KlarColors.barTrack, lineWidth: 14)
                            .frame(width: radius * 2, height: radius * 2)

                        Circle()
                            .trim(from: 0, to: ringProgress[item.id] ?? 0)
                            .stroke(
                                progress > 1.0
                                    ? KlarColors.negative
                                    : KlarColors.categoryColor(for: item.category),
                                style: StrokeStyle(lineWidth: 14, lineCap: .round)
                            )
                            .frame(width: radius * 2, height: radius * 2)
                            .rotationEffect(.degrees(-90))
                            .scaleEffect(isTapped ? 1.08 : 1.0)
                            .animation(KlarChartStyle.chartInteractionAnimation, value: isTapped)
                            .onTapGesture {
                                withAnimation(KlarChartStyle.chartInteractionAnimation) {
                                    tappedCategory = tappedCategory == item.category ? nil : item.category
                                }
                                HapticManager.light()
                            }
                    }

                    VStack(spacing: 2) {
                        Text("\(overallPercent)%")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundColor(KlarColors.primary)
                            .contentTransition(.numericText())
                        Text("of budget")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(KlarColors.secondary)
                    }
                }
                .frame(width: 190, height: 190)

                // Legend
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(topCategories) { item in
                        let progress = item.budget > 0 ? item.amount / item.budget : 0
                        let isTapped = tappedCategory == item.category

                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(KlarColors.categoryColor(for: item.category))
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.category.uppercased())
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(KlarColors.primary)
                                    Text("\(Int(progress * 100))% of budget")
                                        .font(.system(size: 10))
                                        .foregroundColor(
                                            progress > 0.9 ? KlarColors.negative : KlarColors.secondary
                                        )
                                }
                            }

                            if isTapped {
                                Text("\(KlarChartStyle.formatAmount(item.amount)) / \(KlarChartStyle.formatAmount(item.budget))")
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(KlarColors.secondary)
                                    .padding(.leading, 16)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .onTapGesture {
                            withAnimation(KlarChartStyle.chartInteractionAnimation) {
                                tappedCategory = tappedCategory == item.category ? nil : item.category
                            }
                            HapticManager.light()
                        }
                    }
                }
            }
        }
        .onAppear {
            for (index, item) in topCategories.enumerated() {
                let progress = item.budget > 0 ? min(item.amount / item.budget, 1.2) : 0
                withAnimation(
                    .spring(response: 0.8, dampingFraction: 0.7)
                    .delay(Double(index) * 0.12)
                ) {
                    ringProgress[item.id] = CGFloat(progress)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                HapticManager.light()
            }
        }
    }
}
