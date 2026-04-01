import UIKit
import SwiftData

@MainActor
final class ClipboardManager {
    static let shared = ClipboardManager()

    private init() {}

    var modelContext: ModelContext?

    /// Copy text to system clipboard AND save to in-app clipboard history.
    func copy(_ text: String, source: String? = nil) {
        UIPasteboard.general.string = text
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        saveToHistory(text, source: source)
    }

    private func saveToHistory(_ text: String, source: String?) {
        guard let modelContext else { return }
        let item = ClipboardItem(text: text, sourceLabel: source)
        modelContext.insert(item)

        // Cap at 50 items
        let fetchDescriptor = FetchDescriptor<ClipboardItem>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        if let all = try? modelContext.fetch(fetchDescriptor), all.count > 50 {
            for old in all.dropFirst(50) {
                modelContext.delete(old)
            }
        }
        try? modelContext.save()
    }
}
