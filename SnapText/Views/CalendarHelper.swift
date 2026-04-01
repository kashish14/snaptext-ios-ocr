import EventKit
import EventKitUI
import SwiftUI

/// Wraps EKEventEditViewController to present a pre-filled "Add to Calendar" sheet.
struct CalendarEventEditor: UIViewControllerRepresentable {
    let title: String
    let date: Date?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.title = title
        if let date {
            event.startDate = date
            event.endDate = date.addingTimeInterval(3600) // default 1 hour
        } else {
            event.startDate = Date()
            event.endDate = Date().addingTimeInterval(3600)
        }

        let editor = EKEventEditViewController()
        editor.eventStore = store
        editor.event = event
        editor.editViewDelegate = context.coordinator
        return editor
    }

    func updateUIViewController(_ uiViewController: EKEventEditViewController, context: Context) {}

    class Coordinator: NSObject, EKEventEditViewDelegate {
        let dismiss: DismissAction

        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            dismiss()
        }
    }
}

/// Handles calendar permission and event creation
@MainActor
final class CalendarManager {
    static let shared = CalendarManager()
    private let store = EKEventStore()

    func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    /// Parses date from the entity's secondaryValue (ISO8601) or tries natural language
    func parseDate(from entity: DetectedEntity) -> Date? {
        // Try ISO8601 from secondaryValue first
        if let iso = entity.secondaryValue {
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: iso) {
                return date
            }
        }

        // Try natural language parsing via DataDetector
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let range = NSRange(entity.value.startIndex..., in: entity.value)
            if let match = detector.firstMatch(in: entity.value, options: [], range: range) {
                return match.date
            }
        }

        return nil
    }
}
