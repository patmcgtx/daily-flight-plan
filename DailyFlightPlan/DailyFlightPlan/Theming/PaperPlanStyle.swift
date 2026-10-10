//
//  PaperPlanStyle.swift
//  DailyFlightPlan
//
import SwiftUI

/// Color/font tokens for the "Paper Plan" design-sprint tab — a filed-flight-plan, typewritten
/// look (monospaced type, flat black borders, hard offset shadows, highlighter-yellow accents).
/// Deliberately separate from `DFPTheme`: these are fixed values for one experimental tab, not a
/// user-selectable theme applied app-wide.
enum PaperPlanStyle {

    static let background = Color(red: 0xE9 / 255, green: 0xE5 / 255, blue: 0xDA / 255)
    static let surface = Color(red: 0xF8 / 255, green: 0xF7 / 255, blue: 0xF1 / 255)
    static let ink = Color(red: 0x10 / 255, green: 0x10 / 255, blue: 0x10 / 255)
    static let muted = Color(red: 0x55 / 255, green: 0x55 / 255, blue: 0x55 / 255)
    static let border = Color(red: 0x11 / 255, green: 0x11 / 255, blue: 0x11 / 255)
    static let highlighter = Color(red: 0xF2 / 255, green: 0xED / 255, blue: 0x37 / 255)
    static let routeBlue = Color(red: 0x51 / 255, green: 0x69 / 255, blue: 0x9A / 255)
    static let shadow = Color.black.opacity(0.18)

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
}

extension View {
    /// Flat black border + hard (non-blurred) offset shadow, the signature "stamped paper" look.
    func paperCardBorder(lineWidth: CGFloat = 1.5) -> some View {
        self
            .background(PaperPlanStyle.surface)
            .overlay(Rectangle().stroke(PaperPlanStyle.border, lineWidth: lineWidth))
            .background {
                Rectangle()
                    .fill(PaperPlanStyle.shadow)
                    .offset(x: 3, y: 4)
            }
    }
}
