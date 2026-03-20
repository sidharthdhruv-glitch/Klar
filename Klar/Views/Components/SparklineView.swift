import SwiftUI

struct SparklineView: View {
    let data: [Double]
    let trendColor: Color?
    let height: CGFloat
    let lineWidth: CGFloat
    let showGradientFill: Bool
    let showEndDot: Bool

    init(
        data: [Double],
        trendColor: Color? = nil,
        height: CGFloat = 28,
        lineWidth: CGFloat = 1.5,
        showGradientFill: Bool = true,
        showEndDot: Bool = true
    ) {
        self.data = data
        self.trendColor = trendColor
        self.height = height
        self.lineWidth = lineWidth
        self.showGradientFill = showGradientFill
        self.showEndDot = showEndDot
    }

    private var resolvedColor: Color {
        if let trendColor { return trendColor }
        guard let first = data.first, let last = data.last else { return KlarColors.secondary }
        return last >= first ? Color(hex: "#2D6A4F") : Color(hex: "#C9505B")
    }

    private var normalizedData: [CGFloat] {
        guard let minVal = data.min(), let maxVal = data.max(), maxVal > minVal else {
            return data.map { _ in 0.5 }
        }
        return data.map { CGFloat(($0 - minVal) / (maxVal - minVal)) }
    }

    var body: some View {
        GeometryReader { geo in
            let points = pointsForSize(geo.size)

            ZStack {
                if showGradientFill && points.count > 1 {
                    Path { path in
                        path.move(to: CGPoint(x: points.first!.x, y: geo.size.height))
                        for point in points {
                            path.addLine(to: point)
                        }
                        path.addLine(to: CGPoint(x: points.last!.x, y: geo.size.height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [resolvedColor.opacity(0.2), resolvedColor.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }

                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(resolvedColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

                if showEndDot, let last = points.last {
                    Circle()
                        .fill(resolvedColor)
                        .frame(width: lineWidth * 2.5, height: lineWidth * 2.5)
                        .position(last)
                }
            }
        }
        .frame(height: height)
    }

    private func pointsForSize(_ size: CGSize) -> [CGPoint] {
        guard normalizedData.count > 1 else { return [] }
        let stepX = size.width / CGFloat(normalizedData.count - 1)
        let padding: CGFloat = 2
        let usableHeight = size.height - padding * 2

        return normalizedData.enumerated().map { index, value in
            CGPoint(
                x: CGFloat(index) * stepX,
                y: padding + usableHeight * (1 - value)
            )
        }
    }
}
