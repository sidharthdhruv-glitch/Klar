import SwiftUI

struct AnimatedNumber: View {
    let value: Double
    let format: (Double) -> String
    let font: Font
    let color: Color

    @State private var displayValue: Double = 0
    @State private var hasAppeared = false

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
                guard !hasAppeared else { return }
                hasAppeared = true
                withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) {
                    displayValue = value
                }
            }
            .onChange(of: value) { _, newValue in
                withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                    displayValue = newValue
                }
            }
    }
}

struct AnimatedPercentage: View {
    let value: Double
    @State private var displayValue: Double = 0
    @State private var hasAppeared = false

    var body: some View {
        Text(String(format: "%.1f%%", displayValue * 100))
            .font(KlarFonts.label(14))
            .monospacedDigit()
            .foregroundStyle(value >= 0 ? KlarColors.positive : KlarColors.negative)
            .contentTransition(.numericText(value: displayValue))
            .onAppear {
                guard !hasAppeared else { return }
                hasAppeared = true
                withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) {
                    displayValue = value
                }
            }
            .onChange(of: value) { _, newValue in
                withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                    displayValue = newValue
                }
            }
    }
}
