//
//  ProgressRingView.swift
//  DailyFlightPlan
//
import SwiftUI

/// A small donut/ring showing completion progress for the day.
struct ProgressRingView: View {

    /// Completion ratio from 0.0 (none done) to 1.0 (all done).
    let progress: Double

    /// Completed and total item counts for accessibility.
    let completed: Int
    let total: Int

    private var ringColor: Color {
        // Hue sweeps red (0°) → yellow (60°) → green (120°) as progress goes 0→1
        Color(hue: progress / 3.0, saturation: 0.75, brightness: 0.85)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.2),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round))
            Circle()
                .trim(from: 0, to: progress)
                .stroke(ringColor,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.4), value: progress)
        }
        .frame(width: 26, height: 26)
        .accessibilityLabel("\(completed) of \(total) items completed")
    }
}

#Preview {
    HStack(spacing: 20) {
        ProgressRingView(progress: 0,    completed: 0, total: 6)
        ProgressRingView(progress: 0.33, completed: 2, total: 6)
        ProgressRingView(progress: 0.67, completed: 4, total: 6)
        ProgressRingView(progress: 1,    completed: 6, total: 6)
    }
    .padding()
}
