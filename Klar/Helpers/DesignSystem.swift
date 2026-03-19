import SwiftUI
import UIKit

enum KlarColors {
    static let background = Color(hex: "#F5F0E8")
    static let surface = Color.white
    static let surfaceElevated = Color(hex: "#EDE8E0")
    static let primary = Color(hex: "#1A1A1A")
    static let secondary = Color(hex: "#7A7A7A")
    static let positive = Color(hex: "#4A8C5C")
    static let negative = Color(hex: "#C0392B")
    static let tabBarBg = Color(hex: "#2A2A2A")
    static let tabBarBorder = Color(hex: "#3A3A3A")
    static let inactive = Color(hex: "#AAAAAA")
    static let barTrack = Color(hex: "#E0DBD3")
    static let accent = Color(hex: "#D64B8A")
    static let dropZone = Color(hex: "#C8D4E8")
    static let searchHighlight = Color(hex: "#E8C840")
    static let dashedBorder = Color(hex: "#C0B8A8")

    static let shopping = Color(hex: "#E8D44D")
    static let entertainment = Color(hex: "#E8A060")
    static let health = Color(hex: "#6BBF8A")
    static let finance = Color(hex: "#8E9FD0")
    static let transport = Color(hex: "#5BAFCF")
    static let utilities = Color(hex: "#D64B8A")
    static let misc = Color(hex: "#9B8EC2")
    static let food = Color(hex: "#E07B5A")
    static let income = Color(hex: "#4A8C5C")

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
    func toHex() -> String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

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
        .system(size: size, weight: .black, design: .rounded)
    }

    static func heading(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func body(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    static func label(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    static func sectionHeader() -> Font {
        .system(size: 13, weight: .black, design: .rounded)
    }
}

struct KlarCard<Content: View>: View {
    let content: Content
    var dashedBorder: Bool = false

    init(dashedBorder: Bool = false, @ViewBuilder content: () -> Content) {
        self.dashedBorder = dashedBorder
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(KlarColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        dashedBorder ? KlarColors.dashedBorder : .clear,
                        style: StrokeStyle(lineWidth: dashedBorder ? 1.5 : 0, dash: dashedBorder ? [6, 4] : [])
                    )
            )
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(KlarFonts.sectionHeader())
            .tracking(1.5)
            .foregroundStyle(KlarColors.primary)
            .textCase(.uppercase)
    }
}

struct CategoryPill: View {
    let name: String
    let color: Color

    var body: some View {
        Text(name.uppercased())
            .font(.system(size: 10, weight: .bold))
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
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}
