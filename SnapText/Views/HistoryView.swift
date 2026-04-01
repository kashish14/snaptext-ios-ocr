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
                    emptyState
                } else if filteredItems.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredItems) { item in
                                HistoryCard(item: item)
                                    .onTapGesture { selectedItem = item }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .background(Color(.systemGroupedBackground))
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

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.08))
                    .frame(width: 120, height: 120)
                Image(systemName: "clock")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                Text("No Scans Yet")
                    .font(.title3.bold())
                Text("Your scan history will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredItems[index])
        }
        try? modelContext.save()
    }
}

// MARK: - History Card

private struct HistoryCard: View {
    let item: ScanHistoryItem

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let image = item.thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.08))
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.blue.opacity(0.5))
                    }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(item.textPreview)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(item.timestamp.timeAgoDisplay())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                // Entity badges
                if !item.entities.isEmpty {
                    entityBadges
                }
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.quaternary)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 3, y: 2)
    }

    private var entityBadges: some View {
        HStack(spacing: 4) {
            ForEach(entitySummary, id: \.label) { badge in
                HStack(spacing: 3) {
                    Image(systemName: badge.icon)
                    Text(badge.label)
                }
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(badge.color.opacity(0.1))
                .foregroundStyle(badge.color)
                .clipShape(Capsule())
            }
        }
    }

    private var entitySummary: [EntityBadge] {
        let categories = EntityCategoryHelper.categories(from: item.entities)
        return categories.prefix(3).map { cat in
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
                VStack(spacing: 0) {
                    // Hero image
                    if let image = item.thumbnailImage {
                        ZStack(alignment: .bottom) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 220)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .onTapGesture { showFullscreenImage = true }

                            LinearGradient(
                                colors: [.clear, Color(.systemGroupedBackground)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 60)

                            HStack {
                                Spacer()
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.caption2.bold())
                                    .padding(6)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                                    .padding(12)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }

                    VStack(spacing: 20) {
                        // Smart entities
                        if !item.entities.isEmpty {
                            smartEntitiesSection
                                .padding(.top, 8)
                        }

                        // Full text
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundStyle(.blue)
                                Text("Full Text")
                                    .font(.headline)
                            }
                            .padding(.horizontal)

                            SelectableTextView(text: item.text)
                                .frame(maxWidth: .infinity)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(4)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
                                .padding(.horizontal)
                        }

                        // Actions
                        VStack(spacing: 10) {
                            HStack(spacing: 12) {
                                Button {
                                    ClipboardManager.shared.copy(item.text, source: "History")
                                    showCopiedFeedback()
                                } label: {
                                    Label("Copy All", systemImage: "doc.on.doc.fill")
                                        .font(.body.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                }
                                .buttonStyle(.borderedProminent)
                                .clipShape(RoundedRectangle(cornerRadius: 14))

                                ShareLink(item: item.text) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                        .font(.body.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                }
                                .buttonStyle(.bordered)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }

                            TranslateButton(text: item.text)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 20)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Scan Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay(alignment: .bottom) {
                if showCopiedToast {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Copied!")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(Color.green.gradient)
                            .shadow(color: .green.opacity(0.3), radius: 8, y: 4)
                    )
                    .padding(.bottom, 30)
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
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.orange)
                Text("Detected")
                    .font(.headline)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(entityCategories, id: \.type) { category in
                        Button {
                            showEntitySheet = category.type
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: category.icon)
                                    .font(.caption2)
                                Text("\(category.count)")
                                    .font(.caption.bold())
                                Text(category.label)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(category.color.opacity(0.15))
                            .foregroundStyle(category.color)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(category.color.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func showCopiedFeedback() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(duration: 0.3)) { showCopiedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(duration: 0.3)) { showCopiedToast = false }
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
