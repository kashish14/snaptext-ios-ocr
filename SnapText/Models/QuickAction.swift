import SwiftUI

/// Represents a single action the user can take on scanned content.
struct QuickAction: Identifiable {
    let id: String
    let title: String
    let icon: String
    let color: Color
    var score: Double
    let category: ActionCategory
    /// The tool view to present, if this action opens a tool
    let toolDestination: (() -> AnyView)?
    /// Direct action (e.g., copy, call, open URL) — no navigation needed
    let directAction: (() -> Void)?

    enum ActionCategory: String, CaseIterable {
        case document = "Document"
        case image = "Image"
        case text = "Text"
        case utility = "Utilities"
    }

    var isDirectAction: Bool { directAction != nil }
}

/// Content type classification for scanned input
enum ContentType: String {
    case document       // text-heavy (long paragraphs, many lines)
    case image          // low text (few words, likely a photo)
    case structured     // structured data (JSON, code, key-value pairs)
    case receipt        // receipt or table-like content
    case mixed          // can't clearly classify
}
