//
//  DFPTheme.swift
//  DailyFlightPlan
//
import SwiftUI

/// Themes for styling the app
enum DFPTheme: String, CaseIterable, Identifiable {

    var id: String { rawValue }

    /// The basic, default iOS theme
    case cupertino

    /// A fun, retro pixelated theme
    case eightBit

    /// An Austin-inspired cafe theme
    case kerby

    /// A Miami/flamingo-inspired theme
    case flamingo

    var localizedName: String {
        switch self {
        case .cupertino: return "Standard"
        case .eightBit: return "8-Bit"
        case .kerby: return "Kerby"
        case .flamingo: return "Flamingo"
        }
    }

    var fontDesign: Font.Design {
        switch self {
        case .eightBit: return .monospaced
        case .kerby: return .rounded
        default: return .default
        }
    }

    var fontWeight: Font.Weight? {
        switch self {
        case .kerby: return .bold
        default: return nil
        }
    }

    var textCase: Text.Case? {
        switch self {
        case .kerby: return .uppercase
        default: return nil
        }
    }

    var menuIconName: String {
        switch self {
        case .cupertino: return "paintbrush"
        default: return "paintbrush.fill"
        }
    }

    func foregroundColor(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .cupertino: return .primary
        case .eightBit: return highContrastGreen(for: colorScheme)
        case .kerby: return highContrastOrange(for: colorScheme)
        case .flamingo: return highContrastPink(for: colorScheme)
        }
    }

    var tintColor: Color {
        switch self {
        case .cupertino: return .accentColor
        case .eightBit: return .green
        case .kerby: return .orange
        case .flamingo: return softFlamingoPink
        }
    }

    /// Font color to use on a selected capsule (which has tintColor as its background)
    var selectedCapsuleFontColor: Color {
        switch self {
        case .cupertino: return .white
        case .eightBit: return .black
        case .kerby: return .white
        case .flamingo: return .black
        }
    }

    // MARK: Private helpers

    private func highContrastGreen(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .green : Color(red: 0/255, green: 130/255, blue: 40/255)
    }

    private func highContrastOrange(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .orange : Color(red: 175/255, green: 82/255, blue: 0/255)
    }

    private func highContrastPink(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? softFlamingoPink : .pink
    }

    private var softFlamingoPink: Color {
        Color(red: 252/255, green: 142/255, blue: 172/255)
    }
}
