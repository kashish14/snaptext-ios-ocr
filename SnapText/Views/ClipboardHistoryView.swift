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
                    ContentUnavailableView(
                        "No Clipboard History",
                        systemImage: "clipboard",
                        description: Text("Items you copy from scans will appear here.")
                    )
                } else if filteredItems.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        ForEach(filteredItems) { item in
                            clipboardRow(item)
                        }
                        .onDelete(perform: deleteItems)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Clipboard")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search clipboard...")
            .toolbar {
                if !items.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear All", role: .destructive) {
                            for item in items { modelContext.delete(item) }
                            try? modelContext.save()
                        }
                    }
                }
            }
        }
    }

    private func clipboardRow(_ item: ClipboardItem) -> some View {
        Button {
            UIPasteboard.general.string = item.text
            copiedId = item.id
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if copiedId == item.id { copiedId = nil }
            }
        } label: { // Re-copy only — no duplicate history entry
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.preview)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Text(item.timestamp.timeAgoDisplay())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if let source = item.sourceLabel {
                            Text(source)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundStyle(Color.accentColor)
                                .clipShape(Capsule())
                        }
                    }
                }

                Spacer()

                Image(systemName: copiedId == item.id ? "checkmark.circle.fill" : "doc.on.doc")
                    .foregroundStyle(copiedId == item.id ? .green : .secondary)
                    .font(.title3)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredItems[index])
        }
        try? modelContext.save()
    }
}
