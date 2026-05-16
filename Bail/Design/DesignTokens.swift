import SwiftUI
import UIKit

// MARK: - Adaptive color helper

private extension UIColor {
    /// Creates a color that automatically switches between light and dark appearances.
    static func adaptive(light: String, dark: String) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) }
    }

    convenience init(hex: String) {
        var int: UInt64 = 0
        Scanner(string: hex.trimmingCharacters(in: .alphanumerics.inverted)).scanHexInt64(&int)
        self.init(
            red:   CGFloat((int >> 16) & 0xFF) / 255,
            green: CGFloat((int >> 8)  & 0xFF) / 255,
            blue:  CGFloat( int        & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Colors

enum BailColor {
    // Backgrounds
    static let background  = Color(UIColor.adaptive(light: "F2F2F7", dark: "0A0A0A"))
    static let surface     = Color(UIColor.adaptive(light: "FFFFFF", dark: "141414"))
    static let surface2    = Color(UIColor.adaptive(light: "F0F0F0", dark: "1A1A1A"))
    static let surfaceDeep = Color(UIColor.adaptive(light: "E8E8ED", dark: "0F0F0F"))

    // Borders
    static let border      = Color(UIColor.adaptive(light: "D8D8D8", dark: "2A2A2A"))
    static let cardBorder  = Color(UIColor.adaptive(light: "E0E0E0", dark: "222222"))

    // Accent (same in both modes)
    static let accentStart = Color(hex: "FF4458")
    static let accentEnd   = Color(hex: "FF6B35")
    static let teal        = Color(hex: "4ECDC4")
    static let tealEnd     = Color(hex: "2EC4B6")

    // Text
    static let textPrimary   = Color(UIColor.adaptive(light: "000000", dark: "FFFFFF"))
    static let textSecondary = Color(UIColor.adaptive(light: "555555", dark: "666666"))
    static let textSubtle    = Color(UIColor.adaptive(light: "888888", dark: "555555"))
    static let textMuted     = Color(UIColor.adaptive(light: "AAAAAA", dark: "444444"))
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
