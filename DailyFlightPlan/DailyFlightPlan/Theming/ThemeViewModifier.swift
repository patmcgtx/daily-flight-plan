//
//  ThemeViewModifier.swift
//  DailyFlightPlan
//
import SwiftUI

/// Applies theme-specific styling in a single modifier so the view hierarchy type never
/// changes when the theme switches, preserving view identity and associated state.
struct ThemeViewModifier: ViewModifier {

    let theme: DFPTheme

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .tint(theme.tintColor)
            .foregroundStyle(theme.foregroundColor(for: colorScheme))
            .fontDesign(theme.fontDesign)
            .fontWeight(theme.fontWeight)
            .textCase(theme.textCase)
    }
}

extension View {
    func apply(theme: DFPTheme) -> some View {
        self.modifier(ThemeViewModifier(theme: theme))
    }
}
