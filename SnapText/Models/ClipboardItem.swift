import Foundation
import SwiftData

@Model
final class ClipboardItem {
    var id: UUID
    var text: String
    var timestamp: Date
    var sourceLabel: String?

    init(text: String, sourceLabel: String? = nil) {
        self.id = UUID()
        self.text = text
        self.timestamp = .now
        self.sourceLabel = sourceLabel
    }

    var preview: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 80 { return trimmed }
        return String(trimmed.prefix(80)) + "..."
    }
}
