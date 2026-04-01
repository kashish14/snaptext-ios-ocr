import SwiftUI

struct ImageCompressorView: View {
    @State private var showPicker = false
    @State private var originalImage: UIImage?
    @State private var quality: Double = 0.7
    @State private var compressedData: Data?

    private var originalSize: String {
        guard let img = originalImage, let data = img.jpegData(compressionQuality: 1.0) else { return "" }
        return formatBytes(data.count)
    }

    private var compressedSize: String {
        guard let data = compressedData else { return "" }
        return formatBytes(data.count)
    }

    private var savings: String {
        guard let img = originalImage,
              let origData = img.jpegData(compressionQuality: 1.0),
              let compData = compressedData else { return "" }
        let pct = 100.0 - (Double(compData.count) / Double(origData.count) * 100.0)
        return String(format: "%.0f%% smaller", pct)
    }

    var body: some View {
        VStack(spacing: 16) {
            if let image = originalImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                // Size info
                HStack {
                    VStack(spacing: 4) {
                        Text("Original")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(originalSize)
                            .font(.subheadline.bold())
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                    Spacer()
                    VStack(spacing: 4) {
                        Text("Compressed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(compressedSize)
                            .font(.subheadline.bold())
                            .foregroundStyle(.green)
                    }
                    if !savings.isEmpty {
                        Text(savings)
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal)

                // Quality slider
                VStack(spacing: 8) {
                    HStack {
                        Text("Quality")
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(quality * 100))%")
                            .font(.subheadline.bold())
                    }
                    Slider(value: $quality, in: 0.05...1.0, step: 0.05)
                        .onChange(of: quality) { compress() }
                }
                .padding(.horizontal)

                Spacer()

                VStack(spacing: 12) {
                    if let data = compressedData, let compressed = UIImage(data: data) {
                        ShareLink(item: Image(uiImage: compressed), preview: SharePreview("Compressed Image", image: Image(uiImage: compressed))) {
                            Label("Share Compressed", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }

                    Button {
                        showPicker = true
                    } label: {
                        Label("Change Image", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            } else {
                Spacer()
                VStack(spacing: 24) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 64))
                        .foregroundStyle(.tint)
                    VStack(spacing: 8) {
                        Text("Image Compressor")
                            .font(.title2.bold())
                        Text("Reduce image file size for sharing")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    showPicker = true
                } label: {
                    Label("Select Image", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
        .navigationTitle("Image Compressor")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) {
            ImagePicker { image in
                originalImage = image
                compress()
            }
        }
    }

    private func compress() {
        guard let image = originalImage else { return }
        compressedData = image.jpegData(compressionQuality: quality)
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1_048_576 { return String(format: "%.1f KB", Double(bytes) / 1024.0) }
        return String(format: "%.1f MB", Double(bytes) / 1_048_576.0)
    }
}
