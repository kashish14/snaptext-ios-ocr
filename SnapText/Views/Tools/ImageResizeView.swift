import SwiftUI
import Photos

struct ImageResizeView: View {
    @State private var showPicker = false
    @State private var selectedImage: UIImage?
    @State private var resizedImage: UIImage?
    @State private var selectedPresetIndex = 0
    @State private var isCustom = false
    @State private var customWidth = ""
    @State private var customHeight = ""
    @State private var maintainAspect = true
    @State private var savedToPhotos = false

    private let presets: [(name: String, detail: String, w: Int, h: Int)] = [
        ("Instagram Post",    "1080\u{00D7}1080", 1080, 1080),
        ("Instagram Story",   "1080\u{00D7}1920", 1080, 1920),
        ("WhatsApp DP",       "500\u{00D7}500",   500,  500),
        ("Facebook Cover",    "820\u{00D7}312",   820,  312),
        ("Twitter Header",    "1500\u{00D7}500",  1500, 500),
        ("YouTube Thumbnail", "1280\u{00D7}720",  1280, 720),
        ("LinkedIn Banner",   "1584\u{00D7}396",  1584, 396),
        ("iPhone Wallpaper",  "1170\u{00D7}2532", 1170, 2532),
        ("HD",                "1920\u{00D7}1080", 1920, 1080),
        ("4K",                "3840\u{00D7}2160", 3840, 2160),
        ("A4 Print (300dpi)", "2480\u{00D7}3508", 2480, 3508),
    ]

    private var targetW: Int {
        isCustom ? (Int(customWidth) ?? 800) : presets[selectedPresetIndex].w
    }
    private var targetH: Int {
        isCustom ? (Int(customHeight) ?? 800) : presets[selectedPresetIndex].h
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let image = selectedImage {
                    imageSection(image)
                } else {
                    emptyState
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Image Resize")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) {
            ImagePicker { image in
                selectedImage = image
                resizedImage = nil
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
                        .fill(Color.cyan.opacity(0.08))
                        .frame(width: 120, height: 120)
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.cyan)
                }
                VStack(spacing: 8) {
                    Text("Image Resize")
                        .font(.title2.bold())
                    Text("Resize images for social media, print, or any custom size")
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
            .tint(.cyan)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }

    private func imageSection(_ image: UIImage) -> some View {
        VStack(spacing: 16) {
            // Preview
            if let resized = resizedImage {
                Image(uiImage: resized)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
                    .padding(.horizontal)

                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.caption2)
                    Text("Output: \(Int(resized.size.width))\u{00D7}\(Int(resized.size.height)) px")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(Capsule())
            } else {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
                    .padding(.horizontal)

                HStack(spacing: 6) {
                    Text("Original: \(Int(image.size.width))\u{00D7}\(Int(image.size.height)) px")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.secondary)
            }

            // Size picker
            VStack(alignment: .leading, spacing: 10) {
                Text("Target Size")
                    .font(.headline)
                    .padding(.horizontal)

                Picker("Mode", selection: $isCustom) {
                    Text("Presets").tag(false)
                    Text("Custom").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: isCustom) { resizedImage = nil }

                if isCustom {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Width (px)").font(.caption).foregroundStyle(.secondary)
                            TextField("800", text: $customWidth)
                                .keyboardType(.numberPad)
                                .padding(10)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        Text("\u{00D7}").font(.title2).foregroundStyle(.secondary).padding(.top, 16)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Height (px)").font(.caption).foregroundStyle(.secondary)
                            TextField("800", text: $customHeight)
                                .keyboardType(.numberPad)
                                .padding(10)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(.horizontal)

                    Toggle("Maintain aspect ratio", isOn: $maintainAspect)
                        .font(.subheadline)
                        .padding(.horizontal)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(presets.indices, id: \.self) { i in
                                presetChip(i)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }

            // Actions
            VStack(spacing: 10) {
                Button {
                    resizeImage(image)
                } label: {
                    Label(resizedImage == nil ? "Resize" : "Re-resize", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                if let resized = resizedImage {
                    Button {
                        saveToPhotos(resized)
                    } label: {
                        Label(savedToPhotos ? "Saved!" : "Save to Photos", systemImage: savedToPhotos ? "checkmark.circle.fill" : "square.and.arrow.down")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                    .tint(savedToPhotos ? .green : .cyan)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    ShareLink(item: Image(uiImage: resized), preview: SharePreview("Resized Image", image: Image(uiImage: resized))) {
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

    private func presetChip(_ i: Int) -> some View {
        let p = presets[i]
        let isSelected = selectedPresetIndex == i
        return Button {
            selectedPresetIndex = i
            resizedImage = nil
        } label: {
            VStack(spacing: 4) {
                Text(p.name)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                Text(p.detail)
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? Color.cyan.opacity(0.12) : Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.cyan : .clear, lineWidth: 1.5)
            )
        }
    }

    private func resizeImage(_ image: UIImage) {
        let normalized = image.fixedOrientation()
        let tw = CGFloat(targetW)
        let th = CGFloat(targetH)
        guard tw > 0, th > 0 else { return }

        var finalW = tw
        var finalH = th

        if isCustom && maintainAspect {
            let aspect = normalized.size.width / normalized.size.height
            if tw / th > aspect {
                finalW = th * aspect
            } else {
                finalH = tw / aspect
            }
        }

        let size = CGSize(width: finalW, height: finalH)
        let renderer = UIGraphicsImageRenderer(size: size)
        resizedImage = renderer.image { _ in
            normalized.draw(in: CGRect(origin: .zero, size: size))
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
