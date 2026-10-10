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

    static func mono(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .monospaced).weight(weight)
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
