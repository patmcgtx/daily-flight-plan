//
//  PaperPlanStyle.swift
//  DailyFlightPlan
//
import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Color/font tokens for the "Paper Plan" design-sprint tab — a filed-flight-plan, typewritten
/// look (monospaced type, flat borders, highlighter-yellow accents). Deliberately separate from
/// `DFPTheme`: these are fixed values for one experimental tab, not a user-selectable theme
/// applied app-wide. Colors below adapt to light/dark automatically ("Paper Night").
enum PaperPlanStyle {

    static let background = adaptive(light: rgb(0xE9, 0xE5, 0xDA), dark: rgb(0x0A, 0x0D, 0x12))
    static let surface = adaptive(light: rgb(0xF8, 0xF7, 0xF1), dark: rgb(0x12, 0x17, 0x1D))
    static let ink = adaptive(light: rgb(0x10, 0x10, 0x10), dark: rgb(0xF3, 0xF5, 0xF7))
    static let muted = adaptive(light: rgb(0x55, 0x55, 0x55), dark: rgb(0x9A, 0xA6, 0xB2))
    static let border = adaptive(light: rgb(0x11, 0x11, 0x11), dark: rgb(0x6F, 0x7A, 0x85))
    static let highlighter = adaptive(light: rgb(0xF2, 0xED, 0x37), dark: rgb(0xF1, 0xC8, 0x4C))
    static let routeBlue = adaptive(light: rgb(0x51, 0x69, 0x9A), dark: rgb(0x7F, 0xA9, 0xDC))
    static let shadow = Color.black.opacity(0.18)

    /// Text sitting on a solid/near-solid highlighter background always needs dark ink, in both
    /// color schemes — unlike the rest of the palette, the yellow itself doesn't invert for dark
    /// mode, so text on top of it can't just follow `ink`.
    static let inkOnHighlighter = rgb(0x10, 0x10, 0x10)

    /// IBM Plex Mono, bundled under Theming/Fonts and registered via Info.plist's `UIAppFonts`.
    /// Each static weight ships as its own PostScript name (not a single weight-linked family),
    /// so the lookup is by exact weight rather than applying `.weight()` to one base font.
    /// Falls back to the system monospaced design for any weight we didn't bundle.
    static func mono(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        let size = pointSize(for: style)
        switch weight {
        case .bold:
            return .custom("IBMPlexMono-Bold", size: size, relativeTo: style)
        case .semibold:
            return .custom("IBMPlexMono-SmBld", size: size, relativeTo: style)
        case .regular:
            return .custom("IBMPlexMono", size: size, relativeTo: style)
        default:
            return .system(style, design: .monospaced).weight(weight)
        }
    }

    /// Standard iOS Dynamic Type point sizes at the default (Large) content size category —
    /// `Font.custom(_:size:relativeTo:)` needs an explicit base size to scale from.
    private static func pointSize(for style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: return 34
        case .title: return 28
        case .title2: return 22
        case .title3: return 20
        case .headline, .body: return 17
        case .callout: return 16
        case .subheadline: return 15
        case .footnote: return 13
        case .caption: return 12
        case .caption2: return 11
        default: return 17
        }
    }

    private static func rgb(_ r: Int, _ g: Int, _ b: Int) -> Color {
        Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }

    /// A `Color` that resolves to `light` or `dark` based on the active trait/appearance at
    /// render time, so call sites can use a plain `Color` constant without threading
    /// `colorScheme` through every view.
    private static func adaptive(light: Color, dark: Color) -> Color {
        #if os(iOS)
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #elseif os(macOS)
        Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(dark) : NSColor(light)
        })
        #else
        light
        #endif
    }
}
