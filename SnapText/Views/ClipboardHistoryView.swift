import SwiftUI
import SwiftData

struct ClipboardHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClipboardItem.timestamp, order: .reverse) private var items: [ClipboardItem]
    @State private var copiedId: UUID?
    @State private var searchText = ""
    @State private var confirmClear = false

    private let detector = SmartDetector()

    private var filteredItems: [ClipboardItem] {
        guard !searchText.isEmpty else { return items }
        let query = searchText.lowercased()
        return items.filter { $0.text.lowercased().contains(query) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    emptyState
                } else if filteredItems.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredItems) { item in
                                smartClipboardCard(item)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Clipboard")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search clipboard...")
            .toolbar {
                if !items.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear All", role: .destructive) { confirmClear = true }
                            .confirmationDialog("Clear clipboard history?", isPresented: $confirmClear, titleVisibility: .visible) {
                                Button("Clear All", role: .destructive) {
                                    withAnimation {
                                        for item in items { modelContext.delete(item) }
                                        try? modelContext.save()
                                    }
                                }
                            } message: {
                                Text("This removes all \(items.count) saved items.")
                            }
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.08))
                    .frame(width: 120, height: 120)
                Image(systemName: "clipboard")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                Text("No Clipboard History")
                    .font(.title3.bold())
                Text("Items you copy from scans will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Smart Card

    private func smartClipboardCard(_ item: ClipboardItem) -> some View {
        let entities = detector.detect(in: item.text)
        let suggestions = buildSuggestions(for: item, entities: entities)

        return VStack(alignment: .leading, spacing: 0) {
            // Main row — tap to copy
            Button {
                UIPasteboard.general.string = item.text
                copiedId = item.id
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { if copiedId == item.id { copiedId = nil } }
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.accentColor.opacity(0.1))
                            .frame(width: 40, height: 40)
                        Image(systemName: sourceIcon(for: item.sourceLabel))
                            .font(.body)
                            .foregroundStyle(Color.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.preview)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: 6) {
                            Text(item.timestamp.timeAgoDisplay())
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            if let source = item.sourceLabel {
                                Text(source)
                                    .font(.caption2.weight(.medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.1))
                                    .foregroundStyle(Color.accentColor)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: copiedId == item.id ? "checkmark.circle.fill" : "doc.on.doc")
                        .font(.title3)
                        .foregroundStyle(copiedId == item.id ? Color.green : Color(.tertiaryLabel))
                        .contentTransition(.symbolEffect(.replace))
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            // Smart suggestions row
            if !suggestions.isEmpty {
                Divider()
                    .padding(.horizontal, 14)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(suggestions, id: \.label) { suggestion in
                            Button {
                                suggestion.action()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: suggestion.icon)
                                        .font(.caption2)
                                    Text(suggestion.label)
                                        .font(.caption2.weight(.medium))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(suggestion.color.opacity(0.12))
                                .foregroundStyle(suggestion.color)
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 3, y: 2)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                withAnimation {
                    modelContext.delete(item)
                    try? modelContext.save()
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Build Suggestions

    private struct Suggestion {
        let icon: String
        let label: String
        let color: Color
        let action: () -> Void
    }

    private func buildSuggestions(for item: ClipboardItem, entities: [DetectedEntity]) -> [Suggestion] {
        var suggestions: [Suggestion] = []

        // Check for entity-based suggestions (max 2)
        for entity in entities {
            guard suggestions.count < 2 else { break }

            switch entity.type {
            case .phoneNumber:
                let num = entity.value.filter { $0.isNumber || $0 == "+" }
                suggestions.append(Suggestion(
                    icon: "phone.fill",
                    label: "Call",
                    color: .green,
                    action: {
                        if let url = URL(string: "tel:\(num)") {
                            UIApplication.shared.open(url)
                        }
                    }
                ))
            case .email:
                suggestions.append(Suggestion(
                    icon: "envelope.fill",
                    label: "Email",
                    color: .purple,
                    action: {
                        if let url = URL(string: "mailto:\(entity.value)") {
                            UIApplication.shared.open(url)
                        }
                    }
                ))
            case .url:
                suggestions.append(Suggestion(
                    icon: "safari.fill",
                    label: "Open",
                    color: .blue,
                    action: {
                        if let url = URL(string: entity.value) {
                            UIApplication.shared.open(url)
                        }
                    }
                ))
            case .address:
                suggestions.append(Suggestion(
                    icon: "map.fill",
                    label: "Maps",
                    color: .blue,
                    action: {
                        let encoded = entity.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                        if let url = URL(string: "maps://?q=\(encoded)") {
                            UIApplication.shared.open(url)
                        }
                    }
                ))
            case .upiId:
                suggestions.append(Suggestion(
                    icon: "indianrupeesign.circle.fill",
                    label: "Pay",
                    color: .green,
                    action: {
                        if let url = URL(string: "upi://pay?pa=\(entity.value)") {
                            UIApplication.shared.open(url)
                        }
                    }
                ))
            default:
                break
            }
        }

        // If no entity suggestions, add a share suggestion for longer text
        if suggestions.isEmpty && item.text.count > 20 {
            suggestions.append(Suggestion(
                icon: "square.and.arrow.up",
                label: "Share",
                color: .blue,
                action: {
                    let av = UIActivityViewController(activityItems: [item.text], applicationActivities: nil)
                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let root = scene.windows.first?.rootViewController {
                        root.present(av, animated: true)
                    }
                }
            ))
        }

        return suggestions
    }

    // MARK: - Helpers

    private func sourceIcon(for label: String?) -> String {
        switch label {
        case "Scan": return "doc.text.viewfinder"
        case "QR Scan": return "qrcode.viewfinder"
        case "Batch": return "doc.on.doc"
        case "History": return "clock"
        case "Detection": return "sparkles"
        case "Website": return "globe"
        case "Card": return "person.crop.rectangle"
        case "Receipt": return "receipt"
        case "Note": return "note.text"
        case "Table": return "tablecells"
        case "Tracking": return "shippingbox.fill"
        case "Summarizer": return "text.badge.checkmark"
        default: return "doc.on.doc"
        }
    }
}
