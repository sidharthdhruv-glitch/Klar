import SwiftUI

struct DonutChartSegment: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let color: Color
}

struct DonutChart: View {
    let segments: [DonutChartSegment]
    let lineWidth: CGFloat
    @Binding var selectedSegment: String?
    @State private var animationProgress: CGFloat = 0

    init(segments: [DonutChartSegment], lineWidth: CGFloat = 32, selectedSegment: Binding<String?> = .constant(nil)) {
        self.segments = segments
        self.lineWidth = lineWidth
        self._selectedSegment = selectedSegment
    }

    private var total: Double {
        segments.reduce(0) { $0 + $1.value }
    }

    var body: some View {
        ZStack {
            ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                let startAngle = startAngle(for: index)
                let endAngle = startAngle + .degrees(360 * segment.value / total)
                let isSelected = selectedSegment == segment.label

                Circle()
                    .trim(from: trimStart(for: index) * animationProgress,
                           to: trimEnd(for: index) * animationProgress)
                    .stroke(segment.color, style: StrokeStyle(lineWidth: isSelected ? lineWidth + 6 : lineWidth, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
                    .scaleEffect(isSelected ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3), value: isSelected)
                    .onTapGesture {
                        withAnimation {
                            if selectedSegment == segment.label {
                                selectedSegment = nil
                            } else {
                                selectedSegment = segment.label
                            }
                        }
                    }
            }

            VStack(spacing: 4) {
                Text(CurrencyHelper.format(total))
                    .font(KlarFonts.heading(18))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text("TOTAL")
                    .font(KlarFonts.label(10))
                    .tracking(1)
                    .foregroundStyle(KlarColors.secondary)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2)) {
                animationProgress = 1.0
            }
        }
    }

    private func startAngle(for index: Int) -> Angle {
        let precedingTotal = segments.prefix(index).reduce(0.0) { $0 + $1.value }
        return .degrees(360 * precedingTotal / total)
    }

    private func trimStart(for index: Int) -> CGFloat {
        let precedingTotal = segments.prefix(index).reduce(0.0) { $0 + $1.value }
        return CGFloat(precedingTotal / total)
    }

    private func trimEnd(for index: Int) -> CGFloat {
        let precedingTotal = segments.prefix(index + 1).reduce(0.0) { $0 + $1.value }
        return CGFloat(precedingTotal / total)
    }
}
