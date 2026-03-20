import SwiftUI

struct BurnRateView: View {
    let rate: Double
    let spent: Double
    let budget: Double
    @State private var barProgress: CGFloat = 0
    @State private var isPulsing = false
    @State private var isShaking = false

    private var barColor: Color {
        if rate < 0.5 { return KlarColors.positive }
        if rate < 0.75 { return KlarColors.searchHighlight }
        return KlarColors.negative
    }

    private var statusText: String {
        if rate < 0.5 { return "On track" }
        if rate < 0.75 { return "Watch spending" }
        if rate < 1.0 { return "Near limit" }
        return "Over budget"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "BURN RATE")
                Spacer()
                Text(statusText.uppercased())
                    .font(KlarFonts.label(10))
                    .tracking(0.5)
                    .foregroundStyle(barColor)
                    .opacity(rate > 0.8 ? (isPulsing ? 0.4 : 1.0) : 1.0)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(KlarColors.barTrack)
                        .frame(height: 28)

                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(barColor)
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
            .offset(x: isShaking ? -4 : 0)

            if rate >= 1.0 {
                Text("You've exceeded your monthly budget by \(CurrencyHelper.format(spent - budget))")
                    .font(KlarFonts.label(11))
                    .foregroundStyle(KlarColors.negative)
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
        .task(id: rate) {
            barProgress = 0
            isPulsing = false
            isShaking = false
            try? await Task.sleep(nanoseconds: 100_000_000)
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                barProgress = CGFloat(rate)
            }
            // Threshold animations after bar fills
            try? await Task.sleep(nanoseconds: 900_000_000)
            if rate > 0.8 && rate <= 1.0 {
                // Pulsing for >80%
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
                HapticManager.warning()
            } else if rate > 1.0 {
                // Shake for >100%
                withAnimation(.spring(response: 0.1, dampingFraction: 0.2)) {
                    isShaking = true
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
                withAnimation(.spring(response: 0.1, dampingFraction: 0.2)) {
                    isShaking = false
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
                withAnimation(.spring(response: 0.1, dampingFraction: 0.2)) {
                    isShaking = true
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
                withAnimation(.spring(response: 0.1, dampingFraction: 0.9)) {
                    isShaking = false
                }
                // Then pulse
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
                HapticManager.error()
            }
        }
    }
}
