import SwiftUI

struct NetFlowCard: View {
    let totalIncome: Double
    let totalExpense: Double
    let balance: Double
    let categorySpend: [(String, Double)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "NET FLOW")

            // Mini flow chart with gradient fills
            NetFlowChart(income: totalIncome, expense: totalExpense)
                .frame(height: 80)

            // Inflow/Outflow pill
            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    Text("INFLOW")
                        .font(KlarFonts.label(11))
                        .foregroundStyle(KlarColors.secondary)
                    Text(CurrencyHelper.format(totalIncome))
                        .font(KlarFonts.label(13))
                        .monospacedDigit()
                        .foregroundStyle(KlarColors.positive)
                }

                Spacer()

                Rectangle()
                    .frame(width: 1, height: 16)
                    .foregroundStyle(KlarColors.barTrack)

                Spacer()

                HStack(spacing: 6) {
                    Text("OUTFLOW")
                        .font(KlarFonts.label(11))
                        .foregroundStyle(KlarColors.secondary)
                    Text(CurrencyHelper.format(totalExpense))
                        .font(KlarFonts.label(13))
                        .monospacedDigit()
                        .foregroundStyle(KlarColors.negative)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(KlarColors.surfaceElevated)
            .clipShape(Capsule())
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

struct NetFlowChart: View {
    let income: Double
    let expense: Double
    @State private var animationProgress: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            Canvas { context, size in
                let points1 = generateWavePath(width: w, height: h, amplitude: h * 0.25, offset: h * 0.35, seed: 1)
                let points2 = generateWavePath(width: w, height: h, amplitude: h * 0.2, offset: h * 0.6, seed: 2)

                let animatedCount = max(1, Int(CGFloat(points1.count) * animationProgress))

                // Income gradient fill
                var fillPath1 = Path()
                let visiblePoints1 = Array(points1.prefix(animatedCount))
                for (i, pt) in visiblePoints1.enumerated() {
                    if i == 0 { fillPath1.move(to: pt) }
                    else { fillPath1.addLine(to: pt) }
                }
                if let last = visiblePoints1.last {
                    fillPath1.addLine(to: CGPoint(x: last.x, y: h))
                }
                fillPath1.addLine(to: CGPoint(x: visiblePoints1.first?.x ?? 0, y: h))
                fillPath1.closeSubpath()
                context.fill(fillPath1, with: .linearGradient(
                    Gradient(colors: [KlarColors.positive.opacity(0.2), KlarColors.positive.opacity(0.0)]),
                    startPoint: CGPoint(x: w / 2, y: 0),
                    endPoint: CGPoint(x: w / 2, y: h)
                ))

                // Income line
                var path1 = Path()
                for (i, pt) in visiblePoints1.enumerated() {
                    if i == 0 { path1.move(to: pt) }
                    else { path1.addLine(to: pt) }
                }
                context.stroke(path1, with: .color(KlarColors.positive), lineWidth: 2.5)

                // Expense gradient fill
                let visiblePoints2 = Array(points2.prefix(animatedCount))
                var fillPath2 = Path()
                for (i, pt) in visiblePoints2.enumerated() {
                    if i == 0 { fillPath2.move(to: pt) }
                    else { fillPath2.addLine(to: pt) }
                }
                if let last = visiblePoints2.last {
                    fillPath2.addLine(to: CGPoint(x: last.x, y: h))
                }
                fillPath2.addLine(to: CGPoint(x: visiblePoints2.first?.x ?? 0, y: h))
                fillPath2.closeSubpath()
                context.fill(fillPath2, with: .linearGradient(
                    Gradient(colors: [KlarColors.accent.opacity(0.15), KlarColors.accent.opacity(0.0)]),
                    startPoint: CGPoint(x: w / 2, y: 0),
                    endPoint: CGPoint(x: w / 2, y: h)
                ))

                // Expense line
                var path2 = Path()
                for (i, pt) in visiblePoints2.enumerated() {
                    if i == 0 { path2.move(to: pt) }
                    else { path2.addLine(to: pt) }
                }
                context.stroke(path2, with: .color(KlarColors.accent), lineWidth: 2.5)

                // End dots
                if let last1 = visiblePoints1.last {
                    let dotRect = CGRect(x: last1.x - 4, y: last1.y - 4, width: 8, height: 8)
                    context.fill(Path(ellipseIn: dotRect), with: .color(KlarColors.positive))
                }
                if let last2 = visiblePoints2.last {
                    let dotRect = CGRect(x: last2.x - 4, y: last2.y - 4, width: 8, height: 8)
                    context.fill(Path(ellipseIn: dotRect), with: .color(KlarColors.accent))
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                animationProgress = 1.0
            }
        }
    }

    private func generateWavePath(width: CGFloat, height: CGFloat, amplitude: CGFloat, offset: CGFloat, seed: Int) -> [CGPoint] {
        let steps = 60
        return (0...steps).map { i in
            let x = width * CGFloat(i) / CGFloat(steps)
            let progress = CGFloat(i) / CGFloat(steps)
            let wave = sin(progress * .pi * 2.5 + CGFloat(seed) * 1.5) * amplitude
            let trend = (seed == 1) ? -progress * amplitude * 0.5 : progress * amplitude * 0.3
            return CGPoint(x: x, y: offset + wave + trend)
        }
    }
}
