//
//  ContentView.swift
//  DailyFlightPlan
//
import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        DayView()
    }
}

#Preview {
    ContentView()
        .modelContainer(try! ModelContainer.inMemorySampleContainer())
}
