//
//  PendingImportBanner.swift
//  DailyFlightPlan
//
import SwiftUI
import SwiftData

/// Surfaces the Share Extension's import backlog (see PendingImport) at the top of the day view.
/// Owns its own ModelContainer scope, separate from the app's main CloudKit-synced container,
/// since the backlog lives in a local-only App Group store shared with ShareImport.
struct PendingImportBannerHost: View {

    var onReview: (_ text: String, _ clear: @escaping () -> Void) -> Void

    @State private var container: ModelContainer?

    var body: some View {
        Group {
            if let container {
                PendingImportBanner(onReview: onReview)
                    .modelContainer(container)
            }
        }
        .task {
            guard container == nil else { return }
            container = try? ModelContainer.pendingImportsContainer()
        }
    }
}

private struct PendingImportBanner: View {

    var onReview: (_ text: String, _ clear: @escaping () -> Void) -> Void

    @Query(sort: \PendingImport.createdAt) private var pending: [PendingImport]
    @Environment(\.modelContext) private var pendingContext

    var body: some View {
        if !pending.isEmpty {
            Button {
                let text = pending.map(\.rawText).joined(separator: "\n")
                onReview(text, clearBacklog)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .foregroundStyle(Color.accentColor)
                    Text(
                        "\(pending.count) item\(pending.count == 1 ? "" : "s") shared from another app"
                        + " — Review"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 6)
        }
    }

    private func clearBacklog() {
        for item in pending { pendingContext.delete(item) }
        try? pendingContext.save()
    }
}
