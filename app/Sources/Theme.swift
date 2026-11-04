// Theme.swift — the dusk palette (dark) and warm paper (light).
// Tokens come from the product rules: dark is a warm purple-grey, not black.

import SwiftUI
import AppKit

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

enum Palette {
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }

    static let paper  = dynamic(light: 0xF7F4EF, dark: 0x1E1B22)
    static let nav    = dynamic(light: 0xEFEAE2, dark: 0x262230)
    static let ink    = dynamic(light: 0x2A2622, dark: 0xECE7E1)
    static let muted  = dynamic(light: 0x6E665C, dark: 0x9C93A6)
    static let rule   = dynamic(light: 0xDED7CC, dark: 0x3A3446)
    static let accent = dynamic(light: 0xC4663A, dark: 0xE0895F)
    static let ok     = dynamic(light: 0x3F7A52, dark: 0x7FBF95)
    static let warn   = dynamic(light: 0x9A6A1E, dark: 0xD8A860)
}

enum ThemeMode: String, CaseIterable {
    case auto, light, dark

    var label: String {
        switch self {
        case .auto: return "跟隨系統"
        case .light: return "淺色"
        case .dark: return "深色"
        }
    }

    var appearance: NSAppearance? {
        switch self {
        case .auto: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }

    static func apply(_ raw: String) {
        let mode = ThemeMode(rawValue: raw) ?? .auto
        NSApp.appearance = mode.appearance
    }
}
