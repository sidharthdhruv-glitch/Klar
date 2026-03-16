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
            let leftX: CGFloat = 40
            let rightX: CGFloat = size.width - 40
            let totalHeight = size.height - 40
            let topY: CGFloat = 20

            let total = categories.reduce(0.0) { $0 + $1.value }
            guard total > 0 else { return }

            // Left bar (income)
            let leftBarRect = CGRect(x: leftX - 15, y: topY, width: 30, height: totalHeight)
            context.fill(Path(roundedRect: leftBarRect, cornerRadius: 6), with: .color(KlarColors.positive))

            // Right bars + curves
            var currentY: CGFloat = topY
            var leftCurrentY: CGFloat = topY

            for node in categories {
                let proportion = CGFloat(node.value / total)
                let segmentHeight = totalHeight * proportion
                let leftSegmentHeight = totalHeight * proportion

                // Right bar
                let rightBarRect = CGRect(x: rightX - 15, y: currentY, width: 30, height: segmentHeight)
                context.fill(Path(roundedRect: rightBarRect, cornerRadius: 4), with: .color(node.color))

                // Label
                let labelText = Text(node.label.prefix(4).uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(node.color)
                context.draw(labelText, at: CGPoint(x: rightX + 30, y: currentY + segmentHeight / 2))

                // Bezier curve connection
                var path = Path()
                let startY = leftCurrentY + leftSegmentHeight / 2
                let endY = currentY + segmentHeight / 2

                path.move(to: CGPoint(x: leftX + 15, y: startY - leftSegmentHeight / 2))
                let cp1x = leftX + (rightX - leftX) * 0.4
                let cp2x = leftX + (rightX - leftX) * 0.6

                path.addCurve(
                    to: CGPoint(x: rightX - 15, y: endY - segmentHeight / 2),
                    control1: CGPoint(x: cp1x, y: startY - leftSegmentHeight / 2),
                    control2: CGPoint(x: cp2x, y: endY - segmentHeight / 2)
                )
                path.addLine(to: CGPoint(x: rightX - 15, y: endY + segmentHeight / 2))
                path.addCurve(
                    to: CGPoint(x: leftX + 15, y: startY + leftSegmentHeight / 2),
                    control1: CGPoint(x: cp2x, y: endY + segmentHeight / 2),
                    control2: CGPoint(x: cp1x, y: startY + leftSegmentHeight / 2)
                )
                path.closeSubpath()

                context.fill(path, with: .color(node.color.opacity(0.25 * animationProgress)))
                context.stroke(path, with: .color(node.color.opacity(0.4 * animationProgress)), lineWidth: 0.5)

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
