import SwiftUI
import SwiftData

struct BatchScanView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var pages: [(image: UIImage, text: String)] = []
    @State private var showCamera = false
    @State private var showGallery = false
    @State private var isProcessing = false
    @State private var showResult = false
    @State private var combinedText = ""
    @State private var applyBW = false

    private let ocrService = OCRService()
    private let smartDetector = SmartDetector()

    var body: some View {
        VStack(spacing: 0) {
            if pages.isEmpty {
                Spacer()
                VStack(spacing: 24) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 64))
                        .foregroundStyle(.tint)

                    VStack(spacing: 8) {
                        Text("Batch Scan")
                            .font(.title2.bold())
                        Text("Scan multiple pages, combine into one")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            } else {
                // Pages list
                List {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        HStack(spacing: 12) {
                            Image(uiImage: page.image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Page \(index + 1)")
                                    .font(.subheadline.bold())
                                Text(page.text.prefix(80) + (page.text.count > 80 ? "..." : ""))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .onDelete { offsets in
                        pages.remove(atOffsets: offsets)
                    }
                }
                .listStyle(.plain)
            }

            if isProcessing {
                ProgressView("Extracting text...")
                    .padding()
            }

            // Bottom actions
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Camera", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button {
                        showGallery = true
                    } label: {
                        Label("Gallery", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                if !pages.isEmpty {
                    Button {
                        combineAndShow()
                    } label: {
                        Label("Combine All (\(pages.count) pages)", systemImage: "doc.text")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { image in
                Task { await addPage(image) }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showGallery) {
            MultiImagePicker { images in
                Task {
                    for image in images {
                        await addPage(image)
                    }
                }
            }
        }
        .sheet(isPresented: $showResult) {
            batchResultView
        }
    }

    private func addPage(_ image: UIImage) async {
        isProcessing = true
        do {
            let text = try await ocrService.recognizeText(in: image, mode: .accurate)
            await MainActor.run {
                pages.append((image: image, text: text))
                isProcessing = false
            }
        } catch {
            await MainActor.run { isProcessing = false }
        }
    }

    private func combineAndShow() {
        combinedText = pages.enumerated().map { index, page in
            "--- Page \(index + 1) ---\n\(page.text)"
        }.joined(separator: "\n\n")
        showResult = true

        // Save to history
        let entities = smartDetector.detect(in: combinedText)
        let item = ScanHistoryItem(
            text: combinedText,
            image: pages.first?.image,
            entities: entities
        )
        modelContext.insert(item)
        try? modelContext.save()
    }

    private var batchResultView: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("\(pages.count) pages combined")
                        .font(.headline)

                    SelectableTextView(text: combinedText)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)

                    HStack(spacing: 16) {
                        Button {
                            ClipboardManager.shared.copy(combinedText, source: "Batch")
                        } label: {
                            Label("Copy All", systemImage: "doc.on.doc.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        ShareLink(item: combinedText) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    .padding(.horizontal)

                    Toggle("Black & White PDF", isOn: $applyBW)
                        .padding(.horizontal)

                    // Export as PDF
                    let pdfImages = applyBW ? pages.map { $0.image.blackAndWhite() } : pages.map { $0.image }
                    let pdfData = PDFService.renderPDF(from: pdfImages)
                    ShareLink(item: PDFTransferable(data: pdfData), preview: SharePreview("Batch Scan", image: Image(systemName: "doc.fill"))) {
                        Label("Export PDF", systemImage: "arrow.down.doc.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .padding(.horizontal)

                    TranslateButton(text: combinedText)
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Batch Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showResult = false }
                }
            }
        }
    }
}
