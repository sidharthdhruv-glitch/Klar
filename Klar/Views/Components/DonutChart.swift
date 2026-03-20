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
    @State private var isVisible = false
    @State private var centerVisible = false

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
            // Background track
            Circle()
                .stroke(KlarColors.barTrack, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))

            ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                let isSelected = selectedSegment == segment.label

                Circle()
                    .trim(from: trimStart(for: index),
                          to: isVisible ? trimEnd(for: index) : trimStart(for: index))
                    .stroke(segment.color, style: StrokeStyle(lineWidth: isSelected ? lineWidth + 6 : lineWidth, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
                    .scaleEffect(isSelected ? 1.05 : 1.0)
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.8)
                        .delay(Double(index) * 0.15),
                        value: isVisible
                    )
                    .animation(.spring(response: 0.3), value: isSelected)
                    .onTapGesture {
                        withAnimation {
                            if selectedSegment == segment.label {
                                selectedSegment = nil
                            } else {
                                selectedSegment = segment.label
                            }
                        }
                        HapticManager.light()
                    }
            }

            VStack(spacing: 4) {
                AnimatedNumber(
                    value: total,
                    font: KlarFonts.heading(18),
                    color: KlarColors.primary
                )
                Text("TOTAL")
                    .font(KlarFonts.label(10))
                    .tracking(1)
                    .foregroundStyle(KlarColors.secondary)
            }
            .opacity(centerVisible ? 1 : 0)
            .animation(.easeIn(duration: 0.3).delay(Double(segments.count) * 0.15 + 0.2), value: centerVisible)
        }
        .onAppear {
            isVisible = true
            centerVisible = true
        }
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
