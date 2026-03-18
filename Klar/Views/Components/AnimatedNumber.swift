import SwiftUI

struct AnimatedNumber: View {
    let value: Double
    let format: (Double) -> String
    let font: Font
    let color: Color

    @State private var displayValue: Double = 0

    init(
        value: Double,
        font: Font = KlarFonts.display(),
        color: Color = KlarColors.primary,
        format: @escaping (Double) -> String = { CurrencyHelper.format($0) }
    ) {
        self.value = value
        self.font = font
        self.color = color
        self.format = format
    }

    var body: some View {
        Text(format(displayValue))
            .font(font)
            .monospacedDigit()
            .foregroundStyle(color)
            .contentTransition(.numericText(value: displayValue))
            .onAppear {
                withAnimation(.easeOut(duration: 1.0)) {
                    displayValue = value
                }
            }
    }
}

struct AnimatedPercentage: View {
    let value: Double
    @State private var displayValue: Double = 0

    var body: some View {
        Text(String(format: "%.1f%%", displayValue * 100))
            .font(KlarFonts.label(14))
            .monospacedDigit()
            .foregroundStyle(value >= 0 ? KlarColors.positive : KlarColors.negative)
            .contentTransition(.numericText(value: displayValue))
            .onAppear {
                withAnimation(.easeOut(duration: 1.0)) {
                    displayValue = value
                }
            }
    }
}
