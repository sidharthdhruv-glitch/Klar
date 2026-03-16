import SwiftUI

struct BurnRateView: View {
    let rate: Double
    let spent: Double
    let budget: Double
    @State private var barProgress: CGFloat = 0

    private var barColor: Color {
        if rate < 0.5 { return KlarColors.positive }
        if rate < 0.75 { return .orange }
        return KlarColors.negative
    }

    var body: some View {
        KlarCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeader(title: "BURN RATE")
                    Spacer()
                    Text(String(format: "%.1f%%", rate * 100))
                        .font(KlarFonts.heading(18))
                        .monospacedDigit()
                        .foregroundStyle(barColor)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(KlarColors.barTrack)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(barColor)
                            .frame(width: geo.size.width * min(barProgress, 1.0), height: 8)
                    }
                }
                .frame(height: 8)

                Text("\(CurrencyHelper.format(spent)) / \(CurrencyHelper.format(budget))")
                    .font(KlarFonts.label(12))
                    .monospacedDigit()
                    .foregroundStyle(KlarColors.secondary)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                barProgress = CGFloat(rate)
            }
        }
    }
}
