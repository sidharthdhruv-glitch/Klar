import SwiftUI

struct NetFlowCard: View {
    let totalIncome: Double
    let totalExpense: Double
    let balance: Double
    let categorySpend: [(String, Double)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "NET FLOW")

            // Mini flow chart
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
        .background(KlarColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(KlarColors.dashedBorder, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        )
    }
}

struct NetFlowChart: View {
    let income: Double
    let expense: Double

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            Canvas { context, size in
                let points1 = generateWavePath(width: w, height: h, amplitude: h * 0.25, offset: h * 0.35, seed: 1)
                let points2 = generateWavePath(width: w, height: h, amplitude: h * 0.2, offset: h * 0.6, seed: 2)

                // Income line (green)
                var path1 = Path()
                for (i, pt) in points1.enumerated() {
                    if i == 0 { path1.move(to: pt) }
                    else { path1.addLine(to: pt) }
                }
                context.stroke(path1, with: .color(KlarColors.positive), lineWidth: 2.5)

                // Expense line (pink)
                var path2 = Path()
                for (i, pt) in points2.enumerated() {
                    if i == 0 { path2.move(to: pt) }
                    else { path2.addLine(to: pt) }
                }
                context.stroke(path2, with: .color(KlarColors.accent), lineWidth: 2.5)

                // End dots
                if let last1 = points1.last {
                    let dotRect = CGRect(x: last1.x - 4, y: last1.y - 4, width: 8, height: 8)
                    context.fill(Path(ellipseIn: dotRect), with: .color(KlarColors.positive))
                }
                if let last2 = points2.last {
                    let dotRect = CGRect(x: last2.x - 4, y: last2.y - 4, width: 8, height: 8)
                    context.fill(Path(ellipseIn: dotRect), with: .color(KlarColors.accent))
                }
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
