import SwiftUI
import Photos
import Vision

struct PassportPhotoView: View {
    @Environment(\.toolContext) private var toolContext
    @State private var showPicker = false
    @State private var selectedImage: UIImage?
    @State private var didApplyContext = false
    @State private var croppedImage: UIImage?
    @State private var selectedPresetIndex = 0
    @State private var customWidth = ""
    @State private var customHeight = ""
    @State private var isCustom = false
    @State private var addWhiteBG = false
    @State private var savedToPhotos = false
    @State private var saveError: String?

    // Each preset has unique aspect ratio or unique output size
    // Grouped: no duplicates, clearly different ratios
    private let presets: [(name: String, detail: String, widthPx: Int, heightPx: Int)] = [
        // Square (1:1)
        ("US Passport",     "2\u{00D7}2 in \u{2022} 600\u{00D7}600",   600, 600),
        // 3.5:4.5 (0.778)
        ("India Passport",  "3.5\u{00D7}4.5 cm \u{2022} 413\u{00D7}531", 413, 531),
        // 2.5:3.5 (0.714)
        ("Aadhaar / PAN",   "2.5\u{00D7}3.5 cm \u{2022} 295\u{00D7}413", 295, 413),
        // 4:5 (0.8)
        ("Driving License",  "3.6\u{00D7}4.5 cm \u{2022} 360\u{00D7}450", 360, 450),
        // 2:2.5 (0.8) — smaller output
        ("Stamp Size",      "2\u{00D7}2.5 cm \u{2022} 236\u{00D7}295", 236, 295),
        // 33:48 (0.688)
        ("China Visa",      "3.3\u{00D7}4.8 cm \u{2022} 390\u{00D7}567", 390, 567),
        // 35:45 at higher res for EU
        ("EU / Schengen",   "3.5\u{00D7}4.5 cm \u{2022} 413\u{00D7}531", 413, 531),
        // 4.5:4.5 square
        ("Japan Visa",      "4.5\u{00D7}4.5 cm \u{2022} 531\u{00D7}531", 531, 531),
        // Square high-res
        ("Profile / LinkedIn", "Square \u{2022} 800\u{00D7}800",       800, 800),
        // 3.5:4.5 but 2x resolution for print
        ("Print (2x India)", "3.5\u{00D7}4.5 cm \u{2022} 827\u{00D7}1063", 827, 1063),
    ]

    private var targetWidth: Int {
        if isCustom { return Int(customWidth) ?? 600 }
        return presets[selectedPresetIndex].widthPx
    }

    private var targetHeight: Int {
        if isCustom { return Int(customHeight) ?? 600 }
        return presets[selectedPresetIndex].heightPx
    }

    private var targetAspectRatio: CGFloat {
        guard targetHeight > 0 else { return 1 }
        return CGFloat(targetWidth) / CGFloat(targetHeight)
    }

    private var currentLabel: String {
        if isCustom {
            return "Custom \(targetWidth)\u{00D7}\(targetHeight) px"
        }
        return "\(presets[selectedPresetIndex].name) \u{2022} \(targetWidth)\u{00D7}\(targetHeight)"
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
        .navigationTitle("Passport Photo")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !didApplyContext, let img = toolContext.image, img.size.width > 0 {
                didApplyContext = true
                selectedImage = img
            }
        }
        .sheet(isPresented: $showPicker) {
            ImagePicker { image in
                selectedImage = image
                croppedImage = nil
            }
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 80)
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.08))
                        .frame(width: 120, height: 120)
                    Image(systemName: "person.crop.rectangle")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.purple)
                }
                VStack(spacing: 8) {
                    Text("Passport Photo")
                        .font(.title2.bold())
                    Text("Crop photos to passport, visa, or ID sizes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            Spacer(minLength: 80)
            Button {
                showPicker = true
            } label: {
                Label("Select Photo", systemImage: "photo.on.rectangle")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Image Selected

    private func imageSection(_ image: UIImage) -> some View {
        VStack(spacing: 16) {
            // Preview — show at TRUE aspect ratio so user sees the difference
            if let cropped = croppedImage {
                croppedPreview(cropped)
            } else {
                // Original image
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
                    .padding(.horizontal)
            }

            // Size picker
            VStack(alignment: .leading, spacing: 10) {
                Text("Photo Size")
                    .font(.headline)
                    .padding(.horizontal)

                Picker("Mode", selection: $isCustom) {
                    Text("Preset").tag(false)
                    Text("Custom").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: isCustom) { croppedImage = nil }

                if isCustom {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Width (px)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("600", text: $customWidth)
                                .keyboardType(.numberPad)
                                .padding(10)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        Text("\u{00D7}")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .padding(.top, 16)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Height (px)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("600", text: $customHeight)
                                .keyboardType(.numberPad)
                                .padding(10)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(.horizontal)

                    // Aspect ratio preview shape
                    aspectPreviewShape
                } else {
                    // Preset list — show ratio + dimensions
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(presets.indices, id: \.self) { i in
                                presetChip(index: i)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // White background toggle
                Toggle(isOn: $addWhiteBG) {
                    HStack(spacing: 8) {
                        Image(systemName: "circle.fill")
                            .foregroundStyle(.white)
                            .background(Circle().stroke(Color(.separator)))
                            .font(.caption)
                        Text("White Background")
                            .font(.subheadline)
                    }
                }
                .padding(.horizontal)
                .onChange(of: addWhiteBG) { croppedImage = nil }
            }

            // Actions
            VStack(spacing: 10) {
                Button {
                    cropImage(image)
                } label: {
                    Label(croppedImage == nil ? "Crop to Size" : "Re-crop", systemImage: "crop")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .disabled(isCustom && ((Int(customWidth) ?? 0) < 50 || (Int(customHeight) ?? 0) < 50))

                if let cropped = croppedImage {
                    // Size info badge
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.caption2)
                        Text("Output: \(Int(cropped.size.width))\u{00D7}\(Int(cropped.size.height)) px")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(Capsule())

                    // Save to Photos
                    Button {
                        saveToPhotos(cropped)
                    } label: {
                        Label(savedToPhotos ? "Saved to Photos" : "Save to Photos", systemImage: savedToPhotos ? "checkmark.circle.fill" : "square.and.arrow.down")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                    .tint(savedToPhotos ? .green : .accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    ShareLink(item: Image(uiImage: cropped), preview: SharePreview("Passport Photo", image: Image(uiImage: cropped))) {
                        Label("Share Photo", systemImage: "square.and.arrow.up")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    Button {
                        if let data = cropped.pngData() {
                            UIPasteboard.general.setData(data, forPasteboardType: "public.png")
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    } label: {
                        Label("Copy Image", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    if let err = saveError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Button {
                    showPicker = true
                } label: {
                    Label("Change Photo", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Cropped Preview (true proportions)

    private var croppedDisplaySize: (w: CGFloat, h: CGFloat) {
        let aspect = targetAspectRatio
        let maxW: CGFloat = 220
        let maxH: CGFloat = 280
        if aspect >= 1 {
            let w = min(maxW, maxH * aspect)
            return (w, w / aspect)
        } else {
            let h = min(maxH, maxW / aspect)
            return (h * aspect, h)
        }
    }

    private func croppedPreview(_ cropped: UIImage) -> some View {
        let size = croppedDisplaySize

        return VStack(spacing: 8) {
            ZStack {
                if !addWhiteBG {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .frame(width: size.w + 8, height: size.h + 8)
                }

                Image(uiImage: cropped)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: size.w, height: size.h)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
            }

            HStack(spacing: 4) {
                Image(systemName: "aspectratio")
                    .font(.caption2)
                Text(currentLabel)
                    .font(.caption2.weight(.medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(Capsule())
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Aspect Preview Shape (for custom mode)

    private var aspectPreviewShape: some View {
        let w = CGFloat(Int(customWidth) ?? 600)
        let h = CGFloat(Int(customHeight) ?? 600)
        let aspect = h > 0 ? w / h : 1.0
        let previewH: CGFloat = 60
        let previewW = previewH * aspect

        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.accentColor, lineWidth: 2)
                .frame(width: max(20, min(100, previewW)), height: previewH)
                .overlay {
                    Text("\(Int(w))\u{00D7}\(Int(h))")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            Text("Ratio \(String(format: "%.2f", aspect))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    // MARK: - Preset Chip

    private func presetChip(index i: Int) -> some View {
        let p = presets[i]
        let ratio = CGFloat(p.widthPx) / CGFloat(p.heightPx)
        let isSelected = selectedPresetIndex == i

        return Button {
            selectedPresetIndex = i
            croppedImage = nil
        } label: {
            VStack(spacing: 4) {
                // Mini aspect ratio preview
                let chipH: CGFloat = 32
                let chipW = chipH * ratio
                RoundedRectangle(cornerRadius: 3)
                    .fill(isSelected ? Color.accentColor : Color(.systemGray4))
                    .frame(width: max(18, chipW), height: chipH)

                Text(p.name)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)

                Text(p.detail)
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
            )
        }
    }

    // MARK: - Save to Photos

    private func saveToPhotos(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    saveError = "Photo library access denied. Enable in Settings."
                }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                if let data = image.pngData() {
                    request.addResource(with: .photo, data: data, options: nil)
                }
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    if success {
                        savedToPhotos = true
                        saveError = nil
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } else {
                        saveError = error?.localizedDescription ?? "Failed to save"
                    }
                }
            }
        }
    }

    // MARK: - Crop (with face detection)

    private func cropImage(_ image: UIImage) {
        let tw = CGFloat(targetWidth)
        let th = CGFloat(targetHeight)
        guard tw > 0, th > 0 else { return }

        let normalized = image.fixedOrientation()
        guard let cgImage = normalized.cgImage else { return }

        // Detect face to center crop on it
        let faceCenter = detectFaceCenter(in: cgImage, imageSize: normalized.size)

        let imageSize = normalized.size
        let targetAspect = tw / th
        var cropRect: CGRect
        let imageAspect = imageSize.width / imageSize.height

        if imageAspect > targetAspect {
            let newWidth = imageSize.height * targetAspect
            let centerX = faceCenter?.x ?? (imageSize.width / 2)
            let xOffset = max(0, min(imageSize.width - newWidth, centerX - newWidth / 2))
            cropRect = CGRect(x: xOffset, y: 0, width: newWidth, height: imageSize.height)
        } else {
            let newHeight = imageSize.width / targetAspect
            if let face = faceCenter {
                // Place face in upper third of the crop
                let desiredFaceY = newHeight * 0.35
                let yOffset = max(0, min(imageSize.height - newHeight, face.y - desiredFaceY))
                cropRect = CGRect(x: 0, y: yOffset, width: imageSize.width, height: newHeight)
            } else {
                let yOffset = max(0, (imageSize.height - newHeight) * 0.25)
                cropRect = CGRect(x: 0, y: yOffset, width: imageSize.width, height: newHeight)
            }
        }

        guard let cropped = cgImage.cropping(to: cropRect) else { return }
        savedToPhotos = false
        saveError = nil

        if addWhiteBG {
            let padFraction: CGFloat = 0.10
            let padW = tw * padFraction
            let padH = th * padFraction
            let totalSize = CGSize(width: tw + padW * 2, height: th + padH * 2)
            let renderer = UIGraphicsImageRenderer(size: totalSize)
            croppedImage = renderer.image { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: totalSize))
                UIImage(cgImage: cropped).draw(in: CGRect(x: padW, y: padH, width: tw, height: th))
            }
        } else {
            let size = CGSize(width: tw, height: th)
            let renderer = UIGraphicsImageRenderer(size: size)
            croppedImage = renderer.image { _ in
                UIImage(cgImage: cropped).draw(in: CGRect(origin: .zero, size: size))
            }
        }
    }

    /// Returns face center in image coordinates (top-left origin), or nil if no face found.
    private func detectFaceCenter(in cgImage: CGImage, imageSize: CGSize) -> CGPoint? {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])

        guard let face = request.results?.first else { return nil }
        // Vision uses bottom-left origin normalized coords — convert to top-left image coords
        let box = face.boundingBox
        let cx = box.midX * imageSize.width
        let cy = (1 - box.midY) * imageSize.height
        return CGPoint(x: cx, y: cy)
    }
}
