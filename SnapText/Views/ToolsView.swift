import SwiftUI

struct ToolsView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Scan & Extract
                    toolSection("Scan & Extract", icon: "viewfinder") {
                        toolGrid([
                            ToolItem(title: "Text Scanner", icon: "doc.text.viewfinder", color: .blue, destination: AnyView(ScanViewPush())),
                            ToolItem(title: "QR Scanner", icon: "qrcode.viewfinder", color: .purple, destination: AnyView(QRScannerTab())),
                            ToolItem(title: "Batch Scan", icon: "doc.on.doc", color: .orange, destination: AnyView(BatchScanView())),
                            ToolItem(title: "Doc Scanner", icon: "doc.viewfinder", color: .teal, destination: AnyView(DocumentScannerTab())),
                        ])
                    }

                    // Smart Scanners
                    toolSection("Smart Scanners", icon: "sparkle.magnifyingglass") {
                        toolGrid([
                            ToolItem(title: "Receipt", icon: "receipt", color: .mint, destination: AnyView(ReceiptScannerView())),
                            ToolItem(title: "Table / CSV", icon: "tablecells", color: .cyan, destination: AnyView(TableExtractorView())),
                            ToolItem(title: "Website URL", icon: "globe", color: .orange, destination: AnyView(WebsiteDetectionView())),
                        ])
                    }

                    // Convert & Edit
                    toolSection("Convert & Edit", icon: "arrow.triangle.2.circlepath") {
                        toolGrid([
                            ToolItem(title: "Image to PDF", icon: "photo.on.rectangle.angled", color: .red, destination: AnyView(ImageToPDFView())),
                            ToolItem(title: "Doc to PDF", icon: "doc.badge.arrow.up", color: .indigo, destination: AnyView(DocToPDFView())),
                            ToolItem(title: "Sign Document", icon: "signature", color: .green, destination: AnyView(DocumentSigningView())),
                            ToolItem(title: "Compress Image", icon: "arrow.down.right.and.arrow.up.left", color: .blue, destination: AnyView(ImageCompressorView())),
                            ToolItem(title: "Passport Photo", icon: "person.crop.rectangle", color: .purple, destination: AnyView(PassportPhotoView())),
                            ToolItem(title: "Remove BG", icon: "person.and.background.strikethrough", color: .pink, destination: AnyView(RemoveBackgroundView())),
                        ])
                    }

                    // Text Tools
                    toolSection("Text Tools", icon: "textformat") {
                        toolGrid([
                            ToolItem(title: "Word Counter", icon: "number", color: .blue, destination: AnyView(WordCounterView())),
                            ToolItem(title: "Summarizer", icon: "text.badge.checkmark", color: .green, destination: AnyView(TextSummarizerView())),
                            ToolItem(title: "Compare Texts", icon: "doc.text.magnifyingglass", color: .orange, destination: AnyView(TextCompareView())),
                            ToolItem(title: "JSON Formatter", icon: "curlybraces", color: .purple, destination: AnyView(CodeFormatterView())),
                            ToolItem(title: "Notes from Scan", icon: "note.text", color: .yellow, destination: AnyView(NotesFromScanView())),
                        ])
                    }

                    // Utilities
                    toolSection("Utilities", icon: "wrench.and.screwdriver") {
                        toolGrid([
                            ToolItem(title: "Unit Converter", icon: "arrow.left.arrow.right", color: .teal, destination: AnyView(UnitConverterView())),
                            ToolItem(title: "Color Picker", icon: "eyedropper", color: .pink, destination: AnyView(ColorPickerImageView())),
                            ToolItem(title: "Ruler", icon: "ruler", color: .brown, destination: AnyView(RulerView())),
                        ])
                    }

                    // Footer
                    VStack(spacing: 6) {
                        Text("20 tools \u{2022} 20+ auto-detections")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text("Phone \u{2022} Email \u{2022} Address \u{2022} URL \u{2022} Date \u{2022} UPI \u{2022} Tracking \u{2022} WiFi \u{2022} Flight \u{2022} PAN \u{2022} Aadhaar \u{2022} GST \u{2022} IFSC \u{2022} Coordinates \u{2022} & more")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Tools")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Helpers

    private func toolSection<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
                Text(title)
                    .font(.headline)
            }
            .padding(.horizontal, 20)
            content()
        }
    }

    private func toolGrid(_ items: [ToolItem]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(items) { item in
                NavigationLink {
                    item.destination
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: item.icon)
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.white)
                            .frame(width: 46, height: 46)
                            .background(item.color.gradient)
                            .clipShape(RoundedRectangle(cornerRadius: 13))
                            .shadow(color: item.color.opacity(0.3), radius: 4, y: 2)

                        Text(item.title)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.04), radius: 3, y: 2)
                }
            }
        }
        .padding(.horizontal)
    }
}

private struct ToolItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
    let destination: AnyView
}

/// Wrapper to push ScanView's OCR mode as standalone from Tools
private struct ScanViewPush: View {
    @State private var viewModel = ScanViewModel()
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 24) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                VStack(spacing: 8) {
                    Text("Text Scanner")
                        .font(.title2.bold())
                    Text("Extract text from any image")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if viewModel.isProcessing {
                    ProgressView("Extracting text...").padding()
                }
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.callout).foregroundStyle(.red)
                        .multilineTextAlignment(.center).padding(.horizontal)
                }
            }
            Spacer()
            HStack(spacing: 20) {
                Button { viewModel.showCamera = true } label: {
                    Label("Camera", systemImage: "camera.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                Button { viewModel.showGallery = true } label: {
                    Label("Gallery", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).controlSize(.large)
            }
            .padding(.horizontal).padding(.bottom, 16)
        }
        .navigationTitle("Text Scanner")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.modelContext = modelContext }
        .fullScreenCover(isPresented: $viewModel.showCamera) {
            CameraView { image in Task { await viewModel.processImage(image) } }.ignoresSafeArea()
        }
        .sheet(isPresented: $viewModel.showGallery) {
            ImagePicker { image in Task { await viewModel.processImage(image) } }
        }
        .sheet(item: $viewModel.scanResult) { result in
            ScanResultView(
                result: result,
                onCopy: { viewModel.copyToClipboard($0) },
                onDismiss: { viewModel.clearResult() }
            )
        }
    }
}

#Preview {
    ToolsView()
}
