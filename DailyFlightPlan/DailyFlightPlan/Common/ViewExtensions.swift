//
//  ViewExtensions.swift
//  DailyFlightPlan
//
import SwiftUI

extension View {
    /// Applies `.navigationBarTitleDisplayMode(.inline)` on iOS/iPadOS only.
    /// On macOS (Mac Catalyst), this modifier is unavailable and is a no-op.
    @ViewBuilder
    func inlineNavigationTitle() -> some View {
        #if os(macOS)
        self
        #else
        self.navigationBarTitleDisplayMode(.inline)
        #endif
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
