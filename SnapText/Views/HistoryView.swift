import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScanHistoryItem.timestamp, order: .reverse) private var historyItems: [ScanHistoryItem]
    @State private var selectedItem: ScanHistoryItem?
    @State private var searchText = ""

    private var filteredItems: [ScanHistoryItem] {
        guard !searchText.isEmpty else { return historyItems }
        let query = searchText.lowercased()
        return historyItems.filter { item in
            item.text.lowercased().contains(query) ||
            item.entities.contains { $0.value.lowercased().contains(query) }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if historyItems.isEmpty {
                    ContentUnavailableView(
                        "No Scans Yet",
                        systemImage: "clock",
                        description: Text("Your scan history will appear here.")
                    )
                } else if filteredItems.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        ForEach(filteredItems) { item in
                            HistoryRow(item: item)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedItem = item }
                        }
                        .onDelete(perform: deleteItems)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search scans...")
            .toolbar {
                if !historyItems.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        EditButton()
                    }
                }
            }
            .sheet(item: $selectedItem) { item in
                HistoryDetailView(item: item)
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredItems[index])
        }
        try? modelContext.save()
    }
}

// MARK: - History Row

private struct HistoryRow: View {
    let item: ScanHistoryItem

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let image = item.thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.tertiarySystemBackground))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                // Text preview
                Text(item.textPreview)
                    .font(.subheadline)
                    .lineLimit(2)

                // Timestamp
                Text(item.timestamp.timeAgoDisplay())
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                // Smart entity badges
                if !item.entities.isEmpty {
                    entityBadges
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var entityBadges: some View {
        HStack(spacing: 6) {
            ForEach(entitySummary, id: \.label) { badge in
                HStack(spacing: 3) {
                    Image(systemName: badge.icon)
                    Text(badge.label)
                }
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(badge.color.opacity(0.15))
                .foregroundStyle(badge.color)
                .clipShape(Capsule())
            }
        }
    }

    private var entitySummary: [EntityBadge] {
        let categories = EntityCategoryHelper.categories(from: item.entities)
        // Show top 4 badges to avoid overflow in the row
        return categories.prefix(4).map { cat in
            EntityBadge(icon: cat.icon, label: "\(cat.count) \(cat.label)", color: cat.color)
        }
    }
}

private struct EntityBadge: Hashable {
    let icon: String
    let label: String
    let color: Color
}

// MARK: - History Detail View

private struct HistoryDetailView: View {
    let item: ScanHistoryItem
    @Environment(\.dismiss) private var dismiss
    @State private var showCopiedToast = false
    @State private var showEntitySheet: DetectedEntity.EntityType?
    @State private var showFullscreenImage = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Thumbnail (tap to view fullscreen)
                    if let image = item.thumbnailImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(radius: 4)
                            .padding(.horizontal)
                            .onTapGesture { showFullscreenImage = true }
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.caption)
                                    .padding(6)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                                    .padding(.horizontal, 24)
                                    .padding(.bottom, 8)
                            }
                    }

                    // Smart entities
                    if !item.entities.isEmpty {
                        smartEntitiesSection
                    }

                    // Full text
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Full Text")
                            .font(.headline)
                            .padding(.horizontal)

                        SelectableTextView(text: item.text)
                            .frame(maxWidth: .infinity)
                            .fixedSize(horizontal: false, vertical: true)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                    }

                    // Actions
                    HStack(spacing: 16) {
                        Button {
                            ClipboardManager.shared.copy(item.text, source: "History")
                            showCopiedFeedback()
                        } label: {
                            Label("Copy All", systemImage: "doc.on.doc.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        ShareLink(item: item.text) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    .padding(.horizontal)

                    // Translate
                    TranslateButton(text: item.text)
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Scan Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay(alignment: .bottom) {
                if showCopiedToast {
                    copiedToast
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .sheet(item: $showEntitySheet) { type in
                EntityListSheet(
                    title: EntityCategoryHelper.sheetTitle(for: type),
                    entities: item.entities.filter { $0.type == type }
                )
                .presentationDetents([.medium, .large])
            }
            .fullScreenCover(isPresented: $showFullscreenImage) {
                if let image = item.thumbnailImage {
                    FullscreenImageViewer(image: image)
                }
            }
        }
    }

    private var entityCategories: [(type: DetectedEntity.EntityType, icon: String, label: String, color: Color, count: Int)] {
        EntityCategoryHelper.categories(from: item.entities)
    }

    private var smartEntitiesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Detected")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(entityCategories, id: \.type) { category in
                        Button {
                            showEntitySheet = category.type
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: category.icon)
                                    .font(.caption)
                                Text("\(category.count) \(category.label)")
                                    .font(.caption.weight(.medium))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(category.color)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var copiedToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
            Text("Copied to clipboard!")
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.green)
        .clipShape(Capsule())
        .shadow(radius: 8)
        .padding(.bottom, 30)
    }

    private func showCopiedFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        withAnimation(.easeInOut(duration: 0.3)) { showCopiedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.3)) { showCopiedToast = false }
        }
    }

}

// MARK: - Time Ago Formatter

extension Date {
    func timeAgoDisplay() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: self, to: now)

        if let years = components.year, years > 0 {
            return years == 1 ? "1 year ago" : "\(years) years ago"
        }
        if let months = components.month, months > 0 {
            return months == 1 ? "1 month ago" : "\(months) months ago"
        }
        if let days = components.day, days > 0 {
            return days == 1 ? "1 day ago" : "\(days) days ago"
        }
        if let hours = components.hour, hours > 0 {
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        }
        if let minutes = components.minute, minutes > 0 {
            return minutes == 1 ? "1 min ago" : "\(minutes) mins ago"
        }
        return "Just now"
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: ScanHistoryItem.self, inMemory: true)
}
