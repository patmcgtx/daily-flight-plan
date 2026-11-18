//
//  CategoriesToolbarButton.swift
//  DailyFlightPlan
//
import SwiftUI

/// Cockpit toolbar button that opens only the category selector (`CategoriesSelectFlow`) as a
/// popover anchored to the button. Fills its icon when any category is selected. Display options
/// live separately in `CockpitViewMenu`.
struct CategoriesToolbarButton: View {

    @State private var isShowingCategories = false

    @Environment(\.categorySelectionService)
    private var categorySelectionService: CategorySelectionService?

    private var isActive: Bool {
        categorySelectionService?.hasSelectedCategories ?? false
    }

    var body: some View {
        Button {
            isShowingCategories = true
        } label: {
            Image(systemName: isActive ? "tag.fill" : "tag")
                .foregroundStyle(isActive ? Color.accentColor : Color.primary)
        }
        .accessibilityLabel("Categories")
        .popover(
            isPresented: $isShowingCategories,
            attachmentAnchor: .point(.bottom),
            arrowEdge: .top
        ) {
            NavigationStack {
                Form {
                    Section {
                        CategoriesSelectFlow()
                    }
                }
                .navigationTitle("Categories")
                .inlineNavigationTitle()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { isShowingCategories = false }
                    }
                }
            }
            // Same explicit sizing as `FilterToolbarButton`: a Form has no intrinsic height, so
            // without it the popover collapses to its nav bar.
            .frame(minWidth: 300, idealWidth: 400, maxWidth: .infinity,
                   minHeight: 400, idealHeight: 500, maxHeight: 600)
            .presentationCompactAdaptation(.popover)
        }
    }
}
