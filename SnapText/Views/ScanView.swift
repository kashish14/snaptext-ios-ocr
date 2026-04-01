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

    // MARK: - OCR Content (original scan flow)

    private var ocrContent: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)

                VStack(spacing: 8) {
                    Text("SnapText")
                        .font(.largeTitle.bold())
                    Text("Screenshot → Copy → Done")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if viewModel.isProcessing {
                    ProgressView("Extracting text...")
                        .padding()
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }

            Spacer()

            HStack(spacing: 20) {
                Button {
                    viewModel.showCamera = true
                } label: {
                    Label("Camera", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    viewModel.showGallery = true
                } label: {
                    Label("Gallery", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
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
