import SwiftUI

struct BurnRateView: View {
    let rate: Double
    let spent: Double
    let budget: Double
    @State private var barProgress: CGFloat = 0

    private var barColor: Color {
        if rate < 0.5 { return KlarColors.positive }
        if rate < 0.75 { return KlarColors.searchHighlight }
        return KlarColors.negative
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "BURN RATE")

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(KlarColors.barTrack)
                        .frame(height: 28)

                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [KlarColors.positive, KlarColors.searchHighlight],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * min(barProgress, 1.0), height: 28)
                    }

                    Text("\(CurrencyHelper.format(spent)) / \(CurrencyHelper.format(budget))")
                        .font(KlarFonts.label(12))
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(KlarColors.primary)
                        .padding(.leading, 12)
                }
            }
            .frame(height: 28)
        }
        .padding(16)
        .background(KlarColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                barProgress = CGFloat(rate)
            }
        }
    }
}
