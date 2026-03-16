import SwiftUI

enum KlarColors {
    static let background = Color(hex: "#0D0D0D")
    static let surface = Color(hex: "#1A1A1A")
    static let surfaceElevated = Color(hex: "#222222")
    static let primary = Color.white
    static let secondary = Color(hex: "#888888")
    static let positive = Color(hex: "#4ADE80")
    static let negative = Color(hex: "#F87171")
    static let tabBarBg = Color(hex: "#111111")
    static let tabBarBorder = Color(hex: "#2A2A2A")
    static let inactive = Color(hex: "#444444")
    static let barTrack = Color(hex: "#2A2A2A")

    static let shopping = Color(hex: "#A78BFA")
    static let entertainment = Color(hex: "#FB923C")
    static let health = Color(hex: "#34D399")
    static let finance = Color(hex: "#60A5FA")
    static let transport = Color(hex: "#FBBF24")
    static let utilities = Color(hex: "#F472B6")
    static let misc = Color(hex: "#94A3B8")
    static let food = Color(hex: "#F97316")
    static let income = Color(hex: "#4ADE80")

    static func categoryColor(for name: String) -> Color {
        switch name.lowercased() {
        case "shopping": return shopping
        case "entertainment": return entertainment
        case "health": return health
        case "finance": return finance
        case "transport": return transport
        case "utilities": return utilities
        case "misc": return misc
        case "food": return food
        case "income": return income
        default: return misc
        }
    }

    static func colorFromHex(_ hex: String) -> Color {
        Color(hex: hex)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

enum KlarFonts {
    static func display(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }

    static func heading(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    static func body(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    static func label(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }

    static func sectionHeader() -> Font {
        .system(size: 11, weight: .semibold, design: .default)
    }
}

struct KlarCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(KlarColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.3), radius: 12)
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(KlarFonts.sectionHeader())
            .tracking(2)
            .foregroundStyle(KlarColors.secondary)
            .textCase(.uppercase)
    }
}

struct CategoryPill: View {
    let name: String
    let color: Color

    var body: some View {
        Text(name.uppercased())
            .font(.system(size: 9, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

struct StatusBadge: View {
    let status: UploadStatus

    var color: Color {
        switch status {
        case .parsing: return .orange
        case .success: return KlarColors.positive
        case .needsReview: return KlarColors.negative
        }
    }

    var body: some View {
        Text(status.rawValue)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}
