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
                VStack(spacing: 20) {
                    // Source image thumbnail (tap to view fullscreen)
                    Image(uiImage: result.image)
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

                    // Smart entities (OTPs first, then others)
                    if !result.entities.isEmpty {
                        smartEntitiesSection
                    }

                    // Extracted text
                    extractedTextSection

                    // Action buttons
                    actionButtons
                }
                .padding(.vertical)
            }
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
            Text("Detected")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(entityCategories, id: \.type) { category in
                        Button {
                            handleCategoryTap(category.type)
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

    // MARK: - Extracted Text

    private var extractedTextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Full Text")
                .font(.headline)
                .padding(.horizontal)

            SelectableTextView(text: result.text)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Button {
                    onCopy(result.text)
                    showCopiedFeedback()
                } label: {
                    Label("Copy All", systemImage: "doc.on.doc.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                ShareLink(item: result.text) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            TranslateButton(text: result.text)
        }
        .padding(.horizontal)
    }

    // MARK: - Toast

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

    // MARK: - Helpers

    private func showCopiedFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        withAnimation(.easeInOut(duration: 0.3)) {
            showCopiedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showCopiedToast = false
            }
        }
    }

    private func handleCategoryTap(_ type: DetectedEntity.EntityType) {
        showEntitySheet = type
    }

    private func sheetTitle(for type: DetectedEntity.EntityType) -> String {
        EntityCategoryHelper.sheetTitle(for: type)
    }
}
