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
        VStack(spacing: 16) {
            // Section header
            Text("BREAKDOWN")
                .font(KlarFonts.label(11))
                .tracking(2)
                .foregroundStyle(KlarColors.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Donut chart
            DonutChart(segments: segments, lineWidth: 32, selectedSegment: $selectedCategory)
                .frame(width: 180, height: 180)
                .padding(.vertical, 8)

            // Category legend
            VStack(spacing: 10) {
                ForEach(categorySpend, id: \.0) { name, value in
                    let percentage = total > 0 ? (value / total * 100) : 0
                    HStack(spacing: 10) {
                        Circle()
                            .fill(KlarColors.categoryColor(for: name))
                            .frame(width: 10, height: 10)
                        Text(name.uppercased())
                            .font(KlarFonts.label(11))
                            .foregroundStyle(KlarColors.primary)
                        Spacer()
                        Text(String(format: "%.0f%%", percentage))
                            .font(KlarFonts.label(10))
                            .foregroundStyle(KlarColors.secondary)
                        Text(CurrencyHelper.format(value))
                            .font(KlarFonts.label(11))
                            .monospacedDigit()
                            .foregroundStyle(KlarColors.primary)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedCategory == name ? KlarColors.categoryColor(for: name).opacity(0.1) : Color.clear)
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            selectedCategory = selectedCategory == name ? nil : name
                        }
                        HapticManager.light()
                    }
                }
            }
        }
        .padding(16)
        .background(KlarColors.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(KlarColors.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}
