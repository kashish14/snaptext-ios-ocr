import SwiftUI
import SwiftData

struct CaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ScanViewModel()
    @State private var showPasteAlert = false
    @Query(sort: \ScanHistoryItem.timestamp, order: .reverse, animation: .default)
    private var recentScans: [ScanHistoryItem]

    private var lastThreeScans: [ScanHistoryItem] {
        Array(recentScans.prefix(3))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(.systemBackground), Color.blue.opacity(0.04)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // Hero
                    heroSection

                    Spacer()

                    // Capture buttons
                    captureButtons

                    // Recent scans strip
                    if !lastThreeScans.isEmpty {
                        recentStrip
                    }
                }
            }
            .navigationTitle("SnapText")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.modelContext = modelContext
            }
            .fullScreenCover(isPresented: $viewModel.showCamera) {
                CameraView { image in
                    Task { await viewModel.processImage(image) }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $viewModel.showGallery) {
                ImagePicker { image in
                    Task { await viewModel.processImage(image) }
                }
            }
            .sheet(item: $viewModel.scanResult) { result in
                IntelligentResultView(
                    result: result,
                    onDismiss: { viewModel.clearResult() }
                )
            }
            .alert("Paste Text", isPresented: $showPasteAlert) {
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("No text found on clipboard.")
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.08))
                    .frame(width: 140, height: 140)

                Circle()
                    .fill(Color.blue.opacity(0.04))
                    .frame(width: 180, height: 180)

                Image(systemName: "viewfinder")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .symbolEffect(.pulse, options: .repeating.speed(0.5))
            }

            VStack(spacing: 8) {
                Text("Capture Anything")
                    .font(.title2.bold())

                Text("Photo \u{2192} Understand \u{2192} Act")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if viewModel.isProcessing {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Analyzing...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Capture Buttons

    private var captureButtons: some View {
        VStack(spacing: 12) {
            // Primary row: Camera + Gallery
            HStack(spacing: 14) {
                Button {
                    viewModel.showCamera = true
                } label: {
                    Label("Camera", systemImage: "camera.fill")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Button {
                    viewModel.showGallery = true
                } label: {
                    Label("Gallery", systemImage: "photo.on.rectangle")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.bordered)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            // Paste from clipboard
            Button {
                handlePaste()
            } label: {
                Label("Paste from Clipboard", systemImage: "clipboard")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Recent Scans

    private var recentStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(lastThreeScans) { item in
                        recentCard(item)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 12)
    }

    private func recentCard(_ item: ScanHistoryItem) -> some View {
        Button {
            // Re-open as a result
            let entities = item.entities
            let result = ScanResult(
                image: item.thumbnailImage ?? UIImage(),
                text: item.text,
                entities: entities,
                timestamp: item.timestamp
            )
            viewModel.scanResult = result
        } label: {
            HStack(spacing: 10) {
                if let img = item.thumbnailImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.08))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: "doc.text")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.textPreview)
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    Text(item.timestamp.timeAgoDisplay())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 0)
            }
            .padding(8)
            .frame(width: 180)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Paste

    private func handlePaste() {
        if let clipboardImage = UIPasteboard.general.image {
            Task { await viewModel.processImage(clipboardImage) }
        } else if let clipboardText = UIPasteboard.general.string,
                  !clipboardText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Create a text-only result (no image)
            let detector = SmartDetector()
            let entities = detector.detect(in: clipboardText)
            let result = ScanResult(
                image: UIImage(),
                text: clipboardText,
                entities: entities
            )
            viewModel.scanResult = result
        } else {
            showPasteAlert = true
        }
    }
}

#Preview {
    CaptureView()
        .modelContainer(for: [ScanHistoryItem.self, ClipboardItem.self], inMemory: true)
}
