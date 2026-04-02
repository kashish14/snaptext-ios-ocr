import SwiftUI

struct IntelligentResultView: View {
    let result: ScanResult
    let onDismiss: () -> Void

    @State private var rankedResult: ActionPriorityEngine.RankedResult?
    @State private var showCopiedToast = false
    @State private var showDoMore = false
    @State private var showEntitySheet: DetectedEntity.EntityType?
    @State private var showFullscreenImage = false
    @State private var showToolView: AnyView?
    @State private var showToolSheet = false

    private let engine = ActionPriorityEngine()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Hero image (only if we have a real image)
                    if result.image.size.width > 0 {
                        heroImage
                    }

                    VStack(spacing: 20) {
                        // A. Understood — entity chips with direct actions
                        if !result.entities.isEmpty {
                            understoodSection
                        }

                        // B. Extracted — clean text
                        extractedTextSection

                        // C. Quick Actions — top 3–5 scored
                        if let ranked = rankedResult, !ranked.quickActions.isEmpty {
                            quickActionsSection(ranked.quickActions)
                        }

                        // D. Do More button
                        doMoreButton
                    }
                    .padding(.bottom, 24)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { onDismiss() }
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
                    entities: result.entities.filter { $0.type == type }
                )
                .presentationDetents([.medium, .large])
            }
            .fullScreenCover(isPresented: $showFullscreenImage) {
                FullscreenImageViewer(image: result.image)
            }
            .sheet(isPresented: $showDoMore) {
                doMoreSheet
            }
            .sheet(isPresented: $showToolSheet) {
                if let toolView = showToolView {
                    NavigationStack {
                        toolView
                            .environment(\.toolContext, ToolContext(
                                image: result.image.size.width > 0 ? result.image : nil,
                                text: result.text
                            ))
                            .toolbar {
                                ToolbarItem(placement: .topBarLeading) {
                                    Button("Close") { showToolSheet = false }
                                }
                            }
                    }
                }
            }
            .onAppear {
                rankedResult = engine.rank(
                    text: result.text,
                    image: result.image.size.width > 0 ? result.image : nil,
                    entities: result.entities
                )
            }
        }
    }

    // MARK: - A. Hero Image

    private var heroImage: some View {
        ZStack(alignment: .bottom) {
            Image(uiImage: result.image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 200)
                .frame(maxWidth: .infinity)
                .clipped()
                .onTapGesture { showFullscreenImage = true }

            LinearGradient(
                colors: [.clear, Color(.systemGroupedBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 50)

            HStack {
                Spacer()
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption2.bold())
                    .padding(6)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .padding(10)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - A. Understood (Entities)

    private var understoodSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.orange)
                Text("Understood")
                    .font(.headline)
            }
            .padding(.horizontal)

            // Entity action chips — inline, 1-tap
            if let ranked = rankedResult, !ranked.entityActions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ranked.entityActions) { action in
                            Button {
                                action.directAction?()
                                UserBehaviorTracker.shared.recordAction(action.id)
                                if action.id.hasPrefix("entity_otp") {
                                    showCopiedFeedback()
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: action.icon)
                                        .font(.caption2.weight(.semibold))
                                    Text(action.title)
                                        .font(.caption.weight(.medium))
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(action.color.opacity(0.15))
                                .foregroundStyle(action.color)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(action.color.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }

            // Category badges (tap to see full list)
            let categories = EntityCategoryHelper.categories(from: result.entities)
            if !categories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(categories, id: \.type) { cat in
                            Button {
                                showEntitySheet = cat.type
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: cat.icon)
                                        .font(.caption2)
                                    Text("\(cat.count)")
                                        .font(.caption2.bold())
                                    Text(cat.label)
                                        .font(.caption2)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.tertiarySystemGroupedBackground))
                                .foregroundStyle(.secondary)
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - B. Extracted Text

    private var extractedTextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundStyle(.blue)
                Text("Extracted")
                    .font(.headline)
                Spacer()
                Button {
                    ClipboardManager.shared.copy(result.text, source: "Scan")
                    showCopiedFeedback()
                } label: {
                    Label("Copy All", systemImage: "doc.on.doc")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            .padding(.horizontal)

            SelectableTextView(text: result.text)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                .padding(4)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.03), radius: 3, y: 2)
                .padding(.horizontal)
        }
    }

    // MARK: - C. Quick Actions

    private func quickActionsSection(_ actions: [QuickAction]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.yellow)
                Text("Quick Actions")
                    .font(.headline)
            }
            .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(actions) { action in
                    quickActionRow(action)
                }
            }
            .padding(.horizontal)
        }
    }

    private func quickActionRow(_ action: QuickAction) -> some View {
        Button {
            handleAction(action)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: action.icon)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(action.color.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 9))

                Text(action.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: action.isDirectAction ? "checkmark.circle" : "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - D. Do More

    private var doMoreButton: some View {
        Button {
            showDoMore = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.grid.2x2")
                    .font(.subheadline)
                Text("All Tools")
                    .font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.bordered)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var doMoreSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    doMoreGroup("Document", category: .document)
                    doMoreGroup("Image", category: .image)
                    doMoreGroup("Text", category: .text)
                    doMoreGroup("Utilities", category: .utility)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("All Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showDoMore = false }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func doMoreGroup(_ title: String, category: QuickAction.ActionCategory) -> some View {
        let actions = allActionsForCategory(category)
        guard !actions.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.headline)
                    .padding(.horizontal)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(actions) { action in
                        Button {
                            showDoMore = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                handleAction(action)
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: action.icon)
                                    .font(.title3.weight(.medium))
                                    .foregroundStyle(.white)
                                    .frame(width: 42, height: 42)
                                    .background(action.color.gradient)
                                    .clipShape(RoundedRectangle(cornerRadius: 11))

                                Text(action.title)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        )
    }

    private func allActionsForCategory(_ category: QuickAction.ActionCategory) -> [QuickAction] {
        guard let ranked = rankedResult else { return [] }
        let all = ranked.quickActions + ranked.doMoreActions
        return all.filter { $0.category == category && $0.toolDestination != nil }
    }

    // MARK: - Action Handling

    private func handleAction(_ action: QuickAction) {
        UserBehaviorTracker.shared.recordAction(action.id)

        if let directAction = action.directAction {
            directAction()
            if action.id == "copy_text" {
                showCopiedFeedback()
            }
        } else if let destination = action.toolDestination {
            showToolView = destination()
            showToolSheet = true
        }
    }

    // MARK: - Toast

    private var copiedToast: some View {
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
    }

    private func showCopiedFeedback() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(duration: 0.3)) { showCopiedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(duration: 0.3)) { showCopiedToast = false }
        }
    }
}
