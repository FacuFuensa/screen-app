import SwiftUI
import UIKit

enum Theme {
    static let ink = adaptive(light: 0x25235C, dark: 0xA7A5E8)
    static let coral = adaptive(light: 0xFF7163, dark: 0xFF8A7E)
    static let amber = adaptive(light: 0xFFC857, dark: 0xFFD77D)
    static let cream = adaptive(light: 0xFFF7EB, dark: 0x141331)
    static let background = adaptive(light: 0xFFF7EB, dark: 0x141331)
    static let card = adaptive(light: 0xFFFFFF, dark: 0x1F1D45)
    static let secondaryText = adaptive(light: 0x68657A, dark: 0xC7C4D8)

    static func avatarColor(for name: String) -> Color {
        let hash = name.unicodeScalars.reduce(UInt64(5381)) { ($0 &* 33) &+ UInt64($1.value) }
        return [coral, amber, adaptive(light: 0x6764B8, dark: 0x8E8BDD)][Int(hash % 3)]
    }

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in color(traits.userInterfaceStyle == .dark ? dark : light) })
    }

    private static func color(_ hex: UInt32) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1)
    }
}
