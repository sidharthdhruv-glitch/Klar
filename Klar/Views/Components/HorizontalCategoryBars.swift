import SwiftUI

struct HorizontalCategoryBars: View {
    let categories: [CategorySpend]
    let totalSpent: Double
    @State private var animationProgress: CGFloat = 0
    @State private var expandedCategory: String?
    @State private var longPressedCategory: String?

    var sortedCategories: [CategorySpend] {
        categories.sorted { $0.amount > $1.amount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("BREAKDOWN")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(1.5)
                    .foregroundColor(KlarColors.primary)
                Spacer()
                Text(KlarChartStyle.formatAmount(totalSpent))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(KlarColors.secondary)
            }
            .padding(.bottom, 20)

            VStack(spacing: 16) {
                ForEach(Array(sortedCategories.enumerated()), id: \.element.id) { index, item in
                    CategoryBarRow(
                        item: item,
                        maxAmount: sortedCategories.first?.amount ?? item.amount,
                        totalSpent: totalSpent,
                        animationProgress: animationProgress,
                        delay: Double(index) * 0.08,
                        isExpanded: expandedCategory == item.category
                    )
                    .onTapGesture {
                        withAnimation(KlarChartStyle.chartInteractionAnimation) {
                            expandedCategory = expandedCategory == item.category ? nil : item.category
                        }
                        HapticManager.light()
                    }
                    .onLongPressGesture {
                        withAnimation(KlarChartStyle.chartInteractionAnimation) {
                            longPressedCategory = longPressedCategory == item.category ? nil : item.category
                        }
                        HapticManager.medium()
                    }

                    if longPressedCategory == item.category {
                        budgetTooltip(for: item)
                            .transition(.scale(scale: 0.9, anchor: .top).combined(with: .opacity))
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) {
                animationProgress = 1.0
            }
        }
    }

    private func budgetTooltip(for item: CategorySpend) -> some View {
        let budgetPct = item.budget > 0 ? Int(item.amount / item.budget * 100) : 0
        return HStack(spacing: 6) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(KlarColors.secondary)
            if item.budget > 0 {
                Text("\(KlarChartStyle.formatAmount(item.amount)) of \(KlarChartStyle.formatAmount(item.budget)) budget (\(budgetPct)%)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(KlarColors.primary)
            } else {
                Text("\(KlarChartStyle.formatAmount(item.amount)) spent")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(KlarColors.primary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(KlarColors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct CategoryBarRow: View {
    let item: CategorySpend
    let maxAmount: Double
    let totalSpent: Double
    let animationProgress: CGFloat
    let delay: Double
    let isExpanded: Bool

    @State private var rowProgress: CGFloat = 0

    private var percentage: Int {
        guard totalSpent > 0 else { return 0 }
        return Int((item.amount / totalSpent) * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(KlarColors.categoryColor(for: item.category))
                        .frame(width: 8, height: 8)
                    Text(item.category.uppercased())
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(KlarColors.primary)
                }
                Spacer()
                HStack(spacing: 8) {
                    Text("\(percentage)%")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(KlarColors.secondary)
                    Text(KlarChartStyle.formatAmount(item.amount))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(KlarColors.primary)
                        .contentTransition(.numericText(value: item.amount))
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(KlarColors.barTrack)
                        .frame(height: 14)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(KlarChartStyle.categoryGradient(for: item.category))
                        .frame(
                            width: max(4, geo.size.width * CGFloat(item.amount / maxAmount) * rowProgress),
                            height: 14
                        )

                    if item.budget > 0 {
                        let budgetPosition = geo.size.width * CGFloat(item.budget / maxAmount)
                        Rectangle()
                            .fill(KlarColors.primary.opacity(0.2))
                            .frame(width: 1.5, height: 20)
                            .offset(x: min(budgetPosition, geo.size.width) - 0.75)
                    }
                }
            }
            .frame(height: 14)

            if isExpanded {
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Category total")
                            .font(.system(size: 11))
                            .foregroundStyle(KlarColors.secondary)
                        Spacer()
                        Text(KlarChartStyle.formatAmount(item.amount))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(KlarColors.primary)
                    }
                    if item.previousAmount > 0 {
                        let delta = item.amount - item.previousAmount
                        let deltaPct = item.previousAmount > 0 ? (delta / item.previousAmount) * 100 : 0
                        HStack(spacing: 6) {
                            Text("vs last month")
                                .font(.system(size: 11))
                                .foregroundStyle(KlarColors.secondary)
                            Spacer()
                            Text(String(format: "%+.0f%% (%@)", deltaPct, KlarChartStyle.formatAmount(abs(delta), compact: true)))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(delta > 0 ? KlarColors.negative : KlarColors.positive)
                        }
                    }
                }
                .padding(.top, 4)
                .padding(.horizontal, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onAppear {
            withAnimation(
                .spring(response: 0.7, dampingFraction: 0.8)
                .delay(delay)
            ) {
                rowProgress = 1.0
            }
        }
    }
}
