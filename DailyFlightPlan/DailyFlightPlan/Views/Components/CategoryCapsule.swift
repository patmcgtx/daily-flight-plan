//
//  CategoryCapsule.swift
//  DailyFlightPlan
//
import SwiftUI

/// A selectable capsule pill for a plan category, used in the filter sub-bar.
struct CategoryCapsule: View {

    let category: PlanCategory

    @Environment(\.categorySelectionService)
    private var categorySelectionService: CategorySelectionService?

    var body: some View {
        let isSelected = categorySelectionService?.isSelected(category) ?? false
        Button {
            withAnimation(.spring(duration: 0.2)) {
                categorySelectionService?.toggle(category)
            }
        } label: {
            Text(category.name)
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .background {
            if isSelected {
                Capsule().fill(Color.accentColor)
            } else {
                Capsule().fill(.regularMaterial)
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: isSelected)
    }
}
