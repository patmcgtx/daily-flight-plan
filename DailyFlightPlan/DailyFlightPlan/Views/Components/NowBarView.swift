//
//  NowBarView.swift
//  DailyFlightPlan
//
import SwiftUI

struct NowBarView: View {
    var body: some View {
        HStack(spacing: 6) {
            Text("NOW")
                .font(.caption2.bold())
                .foregroundStyle(.red)
            Rectangle()
                .fill(.red)
                .frame(height: 1.5)
        }
        .padding(.horizontal, 14)
    }
}

#Preview {
    NowBarView()
        .padding()
}
