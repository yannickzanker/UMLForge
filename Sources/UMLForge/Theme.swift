import SwiftUI
import AppKit

// MARK: - Farben

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

enum Theme {
    // Palette – exakt laut Design-System
    static let bgTop = Color(hex: 0x161311)
    static let bgBottom = Color(hex: 0x0A0908)
    static let panel = Color(hex: 0x121110)
    static let border = Color(hex: 0x2C2723)
    static let accent = Color(hex: 0xFF8A1E)
    static let accentHover = Color(hex: 0xFFA64D)
    static let accentPressed = Color(hex: 0xE26F0A)
    static let success = Color(hex: 0x34D399)
    static let error = Color(hex: 0xF87171)
    static let warning = Color(hex: 0xFBBF24)
    static let textPrimary = Color(hex: 0xF5F1EA)
    static let textSecondary = Color(hex: 0xB3ACA3)
    static let textMuted = Color(hex: 0x736C63)
    static let input = Color(hex: 0x181512)

    // Abgeleitete Töne im selben warmen Schwarz-Bereich
    static let panelRaised = Color(hex: 0x171412)
    static let panelHover = Color(hex: 0x1C1916)
    static let borderStrong = Color(hex: 0x3A332E)
    static let gridDot = Color(hex: 0x221E1B)
    static let gridDotMajor = Color(hex: 0x2C2723)

    /// Akzent als rgba(255, 138, 30, a) für Flächen
    static func accentFill(_ opacity: Double) -> Color { Color(hex: 0xFF8A1E, opacity: opacity) }

    static let background = LinearGradient(colors: [bgTop, bgBottom], startPoint: .top, endPoint: .bottom)

    static let radiusCard: CGFloat = 14
    static let radiusControl: CGFloat = 8
    static let radiusChip: CGFloat = 7
}

// MARK: - Schriften

enum Fonts {
    private static let manager = NSFontManager.shared
    private static let families = Set(NSFontManager.shared.availableFontFamilies)

    /// "Segoe UI", "Inter", "SF Pro Display", sans-serif
    static let uiFamily: String? = ["Segoe UI", "Inter", "SF Pro Display"].first { families.contains($0) }
    /// "Cascadia Code", "JetBrains Mono", "Consolas", monospace
    static let monoFamily: String? = ["Cascadia Code", "JetBrains Mono", "Consolas"].first { families.contains($0) }

    private static var cache: [String: NSFont] = [:]

    static func ns(_ size: CGFloat, _ weight: NSFont.Weight = .regular, mono: Bool = false, italic: Bool = false) -> NSFont {
        let key = "\(size)|\(weight.rawValue)|\(mono)|\(italic)"
        if let cached = cache[key] { return cached }

        var font: NSFont
        if let family = mono ? monoFamily : uiFamily,
           let named = manager.font(withFamily: family,
                                    traits: weight.rawValue >= NSFont.Weight.semibold.rawValue ? .boldFontMask : [],
                                    weight: managerWeight(weight),
                                    size: size) {
            font = named
        } else {
            font = mono
                ? .monospacedSystemFont(ofSize: size, weight: weight)
                : .systemFont(ofSize: size, weight: weight)   // = SF Pro (Fallback sans-serif)
        }
        if italic { font = manager.convert(font, toHaveTrait: .italicFontMask) }

        if cache.count > 400 { cache.removeAll(keepingCapacity: true) }
        cache[key] = font
        return font
    }

    static func font(_ size: CGFloat, _ weight: NSFont.Weight = .regular, mono: Bool = false, italic: Bool = false) -> Font {
        Font(ns: ns(size, weight, mono: mono, italic: italic))
    }

    private static func managerWeight(_ w: NSFont.Weight) -> Int {
        switch w.rawValue {
        case ..<(-0.3): return 3
        case ..<0.1: return 5
        case ..<0.27: return 6
        case ..<0.35: return 8
        default: return 9
        }
    }
}

extension Font {
    init(ns font: NSFont) { self.init(font as CTFont) }
}

/// Typo-Skala.
/// Hinweis: 11pt (Qt/Windows, 96 dpi) entspricht optisch ~13 macOS-Punkten.
enum Typo {
    static let body = Fonts.font(13)                 // Fließtext (11pt)
    static let bodyMedium = Fonts.font(13, .medium)
    static let bodySemibold = Fonts.font(13, .semibold)
    static let title = Fonts.font(15, .semibold)
    static let label = Fonts.font(11)                // Sekundärtext/Labels 10–11px
    static let labelMedium = Fonts.font(11, .medium)
    static let section = Fonts.font(11, .bold)       // Sektionstitel (9pt), GROSS
    static let sectionTracking: CGFloat = 0.88       // ~108 % Buchstabenabstand
    static let mono = Fonts.font(12, mono: true)
    static let monoSmall = Fonts.font(11, mono: true)
}
