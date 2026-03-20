import SwiftUI
import CoreGraphics

struct SpendingGaugeSegment: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let color: Color
}

struct SpendingGauge: View {
    let spent: Double
    let budget: Double
    let segments: [SpendingGaugeSegment]
    @State private var animationProgress: CGFloat = 0
    @State private var ticksRevealed: Int = 0

    private var total: Double {
        segments.reduce(0) { $0 + $1.value }
    }

    private var spentFraction: Double {
        guard budget > 0 else { return 0 }
        return min(spent / budget, 1.0)
    }

    private let barCount = 40
    private let startAngle: Double = -210
    private let endAngle: Double = 30
    private var arcSpan: Double { endAngle - startAngle }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                GeometryReader { geo in
                    let center = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.55)
                    let radius = min(geo.size.width, geo.size.height) * 0.38

                    // Tick bars
                    ForEach(0..<barCount, id: \.self) { i in
                        let fraction = Double(i) / Double(barCount - 1)
                        let angle = Angle.degrees(startAngle + arcSpan * fraction)
                        let barLength: CGFloat = 28
                        let innerRadius = radius - barLength / 2
                        let outerRadius = radius + barLength / 2
                        let innerPoint = pointOnCircle(center: center, radius: innerRadius, angle: angle)
                        let outerPoint = pointOnCircle(center: center, radius: outerRadius, angle: angle)
                        let isActive = fraction <= spentFraction * animationProgress
                        let isRevealed = i < ticksRevealed
                        let barColor = isActive ? colorForFraction(fraction) : KlarColors.barTrack

                        Path { path in
                            path.move(to: innerPoint)
                            path.addLine(to: outerPoint)
                        }
                        .stroke(barColor, style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                        .opacity(isRevealed ? 1 : 0)
                    }

                    // Center text
                    VStack(spacing: 2) {
                        Text("Spent")
                            .font(KlarFonts.label(12))
                            .foregroundStyle(KlarColors.secondary)
                        AnimatedNumber(
                            value: spent,
                            font: KlarFonts.dataValue(24),
                            color: KlarColors.primary
                        )
                    }
                    .position(x: center.x, y: center.y + 8)

                    // Left label
                    let pct = budget > 0 ? Int(spentFraction * 100) : 0
                    Text("\(pct)% spent")
                        .font(KlarFonts.label(11))
                        .foregroundStyle(KlarColors.secondary)
                        .position(x: geo.size.width * 0.12, y: geo.size.height * 0.82)

                    // Right label
                    Text(CurrencyHelper.formatCompact(budget) + " limit")
                        .font(KlarFonts.label(11))
                        .foregroundStyle(KlarColors.secondary)
                        .position(x: geo.size.width * 0.88, y: geo.size.height * 0.82)
                }
            }
            .frame(height: 200)

            // Category pills
            categoryPills
        }
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        // Phase 1: Reveal ticks one by one
        for i in 0..<barCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.015) {
                ticksRevealed = i + 1
            }
        }
        // Phase 2: Sweep colored arc
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animationProgress = 1.0
            }
        }
        // Haptic at completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if spentFraction > 0.8 {
                HapticManager.warning()
            } else {
                HapticManager.light()
            }
        }
    }

    private var categoryPills: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(segments) { seg in
                HStack(spacing: 6) {
                    Circle()
                        .fill(seg.color)
                        .frame(width: 7, height: 7)
                    Text(seg.label)
                        .font(KlarFonts.label(11))
                        .foregroundStyle(KlarColors.primary)
                    Spacer()
                    Text(CurrencyHelper.formatCompact(seg.value))
                        .font(KlarFonts.label(11))
                        .monospacedDigit()
                        .foregroundStyle(KlarColors.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(KlarColors.surfaceElevated)
                .clipShape(Capsule())
            }
        }
    }

    private func colorForFraction(_ fraction: Double) -> Color {
        guard !segments.isEmpty, total > 0 else { return KlarColors.positive }
        var cumulative: Double = 0
        for seg in segments {
            cumulative += seg.value / total
            let segFractionOfSpent = cumulative * spentFraction
            if fraction <= segFractionOfSpent {
                return seg.color
            }
        }
        return segments.last?.color ?? KlarColors.positive
    }

    private func pointOnCircle(center: CGPoint, radius: CGFloat, angle: Angle) -> CGPoint {
        CGPoint(
            x: center.x + radius * CoreGraphics.cos(angle.radians),
            y: center.y + radius * CoreGraphics.sin(angle.radians)
        )
    }
}
