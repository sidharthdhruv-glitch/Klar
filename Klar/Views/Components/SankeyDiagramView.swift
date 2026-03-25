import SwiftUI

struct SankeyFlow: Identifiable {
    let id = UUID()
    let category: String?
    let label: String
    let amount: Double
    let color: Color
}

struct SankeyDiagramView: View {
    let income: Double
    let flows: [SankeyFlow]
    let monthLabel: String

    @State private var animationProgress: CGFloat = 0
    @State private var selectedFlow: SankeyFlow?

    private let nodeWidth: CGFloat = 12
    private let nodeCornerRadius: CGFloat = 4
    private let labelColumnWidth: CGFloat = 80

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("INCOME FLOW")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(1.5)
                        .foregroundColor(KlarColors.primary)
                    Text(monthLabel)
                        .font(.system(size: 12))
                        .foregroundColor(KlarColors.secondary)
                }
                Spacer()
                Text(KlarChartStyle.formatAmount(income))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(KlarColors.positive)
            }

            HStack(spacing: 0) {
                // Left label
                VStack {
                    Text("Income")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(KlarColors.positive)
                }
                .frame(width: 44, alignment: .trailing)
                .opacity(animationProgress)

                // Sankey diagram area
                GeometryReader { geo in
                    let totalHeight = geo.size.height
                    let totalWidth = geo.size.width
                    let leftX: CGFloat = 0
                    let rightX: CGFloat = totalWidth - nodeWidth
                    let sortedFlows = flows.sorted { $0.amount > $1.amount }
                    let gapSize: CGFloat = 4
                    let totalGaps = gapSize * max(CGFloat(sortedFlows.count - 1), 0)
                    let usableHeight = totalHeight - totalGaps

                    ZStack {
                        // Left node (Income)
                        RoundedRectangle(cornerRadius: nodeCornerRadius)
                            .fill(KlarColors.positive)
                            .frame(width: nodeWidth, height: totalHeight * animationProgress)
                            .position(x: leftX + nodeWidth / 2, y: totalHeight / 2)

                        ForEach(Array(sortedFlows.enumerated()), id: \.element.id) { index, flow in
                            let flowHeight = usableHeight * CGFloat(flow.amount / max(income, 1))
                            let yOffset = calculateYOffset(for: index, in: sortedFlows, usableHeight: usableHeight, gapSize: gapSize)
                            let leftFlowY = calculateLeftYOffset(for: index, in: sortedFlows, totalHeight: totalHeight)
                            let leftFlowHeight = totalHeight * CGFloat(flow.amount / max(income, 1))

                            // Flow path
                            SankeyFlowPath(
                                startX: leftX + nodeWidth,
                                startY: leftFlowY,
                                startHeight: leftFlowHeight,
                                endX: rightX,
                                endY: yOffset,
                                endHeight: flowHeight,
                                color: flow.color,
                                progress: animationProgress,
                                isSelected: selectedFlow?.id == flow.id,
                                isOtherSelected: selectedFlow != nil && selectedFlow?.id != flow.id
                            )
                            .onTapGesture {
                                withAnimation(KlarChartStyle.chartInteractionAnimation) {
                                    selectedFlow = selectedFlow?.id == flow.id ? nil : flow
                                }
                                HapticManager.light()
                            }

                            // Right node
                            RoundedRectangle(cornerRadius: nodeCornerRadius)
                                .fill(flow.color)
                                .frame(width: nodeWidth, height: flowHeight * animationProgress)
                                .position(x: rightX + nodeWidth / 2, y: yOffset + flowHeight / 2)
                        }
                    }
                }

                // Right labels column
                VStack(alignment: .leading, spacing: 0) {
                    let sortedFlows = flows.sorted { $0.amount > $1.amount }
                    let gapSize: CGFloat = 4

                    ForEach(Array(sortedFlows.enumerated()), id: \.element.id) { index, flow in
                        if index > 0 {
                            Spacer()
                                .frame(height: gapSize)
                        }

                        let pct = income > 0 ? Int(flow.amount / income * 100) : 0

                        VStack(alignment: .leading, spacing: 1) {
                            Text(flow.label.uppercased())
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(KlarColors.primary)
                                .lineLimit(1)
                            HStack(spacing: 2) {
                                Text(KlarChartStyle.formatAmount(flow.amount, compact: true))
                                    .font(.system(size: 9, weight: .regular, design: .rounded))
                                    .foregroundColor(KlarColors.secondary)
                                if selectedFlow?.id == flow.id {
                                    Text("(\(pct)%)")
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundColor(flow.color)
                                }
                            }
                        }
                        .frame(maxHeight: .infinity)
                        .opacity(animationProgress)
                    }
                }
                .frame(width: labelColumnWidth)
                .padding(.leading, 6)
            }
            .frame(height: max(CGFloat(flows.count) * 36, 200))
        }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.75)) {
                animationProgress = 1.0
            }
        }
        .onChange(of: monthLabel) { _, _ in
            animationProgress = 0
            withAnimation(.spring(response: 1.0, dampingFraction: 0.75)) {
                animationProgress = 1.0
            }
        }
    }

    private func calculateYOffset(for index: Int, in flows: [SankeyFlow], usableHeight: CGFloat, gapSize: CGFloat) -> CGFloat {
        var offset: CGFloat = 0
        for i in 0..<index {
            offset += usableHeight * CGFloat(flows[i].amount / max(income, 1)) + gapSize
        }
        return offset
    }

    private func calculateLeftYOffset(for index: Int, in flows: [SankeyFlow], totalHeight: CGFloat) -> CGFloat {
        var offset: CGFloat = 0
        for i in 0..<index {
            offset += totalHeight * CGFloat(flows[i].amount / max(income, 1))
        }
        return offset
    }
}

struct SankeyFlowPath: View {
    let startX, startY, startHeight, endX, endY, endHeight: CGFloat
    let color: Color
    let progress: CGFloat
    let isSelected: Bool
    let isOtherSelected: Bool

    var body: some View {
        ZStack {
            Path { path in
                let controlOffset = (endX - startX) * 0.45

                path.move(to: CGPoint(x: startX, y: startY))
                path.addCurve(
                    to: CGPoint(x: endX, y: endY),
                    control1: CGPoint(x: startX + controlOffset, y: startY),
                    control2: CGPoint(x: endX - controlOffset, y: endY)
                )

                path.addLine(to: CGPoint(x: endX, y: endY + endHeight))
                path.addCurve(
                    to: CGPoint(x: startX, y: startY + startHeight),
                    control1: CGPoint(x: endX - controlOffset, y: endY + endHeight),
                    control2: CGPoint(x: startX + controlOffset, y: startY + startHeight)
                )

                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [color.opacity(isSelected ? 0.5 : 0.35), color.opacity(isSelected ? 0.3 : 0.15)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .opacity(isOtherSelected ? 0.15 : 1.0)
            .scaleEffect(x: progress, anchor: .leading)

            if isSelected {
                Path { path in
                    let controlOffset = (endX - startX) * 0.45
                    path.move(to: CGPoint(x: startX, y: startY))
                    path.addCurve(
                        to: CGPoint(x: endX, y: endY),
                        control1: CGPoint(x: startX + controlOffset, y: startY),
                        control2: CGPoint(x: endX - controlOffset, y: endY)
                    )
                }
                .stroke(color, lineWidth: 1.5)
                .scaleEffect(x: progress, anchor: .leading)
            }
        }
    }
}
