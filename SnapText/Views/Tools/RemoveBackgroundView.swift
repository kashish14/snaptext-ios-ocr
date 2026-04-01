import SwiftUI
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

struct RemoveBackgroundView: View {
    @State private var showPicker = false
    @State private var originalImage: UIImage?
    @State private var resultImage: UIImage?
    @State private var isProcessing = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            if let original = originalImage {
                // Before/After
                VStack(spacing: 8) {
                    if isProcessing {
                        Image(uiImage: original)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        ProgressView("Removing background...")
                    } else if let result = resultImage {
                        // Checkerboard background to show transparency
                        ZStack {
                            CheckerboardView()
                                .frame(maxHeight: 300)
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            Image(uiImage: result)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 300)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)

                if let error = errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                Spacer()

                VStack(spacing: 12) {
                    if let result = resultImage {
                        ShareLink(item: Image(uiImage: result), preview: SharePreview("No Background", image: Image(uiImage: result))) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Button {
                            if let data = result.pngData() {
                                UIPasteboard.general.setData(data, forPasteboardType: "public.png")
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            }
                        } label: {
                            Label("Copy Image", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
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
                    Image(systemName: "person.and.background.strikethrough")
                        .font(.system(size: 64))
                        .foregroundStyle(.tint)
                    VStack(spacing: 8) {
                        Text("Remove Background")
                            .font(.title2.bold())
                        Text("Isolate the subject from any photo")
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
        .navigationTitle("Remove Background")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) {
            ImagePicker { image in
                originalImage = image
                resultImage = nil
                errorMessage = nil
                removeBackground(from: image)
            }
        }
    }

    private func removeBackground(from image: UIImage) {
        isProcessing = true
        errorMessage = nil

        Task.detached {
            do {
                guard let cgImage = image.cgImage else {
                    throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid image"])
                }

                let request = VNGenerateForegroundInstanceMaskRequest()
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try handler.perform([request])

                guard let result = request.results?.first else {
                    throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "No subject detected"])
                }

                let mask = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
                let ciImage = CIImage(cvPixelBuffer: mask)

                let originalCI = CIImage(cgImage: cgImage)

                // Apply mask
                let filter = CIFilter.blendWithMask()
                filter.inputImage = originalCI
                filter.backgroundImage = CIImage.empty()
                filter.maskImage = ciImage

                let context = CIContext()
                guard let output = filter.outputImage,
                      let finalCG = context.createCGImage(output, from: originalCI.extent) else {
                    throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to process"])
                }

                let finalImage = UIImage(cgImage: finalCG, scale: image.scale, orientation: image.imageOrientation)

                await MainActor.run {
                    resultImage = finalImage
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Could not remove background: \(error.localizedDescription)"
                    isProcessing = false
                }
            }
        }
    }
}

// MARK: - Checkerboard background

private struct CheckerboardView: View {
    var body: some View {
        Canvas { context, size in
            let cellSize: CGFloat = 12
            let cols = Int(ceil(size.width / cellSize))
            let rows = Int(ceil(size.height / cellSize))
            for row in 0..<rows {
                for col in 0..<cols {
                    let isLight = (row + col) % 2 == 0
                    let rect = CGRect(x: CGFloat(col) * cellSize, y: CGFloat(row) * cellSize, width: cellSize, height: cellSize)
                    context.fill(Path(rect), with: .color(isLight ? Color(.systemGray5) : Color(.systemGray4)))
                }
            }
        }
    }
}
