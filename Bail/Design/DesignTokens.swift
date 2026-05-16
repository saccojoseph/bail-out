import SwiftUI

// MARK: - Colors

enum BailColor {
    static let background  = Color(hex: "0A0A0A")
    static let surface     = Color(hex: "141414")
    static let surface2    = Color(hex: "1A1A1A")
    static let border      = Color(hex: "2A2A2A")
    static let accentStart = Color(hex: "FF4458")
    static let accentEnd   = Color(hex: "FF6B35")
    static let teal        = Color(hex: "4ECDC4")
    static let tealEnd     = Color(hex: "2EC4B6")
    static let textPrimary   = Color(hex: "FFFFFF")
    static let textSecondary = Color(hex: "666666")
    static let textMuted     = Color(hex: "444444")
}

// MARK: - Gradients

enum BailGradient {
    static let accent = LinearGradient(
        colors: [BailColor.accentStart, BailColor.accentEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentHorizontal = LinearGradient(
        colors: [BailColor.accentStart, BailColor.accentEnd],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let teal = LinearGradient(
        colors: [BailColor.teal, BailColor.tealEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Spacing

enum BailSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 40
}

// MARK: - Corner Radii

enum BailRadius {
    static let sm:   CGFloat = 10
    static let md:   CGFloat = 14
    static let lg:   CGFloat = 16
    static let xl:   CGFloat = 20
    static let full: CGFloat = 999
}

// MARK: - Color(hex:)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red:     Double(r) / 255,
            green:   Double(g) / 255,
            blue:    Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
