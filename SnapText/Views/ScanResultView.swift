import SwiftUI

struct ScanResultView: View {
    let result: ScanResult
    let onCopy: (String) -> Void
    let onDismiss: () -> Void

    @State private var showCopiedToast = false
    @State private var showEntitySheet: DetectedEntity.EntityType?
    @State private var showFullscreenImage = false

    private func entitiesOfType(_ type: DetectedEntity.EntityType) -> [DetectedEntity] {
        result.entities.filter { $0.type == type }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Hero image with gradient overlay
                    ZStack(alignment: .bottom) {
                        Image(uiImage: result.image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .onTapGesture { showFullscreenImage = true }

                        // Gradient fade at bottom
                        LinearGradient(
                            colors: [.clear, Color(.systemBackground)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 60)

                        // Expand indicator
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

                    VStack(spacing: 20) {
                        // Smart entities
                        if !result.entities.isEmpty {
                            smartEntitiesSection
                                .padding(.top, 8)
                        }

                        // Extracted text
                        extractedTextSection

                        // Action buttons
                        actionButtons
                    }
                    .padding(.bottom, 20)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Extracted Text")
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
                EntityListSheet(title: sheetTitle(for: type), entities: entitiesOfType(type))
                    .presentationDetents([.medium, .large])
            }
            .fullScreenCover(isPresented: $showFullscreenImage) {
                FullscreenImageViewer(image: result.image)
            }
        }
    }

    // MARK: - Smart Entities

    private var entityCategories: [(type: DetectedEntity.EntityType, icon: String, label: String, color: Color, count: Int)] {
        EntityCategoryHelper.categories(from: result.entities)
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
                            handleCategoryTap(category.type)
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

    // MARK: - Extracted Text

    private var extractedTextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundStyle(.blue)
                Text("Full Text")
                    .font(.headline)
            }
            .padding(.horizontal)

            SelectableTextView(text: result.text)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                .padding(4)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
                .padding(.horizontal)
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    onCopy(result.text)
                    showCopiedFeedback()
                } label: {
                    Label("Copy All", systemImage: "doc.on.doc.fill")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                ShareLink(item: result.text) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            TranslateButton(text: result.text)
        }
        .padding(.horizontal)
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

    // MARK: - Helpers

    private func showCopiedFeedback() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(duration: 0.3)) { showCopiedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(duration: 0.3)) { showCopiedToast = false }
        }
    }

    private func handleCategoryTap(_ type: DetectedEntity.EntityType) {
        showEntitySheet = type
    }

    private func sheetTitle(for type: DetectedEntity.EntityType) -> String {
        EntityCategoryHelper.sheetTitle(for: type)
    }
}
