import SwiftUI
import Charts

enum KlarChartStyle {
    static let axisLabelColor = KlarColors.secondary
    static let gridLineColor = KlarColors.barTrack
    static let axisLabelFont = Font.system(size: 10, weight: .regular)
    static let dataLabelFont = Font.system(size: 11, weight: .medium, design: .rounded)

    static let chartBackground = KlarColors.cardBg

    static func formatAmount(_ amount: Double, compact: Bool = false) -> String {
        if compact {
            return CurrencyHelper.formatCompact(amount)
        }
        return CurrencyHelper.format(amount)
    }

    static let chartAppearAnimation = Animation.spring(response: 0.8, dampingFraction: 0.75)
    static let chartInteractionAnimation = Animation.spring(response: 0.3, dampingFraction: 0.85)

    static func categoryGradient(for name: String) -> LinearGradient {
        let base = KlarColors.categoryColor(for: name)
        return LinearGradient(
            colors: [base, base.opacity(0.7)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
