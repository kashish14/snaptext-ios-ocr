import SwiftUI
import SwiftData

struct ScanView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ScanViewModel()
    @State private var scanMode: ScanMode = .ocrText

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Mode picker
                Picker("Scan Mode", selection: $scanMode) {
                    ForEach(ScanMode.allCases) { mode in
                        Label(mode.rawValue, systemImage: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                // Content based on mode
                switch scanMode {
                case .ocrText:
                    ocrContent
                case .qrCode:
                    QRScannerTab()
                case .documentScan:
                    DocumentScannerTab()
                case .batchScan:
                    BatchScanView()
                }
            }
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.modelContext = modelContext
            }
        }
    }

    // MARK: - OCR Content

    private var ocrContent: some View {
        ZStack {
            // Subtle gradient background
            LinearGradient(
                colors: [Color(.systemBackground), Color.blue.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 28) {
                    // Animated icon with glow
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 120, height: 120)

                        Circle()
                            .fill(Color.blue.opacity(0.05))
                            .frame(width: 160, height: 160)

                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 56, weight: .light))
                            .foregroundStyle(
                                LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .symbolEffect(.pulse, options: .repeating.speed(0.5))
                    }

                    VStack(spacing: 10) {
                        Text("SnapText")
                            .font(.largeTitle.bold())
                            .foregroundStyle(
                                LinearGradient(colors: [.primary, .primary.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                            )
                        Text("Screenshot \u{2192} Copy \u{2192} Done")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if viewModel.isProcessing {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Extracting text...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                    }
                }

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    HStack(spacing: 14) {
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

                    Text("Supports 20+ auto-detections")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
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
            ScanResultView(
                result: result,
                onCopy: { viewModel.copyToClipboard($0) },
                onDismiss: { viewModel.clearResult() }
            )
        }
    }
}

#Preview {
    ScanView()
}
