import SwiftUI

struct CategoryBreakdownView: View {
    let categorySpend: [(String, Double)]
    @State private var selectedCategory: String?

    private var segments: [DonutChartSegment] {
        categorySpend.map { name, value in
            DonutChartSegment(label: name, value: value, color: KlarColors.categoryColor(for: name))
        }
    }

    var body: some View {
        KlarCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "BREAK DOWN")

                DonutChart(segments: segments, selectedSegment: $selectedCategory)
                    .frame(height: 200)
                    .padding(.horizontal, 20)

                VStack(spacing: 8) {
                    ForEach(categorySpend, id: \.0) { name, value in
                        let isSelected = selectedCategory == name
                        HStack(spacing: 10) {
                            Circle()
                                .fill(KlarColors.categoryColor(for: name))
                                .frame(width: 8, height: 8)

                            Text(name.uppercased())
                                .font(KlarFonts.label(12))
                                .tracking(0.5)
                                .foregroundStyle(isSelected ? .white : KlarColors.secondary)

                            Spacer()

                            Text(CurrencyHelper.format(value))
                                .font(KlarFonts.label(13))
                                .monospacedDigit()
                                .foregroundStyle(isSelected ? .white : KlarColors.secondary)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(isSelected ? KlarColors.surfaceElevated : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .onTapGesture {
                            withAnimation {
                                selectedCategory = selectedCategory == name ? nil : name
                            }
                        }
                    }
                }
            }
        }
    }
}
