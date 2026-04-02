import SwiftUI

/// Context passed to tools when opened from the result screen.
/// Tools read this to auto-populate with scanned data.
struct ToolContext {
    let image: UIImage?
    let text: String?

    static let empty = ToolContext(image: nil, text: nil)

    var hasImage: Bool { image != nil && (image?.size.width ?? 0) > 0 }
    var hasText: Bool { text != nil && !(text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) }
}

// MARK: - Environment Key

private struct ToolContextKey: EnvironmentKey {
    static let defaultValue: ToolContext = .empty
}

extension EnvironmentValues {
    var toolContext: ToolContext {
        get { self[ToolContextKey.self] }
        set { self[ToolContextKey.self] = newValue }
    }
}
