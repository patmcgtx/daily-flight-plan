//
//  InlineSearchBar.swift
//  DailyFlightPlan
//
import SwiftUI

/// Toolbar button shared by Day/Routine/Timeline to toggle their own local inline search field.
/// Clears `searchText` on close so reopening always starts from an empty query.
struct SearchToggleButton: View {

    @Binding var isShowingSearch: Bool
    @Binding var searchText: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        Button {
            withAnimation {
                isShowingSearch.toggle()
                if !isShowingSearch { searchText = "" }
            }
            isFocused.wrappedValue = isShowingSearch
        } label: {
            Image(systemName: isShowingSearch ? "xmark.circle.fill" : "magnifyingglass")
        }
        .accessibilityLabel(isShowingSearch ? "Hide Search" : "Search")
    }
}

/// Minimal search field pinned above a view's content via `.safeAreaInset(edge: .top)` — no
/// Form/sheet chrome, filters whatever's on screen in real time as you type.
struct InlineSearchField: View {

    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search", text: $text)
                .focused(isFocused)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(.bar)
    }
}
