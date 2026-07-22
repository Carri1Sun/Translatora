import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }

    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum AppTheme {
    static let accent = Color(red: 149 / 255, green: 236 / 255, blue: 104 / 255)
    static let accentDeep = Color(red: 54 / 255, green: 135 / 255, blue: 50 / 255)
    static let accentSoft = Color(red: 214 / 255, green: 250 / 255, blue: 196 / 255)
    static let ink = Color(red: 19 / 255, green: 31 / 255, blue: 24 / 255)
}
