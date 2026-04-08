import SwiftUI
import Photos

struct WatermarkView: View {
    @State private var showPicker = false
    @State private var selectedImage: UIImage?
    @State private var watermarkedImage: UIImage?
    @State private var watermarkText = ""
    @State private var fontSize: Double = 24
    @State private var opacity: Double = 0.4
    @State private var position = WatermarkPosition.bottomRight
    @State private var textColor = Color.white
    @State private var savedToPhotos = false

    enum WatermarkPosition: String, CaseIterable {
        case topLeft = "Top Left"
        case topRight = "Top Right"
        case center = "Center"
        case bottomLeft = "Bottom Left"
        case bottomRight = "Bottom Right"
        case tiled = "Tiled"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let image = selectedImage {
                    editSection(image)
                } else {
                    emptyState
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Watermark")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) {
            ImagePicker { image in
                selectedImage = image
                watermarkedImage = nil
                savedToPhotos = false
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 80)
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.08))
                        .frame(width: 120, height: 120)
                    Image(systemName: "textformat.abc.dottedunderline")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.orange)
                }
                VStack(spacing: 8) {
                    Text("Watermark")
                        .font(.title2.bold())
                    Text("Add text watermarks to protect your images")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            Spacer(minLength: 80)
            Button {
                showPicker = true
            } label: {
                Label("Select Image", systemImage: "photo.on.rectangle")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }

    private func editSection(_ image: UIImage) -> some View {
        VStack(spacing: 16) {
            // Preview
            Image(uiImage: watermarkedImage ?? image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 240)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
                .padding(.horizontal)

            // Watermark text input
            VStack(alignment: .leading, spacing: 10) {
                Text("Watermark Text")
                    .font(.headline)
                    .padding(.horizontal)

                TextField("Your name or brand...", text: $watermarkText)
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)

                // Position
                VStack(alignment: .leading, spacing: 6) {
                    Text("Position").font(.subheadline.weight(.medium)).padding(.horizontal)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(WatermarkPosition.allCases, id: \.self) { pos in
                                Button {
                                    position = pos
                                } label: {
                                    Text(pos.rawValue)
                                        .font(.caption.weight(.medium))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(position == pos ? Color.orange.opacity(0.15) : Color(.secondarySystemGroupedBackground))
                                        .foregroundStyle(position == pos ? .orange : .primary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Font size
                VStack(alignment: .leading, spacing: 4) {
                    Text("Font Size: \(Int(fontSize))").font(.subheadline.weight(.medium))
                    Slider(value: $fontSize, in: 12...72, step: 2)
                }
                .padding(.horizontal)

                // Opacity
                VStack(alignment: .leading, spacing: 4) {
                    Text("Opacity: \(Int(opacity * 100))%").font(.subheadline.weight(.medium))
                    Slider(value: $opacity, in: 0.1...1.0, step: 0.05)
                }
                .padding(.horizontal)

                // Color
                ColorPicker("Text Color", selection: $textColor)
                    .padding(.horizontal)
            }

            // Actions
            VStack(spacing: 10) {
                Button {
                    applyWatermark(to: image)
                } label: {
                    Label("Apply Watermark", systemImage: "checkmark.seal")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .disabled(watermarkText.trimmingCharacters(in: .whitespaces).isEmpty)

                if let wm = watermarkedImage {
                    Button {
                        saveToPhotos(wm)
                    } label: {
                        Label(savedToPhotos ? "Saved!" : "Save to Photos", systemImage: savedToPhotos ? "checkmark.circle.fill" : "square.and.arrow.down")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                    .tint(savedToPhotos ? .green : .orange)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    ShareLink(item: Image(uiImage: wm), preview: SharePreview("Watermarked", image: Image(uiImage: wm))) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Button { showPicker = true } label: {
                    Label("Change Image", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal)
        }
    }

    private func applyWatermark(to image: UIImage) {
        let normalized = image.fixedOrientation()
        let imgSize = normalized.size
        let renderer = UIGraphicsImageRenderer(size: imgSize)

        let uiColor = UIColor(textColor).withAlphaComponent(opacity)
        let font = UIFont.systemFont(ofSize: fontSize * (imgSize.width / 400), weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: uiColor
        ]
        let textSize = (watermarkText as NSString).size(withAttributes: attrs)

        watermarkedImage = renderer.image { ctx in
            normalized.draw(at: .zero)

            switch position {
            case .topLeft:
                let pt = CGPoint(x: imgSize.width * 0.03, y: imgSize.height * 0.03)
                (watermarkText as NSString).draw(at: pt, withAttributes: attrs)
            case .topRight:
                let pt = CGPoint(x: imgSize.width * 0.97 - textSize.width, y: imgSize.height * 0.03)
                (watermarkText as NSString).draw(at: pt, withAttributes: attrs)
            case .center:
                let pt = CGPoint(x: (imgSize.width - textSize.width) / 2, y: (imgSize.height - textSize.height) / 2)
                (watermarkText as NSString).draw(at: pt, withAttributes: attrs)
            case .bottomLeft:
                let pt = CGPoint(x: imgSize.width * 0.03, y: imgSize.height * 0.97 - textSize.height)
                (watermarkText as NSString).draw(at: pt, withAttributes: attrs)
            case .bottomRight:
                let pt = CGPoint(x: imgSize.width * 0.97 - textSize.width, y: imgSize.height * 0.97 - textSize.height)
                (watermarkText as NSString).draw(at: pt, withAttributes: attrs)
            case .tiled:
                let spacingX = textSize.width + imgSize.width * 0.1
                let spacingY = textSize.height + imgSize.height * 0.1
                // Rotate context for diagonal tiling
                let context = ctx.cgContext
                context.saveGState()
                context.rotate(by: -.pi / 6)
                var y: CGFloat = -imgSize.height
                while y < imgSize.height * 2 {
                    var x: CGFloat = -imgSize.width
                    while x < imgSize.width * 2 {
                        (watermarkText as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: attrs)
                        x += spacingX
                    }
                    y += spacingY
                }
                context.restoreGState()
            }
        }

        savedToPhotos = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func saveToPhotos(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                if let data = image.pngData() {
                    request.addResource(with: .photo, data: data, options: nil)
                }
            } completionHandler: { success, _ in
                DispatchQueue.main.async {
                    if success {
                        savedToPhotos = true
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                }
            }
        }
    }
}
