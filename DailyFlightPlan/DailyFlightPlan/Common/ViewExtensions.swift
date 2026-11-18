//
//  ViewExtensions.swift
//  DailyFlightPlan
//
import SwiftUI

extension View {
    /// Applies `.navigationBarTitleDisplayMode(.inline)` on iOS/iPadOS only.
    /// On native macOS, this modifier is unavailable and is a no-op.
    @ViewBuilder
    func inlineNavigationTitle() -> some View {
        #if os(macOS)
        self
        #else
        self.navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

/// Applies `.textCase(.uppercase)` unless the user turned UPPERCASE off in the Cockpit's View menu.
private struct CockpitUppercaseModifier: ViewModifier {
    @AppStorage(AppStorageKeys.uppercaseText.rawValue)
    private var uppercaseText: Bool = true

    func body(content: Content) -> some View {
        content.textCase(uppercaseText ? .uppercase : nil)
    }
}

extension View {
    /// Uppercases text in the Cockpit's paper style, honoring the "UPPERCASE" view option.
    func cockpitUppercase() -> some View {
        modifier(CockpitUppercaseModifier())
    }
}

extension ToolbarItemPlacement {
    /// `.topBarTrailing` on iOS/iPadOS; `.automatic` on macOS.
    static var trailingBar: ToolbarItemPlacement {
        #if os(macOS)
        .automatic
        #else
        .topBarTrailing
        #endif
    }

    /// `.topBarLeading` on iOS/iPadOS; `.automatic` on macOS.
    static var leadingBar: ToolbarItemPlacement {
        #if os(macOS)
        .automatic
        #else
        .topBarLeading
        #endif
    }
}
