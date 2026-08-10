//
//  SettingsView.swift
//  DailyFlightPlan
//
import SwiftUI
import SwiftData

struct SettingsView: View {

    @Environment(\.dismiss) private var dismiss

    let onDeleteItems: () -> Void
    let onDeleteCategories: () -> Void
    let onSeedData: () -> Void

    @State private var showDeleteItemsAlert = false
    @State private var showDeleteCategoriesAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button("Seed Sample Data") {
                        onSeedData()
                        dismiss()
                    }
                    Button("Delete All Items", role: .destructive) {
                        showDeleteItemsAlert = true
                    }
                    Button("Delete All Categories", role: .destructive) {
                        showDeleteCategoriesAlert = true
                    }
                } header: {
                    Text("Developer")
                } footer: {
                    Text("Seed adds sample data only when none exists. Deletions sync to all devices via iCloud.")
                }
            }
            .navigationTitle("Settings")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete All Items?", isPresented: $showDeleteItemsAlert) {
                Button("Delete All", role: .destructive) {
                    onDeleteItems()
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("All items and routines will be permanently deleted from every device.")
            }
            .alert("Delete All Categories?", isPresented: $showDeleteCategoriesAlert) {
                Button("Delete All", role: .destructive) {
                    onDeleteCategories()
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("All categories will be permanently deleted from every device.")
            }
        }
        #if os(macOS)
        .frame(minWidth: 360, minHeight: 260)
        #endif
    }
}

#Preview {
    SettingsView(onDeleteItems: {}, onDeleteCategories: {}, onSeedData: {})
}
