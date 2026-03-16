import Foundation

struct CurrencyHelper {
    static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "en_IN")
        f.currencySymbol = "₹"
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f
    }()

    static func format(_ value: Double) -> String {
        let absValue = abs(value)
        let formatted = formatter.string(from: NSNumber(value: absValue)) ?? "₹0"
        if value < 0 {
            return "-\(formatted)"
        }
        return formatted
    }

    static func formatSigned(_ value: Double) -> String {
        let absValue = abs(value)
        let formatted = formatter.string(from: NSNumber(value: absValue)) ?? "₹0"
        if value >= 0 {
            return "+\(formatted)"
        }
        return "-\(formatted)"
    }

    static func formatCompact(_ value: Double) -> String {
        let absValue = abs(value)
        if absValue >= 100000 {
            let lakhs = absValue / 100000
            return "₹\(String(format: "%.1fL", lakhs))"
        } else if absValue >= 1000 {
            let thousands = absValue / 1000
            return "₹\(String(format: "%.1fK", thousands))"
        }
        return format(value)
    }
}
