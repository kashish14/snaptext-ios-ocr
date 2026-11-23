import SwiftUI
import SwiftData

struct CaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ScanViewModel()
    @State private var showPasteAlert = false
    @State private var showDirectTool: DirectTool?
    @Query(sort: \ScanHistoryItem.timestamp, order: .reverse, animation: .default)
    private var recentScans: [ScanHistoryItem]

    private var lastThreeScans: [ScanHistoryItem] {
        Array(recentScans.prefix(3))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Hero
                    heroSection

                    // Capture buttons
                    captureButtons

                    // Quick tools (no scan needed)
                    quickToolsSection

                    // Recent scans strip
                    if !lastThreeScans.isEmpty {
                        recentStrip
                    }
                }
                .padding(.bottom, 16)
            }
            .background(
                LinearGradient(
                    colors: [Color(.systemBackground), Color.blue.opacity(0.04)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("SnapText")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.modelContext = modelContext
            }
            .fullScreenCover(isPresented: $viewModel.showCamera) {
                LiveCameraView { image in
                    Task { await viewModel.processImage(image) }
                }
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
            .sheet(item: $showDirectTool) { tool in
                NavigationStack {
                    tool.view
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Close") { showDirectTool = nil }
                            }
                        }
                }
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
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.08))
                    .frame(width: 110, height: 110)

                Circle()
                    .fill(Color.blue.opacity(0.04))
                    .frame(width: 145, height: 145)

                Image(systemName: "viewfinder")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .symbolEffect(.pulse, options: .repeating.speed(0.5))
            }

            VStack(spacing: 6) {
                Text("Capture Anything")
                    .font(.title3.bold())

                Text("Photo \u{2192} Understand \u{2192} Act")
                    .font(.caption)
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
        .padding(.top, 16)
    }

    // MARK: - Capture Buttons

    private var captureButtons: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    viewModel.showCamera = true
                } label: {
                    Label("Camera", systemImage: "camera.fill")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Button {
                    viewModel.showGallery = true
                } label: {
                    Label("Gallery", systemImage: "photo.on.rectangle")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Button {
                handlePaste()
            } label: {
                Label("Paste from Clipboard", systemImage: "clipboard")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Quick Tools (no scan required)

    private var quickToolsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Tools")
                .font(.headline)
                .padding(.horizontal, 24)

            // Image tools row
            VStack(alignment: .leading, spacing: 8) {
                toolCategoryLabel("Image", icon: "photo", color: .blue)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        directToolChip("Remove BG", icon: "person.and.background.dotted", color: .pink, tool: .removeBG)
                        directToolChip("Compress", icon: "arrow.down.right.and.arrow.up.left", color: .blue, tool: .compress)
                        directToolChip("Resize", icon: "arrow.up.left.and.arrow.down.right", color: .cyan, tool: .imageResize)
                        directToolChip("Passport", icon: "person.crop.rectangle", color: .purple, tool: .passport)
                        directToolChip("Watermark", icon: "textformat.abc.dottedunderline", color: .orange, tool: .watermark)
                        directToolChip("Color Pick", icon: "eyedropper", color: .pink, tool: .colorPicker)
                        directToolChip("To PDF", icon: "doc.fill", color: .red, tool: .imageToPDF)
                    }
                    .padding(.horizontal, 20)
                }
            }

            // Scan & Utility row
            VStack(alignment: .leading, spacing: 8) {
                toolCategoryLabel("Scan & More", icon: "viewfinder", color: .orange)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        directToolChip("Handwriting", icon: "hand.draw", color: .indigo, tool: .handwriting)
                        directToolChip("Translate", icon: "translate", color: .green, tool: .scanTranslate)
                        directToolChip("Analyze", icon: "brain.head.profile", color: .purple, tool: .smartAnalyze)
                        directToolChip("Objects", icon: "eye.fill", color: .teal, tool: .objectDetector)
                        directToolChip("QR Code", icon: "qrcode.viewfinder", color: .purple, tool: .qrScanner)
                        directToolChip("Document", icon: "doc.viewfinder", color: .teal, tool: .docScanner)
                        directToolChip("Batch", icon: "doc.on.doc", color: .orange, tool: .batchScan)
                        directToolChip("Sign Doc", icon: "signature", color: .green, tool: .signDocument)
                        directToolChip("Merge PDF", icon: "doc.on.doc.fill", color: .red, tool: .pdfMerge)
                        directToolChip("Units", icon: "arrow.left.arrow.right", color: .teal, tool: .unitConverter)
                        directToolChip("Ruler", icon: "ruler", color: .brown, tool: .ruler)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private func toolCategoryLabel(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
    }

    private func directToolChip(_ title: String, icon: String, color: Color, tool: DirectTool) -> some View {
        Button {
            showDirectTool = tool
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(color.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .frame(width: 72)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
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
    }

    private func recentCard(_ item: ScanHistoryItem) -> some View {
        Button {
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

// MARK: - Direct Tool Enum

enum DirectTool: String, Identifiable {
    case removeBG, compress, passport, colorPicker, imageToPDF
    case wordCounter, summarizer, compare, jsonFormatter
    case qrScanner, docScanner, batchScan, signDocument
    case unitConverter, ruler
    case receipt, table, notes, docToPDF, websiteDetect
    case handwriting, scanTranslate, imageResize, watermark, pdfMerge
    case smartAnalyze, objectDetector

    var id: String { rawValue }

    @MainActor @ViewBuilder
    var view: some View {
        switch self {
        case .removeBG: RemoveBackgroundView()
        case .compress: ImageCompressorView()
        case .passport: PassportPhotoView()
        case .colorPicker: ColorPickerImageView()
        case .imageToPDF: ImageToPDFView()
        case .wordCounter: WordCounterView()
        case .summarizer: TextSummarizerView()
        case .compare: TextCompareView()
        case .jsonFormatter: CodeFormatterView()
        case .qrScanner: QRScannerTab()
        case .docScanner: DocumentScannerTab()
        case .batchScan: BatchScanView()
        case .signDocument: DocumentSigningView()
        case .unitConverter: UnitConverterView()
        case .ruler: RulerView()
        case .receipt: ReceiptScannerView()
        case .table: TableExtractorView()
        case .notes: NotesFromScanView()
        case .docToPDF: DocToPDFView()
        case .websiteDetect: WebsiteDetectionView()
        case .handwriting: HandwritingView()
        case .scanTranslate: ScanTranslateView()
        case .imageResize: ImageResizeView()
        case .watermark: WatermarkView()
        case .pdfMerge: PDFMergeView()
        case .smartAnalyze: SmartSummaryView()
        case .objectDetector: ObjectDetectorView()
        }
    }
}

#Preview {
    CaptureView()
        .modelContainer(for: [ScanHistoryItem.self, ClipboardItem.self], inMemory: true)
}
