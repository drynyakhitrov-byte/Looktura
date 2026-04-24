import SwiftUI

enum AppThemeKey: String, CaseIterable, Identifiable {
    case ivory, black
    var id: String { rawValue }

    var label: String {
        switch self {
        case .ivory: return "Светлая"
        case .black: return "Тёмная"
        }
    }
}

struct AppTheme: Equatable {
    let key: AppThemeKey
    let bg: Color
    let surface: Color
    let ink: Color
    let muted: Color
    let line: Color
    let pill: Color
    let accent: Color
    let accentDeep: Color
    let accentInk: Color
    let pop: Color
    let danger: Color
    let success: Color
    let stage: Color
    let isDark: Bool

    static let ivory = AppTheme(
        key: .ivory,
        bg: .init(hex: "#F4F0E8"),
        surface: .init(hex: "#FFFFFF"),
        ink: .init(hex: "#111010"),
        muted: .init(hex: "#7A746C"),
        line: .init(hex: "#111010", opacity: 0.10),
        pill: .init(hex: "#E8E3D8"),
        accent: .init(hex: "#9E8BAF"),
        accentDeep: .init(hex: "#6E5A82"),
        accentInk: .init(hex: "#FFFFFF"),
        pop: .init(hex: "#C7E04A"),
        danger: .init(hex: "#E9553C"),
        success: .init(hex: "#4F8F6C"),
        stage: .init(hex: "#EAE3D3"),
        isDark: false
    )

    static let black = AppTheme(
        key: .black,
        bg: .init(hex: "#0F0E0D"),
        surface: .init(hex: "#1A1917"),
        ink: .init(hex: "#F4F0E8"),
        muted: .init(hex: "#938B80"),
        line: .init(hex: "#F4F0E8", opacity: 0.12),
        pill: .init(hex: "#26231F"),
        accent: .init(hex: "#C9B4DD"),
        accentDeep: .init(hex: "#9E8BAF"),
        accentInk: .init(hex: "#111010"),
        pop: .init(hex: "#C7E04A"),
        danger: .init(hex: "#E9553C"),
        success: .init(hex: "#6BA98A"),
        stage: .init(hex: "#18171C"),
        isDark: true
    )

    static func theme(for key: AppThemeKey) -> AppTheme {
        switch key {
        case .ivory: return .ivory
        case .black: return .black
        }
    }
}

private struct AppThemeKey_Key: EnvironmentKey {
    static let defaultValue: AppTheme = .ivory
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey_Key.self] }
        set { self[AppThemeKey_Key.self] = newValue }
    }
}

extension Color {
    init(hex: String, opacity: Double = 1.0) {
        var h = hex.trimmingCharacters(in: .alphanumerics.inverted)
        if h.hasPrefix("#") { h.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

enum AppFont {
    static let serif = "Fraunces9pt"
    static let sans = "Inter"
    static let mono = "JetBrainsMono"

    static func registerFonts() {
        let names = [
            "Fraunces-Regular", "Fraunces-Light", "Fraunces-SemiBold", "Fraunces-Bold",
            "Inter-Regular", "Inter-Medium", "Inter-SemiBold", "Inter-Bold",
            "JetBrainsMono-Regular", "JetBrainsMono-Medium", "JetBrainsMono-SemiBold", "JetBrainsMono-Bold"
        ]
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

extension Font {
    static func serif(_ size: CGFloat, weight: Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .light, .ultraLight, .thin: name = "Fraunces9pt-Light"
        case .semibold: name = "Fraunces9pt-SemiBold"
        case .bold, .heavy, .black: name = "Fraunces9pt-Bold"
        default: name = "Fraunces9pt-Regular"
        }
        return .custom(name, size: size)
    }

    static func sans(_ size: CGFloat, weight: Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .medium: name = "Inter-Medium"
        case .semibold: name = "Inter-SemiBold"
        case .bold, .heavy, .black: name = "Inter-Bold"
        default: name = "Inter-Regular"
        }
        return .custom(name, size: size)
    }

    static func mono(_ size: CGFloat, weight: Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .medium: name = "JetBrainsMono-Medium"
        case .semibold: name = "JetBrainsMono-SemiBold"
        case .bold, .heavy, .black: name = "JetBrainsMono-Bold"
        default: name = "JetBrainsMono-Regular"
        }
        return .custom(name, size: size)
    }
}
