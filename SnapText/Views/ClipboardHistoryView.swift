import SwiftUI
import SwiftData

struct ClipboardHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClipboardItem.timestamp, order: .reverse) private var items: [ClipboardItem]
    @State private var copiedId: UUID?
    @State private var searchText = ""

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
                                clipboardCard(item)
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
                        Button("Clear All", role: .destructive) {
                            withAnimation {
                                for item in items { modelContext.delete(item) }
                                try? modelContext.save()
                            }
                        }
                        .font(.caption)
                    }
                }
            }
        }
    }

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

    private func clipboardCard(_ item: ClipboardItem) -> some View {
        Button {
            UIPasteboard.general.string = item.text
            copiedId = item.id
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { if copiedId == item.id { copiedId = nil } }
            }
        } label: {
            HStack(spacing: 12) {
                // Source icon
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
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 3, y: 2)
        }
        .buttonStyle(.plain)
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
        default: return "doc.on.doc"
        }
    }
}
