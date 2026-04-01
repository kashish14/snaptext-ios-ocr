import SwiftUI

struct ScanResultView: View {
    let result: ScanResult
    let onCopy: (String) -> Void
    let onDismiss: () -> Void

    @State private var showCopiedToast = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Source image thumbnail
                    Image(uiImage: result.image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 4)
                        .padding(.horizontal)

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
        }
    }

    // MARK: - Smart Entities

    private var smartEntitiesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Detected")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(result.entities) { entity in
                        entityChip(entity)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func entityChip(_ entity: DetectedEntity) -> some View {
        Button {
            handleEntityTap(entity)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: entity.iconName)
                    .font(.caption)
                Text(entity.actionLabel)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(entity.type == .otp ? Color.orange : Color.accentColor)
            .foregroundStyle(.white)
            .clipShape(Capsule())
        }
    }

    // MARK: - Extracted Text

    private var extractedTextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Full Text")
                .font(.headline)
                .padding(.horizontal)

            Text(result.text)
                .font(.body)
                .textSelection(.enabled)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        HStack(spacing: 16) {
            // Copy All
            Button {
                onCopy(result.text)
                showCopiedFeedback()
            } label: {
                Label("Copy All", systemImage: "doc.on.doc.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            // Share
            ShareLink(item: result.text) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
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

    private func handleEntityTap(_ entity: DetectedEntity) {
        switch entity.type {
        case .otp:
            onCopy(entity.value)
            showCopiedFeedback()
        case .phoneNumber:
            if let url = URL(string: "tel:\(entity.value.filter { $0.isNumber || $0 == "+" })") {
                UIApplication.shared.open(url)
            }
        case .url:
            if let url = URL(string: entity.value) {
                UIApplication.shared.open(url)
            }
        case .email:
            if let url = URL(string: "mailto:\(entity.value)") {
                UIApplication.shared.open(url)
            }
        case .address:
            let query = entity.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let url = URL(string: "maps://?q=\(query)") {
                UIApplication.shared.open(url)
            }
        }
    }
}
