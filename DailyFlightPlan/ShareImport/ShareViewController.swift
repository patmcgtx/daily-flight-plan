//
//  ShareViewController.swift
//  ShareImport
//
import UIKit
import Social
import UniformTypeIdentifiers
import SwiftData

class ShareViewController: SLComposeServiceViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Add to Daily Flight Plan"
        Task { await prefillFromExtensionContext() }
    }

    override func isContentValid() -> Bool {
        !contentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    override func didSelectPost() {
        let text = contentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            save(rawText: text)
        }
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    override func configurationItems() -> [Any]! {
        []
    }

    // MARK: - Prefill

    /// Pulls shared text into the compose text view before the user sees it, so the common case
    /// (sharing a selection or a markdown file) needs no typing — just a glance and Post.
    private func prefillFromExtensionContext() async {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return }

        var collected: [String] = []
        for item in items {
            if let attributed = item.attributedContentText?.string,
               !attributed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                collected.append(attributed)
            }
            for provider in item.attachments ?? [] {
                if let text = await extractText(from: provider) {
                    collected.append(text)
                }
            }
        }

        let combined = collected.joined(separator: "\n")
        guard !combined.isEmpty else { return }
        await MainActor.run { textView.text = combined }
    }

    private func extractText(from provider: NSItemProvider) async -> String? {
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            if let data = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) {
                if let string = data as? String { return string }
                if let data = data as? Data { return String(data: data, encoding: .utf8) }
            }
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            if let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
                if url.isFileURL { return try? String(contentsOf: url, encoding: .utf8) }
                return url.absoluteString
            }
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
            if let data = try? await provider.loadItem(forTypeIdentifier: UTType.text.identifier) {
                if let string = data as? String { return string }
                if let data = data as? Data { return String(data: data, encoding: .utf8) }
            }
        }
        return nil
    }

    // MARK: - Save

    private func save(rawText: String) {
        do {
            let container = try ModelContainer.pendingImportsContainer()
            let context = ModelContext(container)
            context.insert(PendingImport(rawText: rawText))
            try context.save()
        } catch {
            print("ShareImport: failed to save pending import: \(error)")
        }
    }
}
