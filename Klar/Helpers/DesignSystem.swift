import SwiftUI
import UIKit

// MARK: - Theme
enum KlarTheme: String, CaseIterable {
    case cream = "Cream"
    case midnight = "Midnight"
    case system = "System"

    var previewGradient: LinearGradient {
        switch self {
        case .cream:
            return LinearGradient(colors: [Color(hex: "#F8F7F4"), Color(hex: "#EFEDE8")], startPoint: .top, endPoint: .bottom)
        case .midnight:
            return LinearGradient(colors: [Color(hex: "#1A1A1E"), Color(hex: "#2A2A2E")], startPoint: .top, endPoint: .bottom)
        case .system:
            return LinearGradient(colors: [Color(hex: "#F8F7F4"), Color(hex: "#1A1A1E")], startPoint: .leading, endPoint: .trailing)
        }
    }
}

// MARK: - Colors (New Unified Palette)
enum KlarColors {
    @AppStorage("selectedTheme") private static var selectedTheme: String = "Cream"

    static var isDark: Bool {
        if selectedTheme == "System" {
            return UITraitCollection.current.userInterfaceStyle == .dark
        }
        return selectedTheme == "Midnight"
    }

    // Backgrounds
    static var background: Color { isDark ? Color(hex: "#1A1A1E") : Color(hex: "#F8F7F4") }
    static var surface: Color { isDark ? Color(hex: "#2A2A2E") : Color(hex: "#FFFFFF") }
    static var surfaceElevated: Color { isDark ? Color(hex: "#3A3A3E") : Color(hex: "#F0EDE8") }
    static var cardBg: Color { isDark ? Color(hex: "#2A2A2E").opacity(0.7) : Color(hex: "#FFFFFF").opacity(0.7) }

    // Text
    static var primary: Color { isDark ? Color(hex: "#F0EDE8") : Color(hex: "#1C1C1E") }
    static var secondary: Color { isDark ? Color(hex: "#8A8A8E") : Color(hex: "#6B6B6B") }
    static var inactive: Color { isDark ? Color(hex: "#5A5A5E") : Color(hex: "#ACACAC") }

    // Borders
    static var border: Color { isDark ? Color(hex: "#3A3A3E") : Color(hex: "#E6E2DB") }
    static var dashedBorder: Color { isDark ? Color(hex: "#4A4A4E") : Color(hex: "#D6D2CB") }
    static var barTrack: Color { isDark ? Color(hex: "#3A3A3E") : Color(hex: "#E6E2DB") }

    // Semantic
    static let positive = Color(hex: "#6FCF97")
    static let negative = Color(hex: "#EB5757")
    static let accent = Color(hex: "#FF8A5B")

    // Tab bar
    static var tabBarBg: Color { isDark ? Color(hex: "#1A1A1E").opacity(0.8) : Color(hex: "#FFFFFF").opacity(0.8) }
    static var tabBarBorder: Color { isDark ? Color(hex: "#3A3A3E") : Color(hex: "#E6E2DB") }

    // Misc
    static var dropZone: Color { isDark ? Color(hex: "#3A4A5A") : Color(hex: "#E8E4DB") }
    static let searchHighlight = Color(hex: "#FF8A5B")

    // Category colors (soft pastel palette)
    static let shopping = Color(hex: "#F6B7C4")
    static let entertainment = Color(hex: "#A0C4FF")
    static let health = Color(hex: "#B7E4C7")
    static let finance = Color(hex: "#A0C4FF")
    static let transport = Color(hex: "#CDB4DB")
    static let utilities = Color(hex: "#B7E4C7")
    static let misc = Color(hex: "#D4C5A9")
    static let food = Color(hex: "#FFD6A5")
    static let income = Color(hex: "#6FCF97")

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
        default: return Color(hex: "#D4C5A9")
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

// MARK: - Typography
enum KlarFonts {
    static func display(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func heading(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static func body(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    static func label(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }

    static func sectionHeader() -> Font {
        .system(size: 13, weight: .bold, design: .rounded)
    }

    static func serifItalic(_ size: CGFloat = 30) -> Font {
        .system(size: size, weight: .bold, design: .serif).italic()
    }

    static func dataValue(_ size: CGFloat = 32) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }

    static func cardTitle() -> Font {
        .system(size: 13, weight: .semibold)
    }
}

// MARK: - Animation
enum KlarAnimation {
    static let springDefault = Animation.spring(response: 0.4, dampingFraction: 0.85)
    static let springBouncy = Animation.spring(response: 0.6, dampingFraction: 0.7)
    static let springSnappy = Animation.spring(response: 0.3, dampingFraction: 0.9)
    static let staggerDelay: TimeInterval = 0.08
}

// MARK: - Glass Card Component (Liquid Glass)
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
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(KlarColors.isDark ? 0.1 : 0.6),
                                Color.white.opacity(KlarColors.isDark ? 0.05 : 0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: dashedBorder ? 0 : 1
                    )
            )
            .overlay(
                dashedBorder ?
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        KlarColors.border,
                        style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                    ) : nil
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(KlarFonts.cardTitle())
            .tracking(1.5)
            .foregroundStyle(KlarColors.primary)
            .textCase(.uppercase)
    }
}

// MARK: - Category Pill
struct CategoryPill: View {
    let name: String
    let color: Color

    var body: some View {
        Text(name.capitalized)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let status: UploadStatus

    var color: Color {
        switch status {
        case .parsing: return KlarColors.accent
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

// MARK: - Pressable Card Modifier
struct PressableCardModifier: ViewModifier {
    @State private var isPressed = false
    let action: (() -> Void)?

    init(action: (() -> Void)? = nil) {
        self.action = action
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(KlarAnimation.springSnappy, value: isPressed)
            .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                isPressed = pressing
                if pressing { HapticManager.light() }
            }, perform: {})
            .simultaneousGesture(
                TapGesture().onEnded {
                    action?()
                }
            )
    }
}

extension View {
    func pressableCard(action: (() -> Void)? = nil) -> some View {
        modifier(PressableCardModifier(action: action))
    }
}

// MARK: - Staggered Appearance
struct StaggeredAppearance: ViewModifier {
    let index: Int
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.8)
                .delay(Double(index) * KlarAnimation.staggerDelay),
                value: isVisible
            )
            .onAppear {
                isVisible = true
            }
    }
}

extension View {
    func staggeredAppearance(index: Int) -> some View {
        modifier(StaggeredAppearance(index: index))
    }
}

// MARK: - Shimmer Loading
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            .clear,
                            KlarColors.surfaceElevated.opacity(0.5),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.5)
                    .offset(x: phase * geo.size.width)
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton View
struct SkeletonRect: View {
    let height: CGFloat
    let cornerRadius: CGFloat

    init(height: CGFloat = 80, cornerRadius: CGFloat = 14) {
        self.height = height
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(KlarColors.surfaceElevated)
            .frame(height: height)
            .shimmer()
    }
}

struct DashboardSkeleton: View {
    var body: some View {
        VStack(spacing: 16) {
            SkeletonRect(height: 120)
            SkeletonRect(height: 180)
            SkeletonRect(height: 200)
        }
        .padding(.horizontal, 20)
    }
}

struct LedgerSkeleton: View {
    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { _ in
                SkeletonRect(height: 56)
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Sliding Picker (Liquid Glass)
struct SlidingPicker: View {
    @Binding var selection: AccountType
    @Namespace private var pickerAnimation

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AccountType.allCases, id: \.self) { type in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selection = type
                    }
                    HapticManager.light()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: type == .savings ? "banknote" : type == .credit ? "creditcard" : "wallet.pass")
                            .font(.system(size: 11))
                        Text(type.rawValue.uppercased())
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .foregroundColor(selection == type ? .white : KlarColors.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .background {
                        if selection == type {
                            Capsule()
                                .fill(KlarColors.accent)
                                .matchedGeometryEffect(id: "pickerPill", in: pickerAnimation)
                        }
                    }
                }
            }
        }
        .padding(4)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(KlarColors.border.opacity(0.5), lineWidth: 0.5)
        )
    }
}
