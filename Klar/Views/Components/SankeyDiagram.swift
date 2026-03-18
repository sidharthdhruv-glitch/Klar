import SwiftUI

struct SankeyNode: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let color: Color
}

struct SankeyDiagram: View {
    let income: Double
    let categories: [SankeyNode]
    @State private var animationProgress: CGFloat = 0

    var body: some View {
        Canvas { context, size in
            let leftX: CGFloat = 60
            let rightX: CGFloat = size.width - 60
            let totalHeight = size.height - 40
            let topY: CGFloat = 20

            let total = categories.reduce(0.0) { $0 + $1.value }
            guard total > 0 else { return }

            // Left bar (income)
            let leftBarRect = CGRect(x: leftX - 18, y: topY, width: 36, height: totalHeight)
            context.fill(Path(roundedRect: leftBarRect, cornerRadius: 6), with: .color(KlarColors.positive))

            // Left label
            let incomeLabel = Text("INCOME")
                .font(.system(size: 8, weight: .black))
                .foregroundColor(KlarColors.positive)
            context.draw(incomeLabel, at: CGPoint(x: leftX - 18, y: topY + totalHeight + 14))

            let incomeAmount = Text(CurrencyHelper.formatCompact(income))
                .font(.system(size: 7, weight: .semibold))
                .foregroundColor(KlarColors.positive)
            context.draw(incomeAmount, at: CGPoint(x: leftX - 18, y: topY + totalHeight + 24))

            // Right bars + curves
            var currentY: CGFloat = topY
            var leftCurrentY: CGFloat = topY

            for node in categories {
                let proportion = CGFloat(node.value / total)
                let segmentHeight = totalHeight * proportion
                let leftSegmentHeight = totalHeight * proportion

                // Right bar
                let rightBarRect = CGRect(x: rightX - 18, y: currentY, width: 36, height: segmentHeight)
                context.fill(Path(roundedRect: rightBarRect, cornerRadius: 4), with: .color(node.color))

                // Right label
                let labelText = Text(node.label.uppercased())
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(node.color)
                context.draw(labelText, at: CGPoint(x: rightX + 30, y: currentY + segmentHeight / 2 - 6))

                let amountText = Text(CurrencyHelper.formatCompact(node.value))
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundColor(node.color)
                context.draw(amountText, at: CGPoint(x: rightX + 30, y: currentY + segmentHeight / 2 + 6))

                // Bezier curve connection
                var path = Path()
                let startY = leftCurrentY + leftSegmentHeight / 2
                let endY = currentY + segmentHeight / 2

                path.move(to: CGPoint(x: leftX + 18, y: startY - leftSegmentHeight / 2))
                let cp1x = leftX + (rightX - leftX) * 0.4
                let cp2x = leftX + (rightX - leftX) * 0.6

                path.addCurve(
                    to: CGPoint(x: rightX - 18, y: endY - segmentHeight / 2),
                    control1: CGPoint(x: cp1x, y: startY - leftSegmentHeight / 2),
                    control2: CGPoint(x: cp2x, y: endY - segmentHeight / 2)
                )
                path.addLine(to: CGPoint(x: rightX - 18, y: endY + segmentHeight / 2))
                path.addCurve(
                    to: CGPoint(x: leftX + 18, y: startY + leftSegmentHeight / 2),
                    control1: CGPoint(x: cp2x, y: endY + segmentHeight / 2),
                    control2: CGPoint(x: cp1x, y: startY + leftSegmentHeight / 2)
                )
                path.closeSubpath()

                context.fill(path, with: .color(node.color.opacity(0.3 * animationProgress)))

                currentY += segmentHeight
                leftCurrentY += leftSegmentHeight
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5)) {
                animationProgress = 1.0
            }
        }
    }
}
