import SwiftUI

struct ScanView: View {
    @State private var viewModel = ScanViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                // Center content
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

                // Scan counter
                Text("\(viewModel.scansRemaining) free scans left today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)

                // Action buttons
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
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.inline)
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
}

#Preview {
    ScanView()
}
