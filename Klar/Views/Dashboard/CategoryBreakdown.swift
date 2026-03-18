import SwiftUI

struct CategoryBreakdownView: View {
    let categorySpend: [(String, Double)]
    @State private var selectedCategory: String?

    private var segments: [DonutChartSegment] {
        categorySpend.map { name, value in
            DonutChartSegment(label: name, value: value, color: KlarColors.categoryColor(for: name))
        }
    }

    private var total: Double {
        categorySpend.reduce(0) { $0 + $1.1 }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Circular breakdown with labels around it
            ZStack {
                DonutChart(segments: segments, lineWidth: 36, selectedSegment: $selectedCategory)
                    .frame(width: 200, height: 200)

                VStack(spacing: 2) {
                    Text("BREAK")
                        .font(KlarFonts.display(28))
                        .foregroundStyle(KlarColors.primary)
                    Text("DOWN")
                        .font(KlarFonts.display(28))
                        .foregroundStyle(KlarColors.primary)
                }
            }
            .frame(height: 280)
            .overlay(
                categoryLabelsOverlay
            )

            // Category legend
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(categorySpend, id: \.0) { name, value in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(KlarColors.categoryColor(for: name))
                            .frame(width: 8, height: 8)
                        Text(name.uppercased())
                            .font(KlarFonts.label(11))
                            .foregroundStyle(KlarColors.secondary)
                        Spacer()
                        Text(CurrencyHelper.format(value))
                            .font(KlarFonts.label(11))
                            .monospacedDigit()
                            .foregroundStyle(KlarColors.primary)
                    }
                }
            }
        }
        .padding(16)
        .background(KlarColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    private var categoryLabelsOverlay: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius: CGFloat = 145

            ForEach(Array(categorySpend.prefix(8).enumerated()), id: \.element.0) { index, item in
                let angle = angleFor(index: index, total: categorySpend.prefix(8).count)
                let x = center.x + radius * cos(angle)
                let y = center.y + radius * sin(angle)
                let color = KlarColors.categoryColor(for: item.0)

                VStack(spacing: 2) {
                    Text(item.0.uppercased())
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(color)
                    Text(CurrencyHelper.formatCompact(item.1))
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(color)
                }
                .position(x: x, y: y)
            }
        }
    }

    private func angleFor(index: Int, total: Int) -> CGFloat {
        let startAngle: CGFloat = -.pi / 2
        let step = (2 * .pi) / CGFloat(total)
        return startAngle + step * CGFloat(index) + step / 2
    }
}
