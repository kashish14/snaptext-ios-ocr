import SwiftUI

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

    private let presets: [(name: String, widthPx: Int, heightPx: Int)] = [
        ("Passport India (3.5\u{00D7}4.5 cm)", 413, 531),
        ("Passport US (2\u{00D7}2 in)", 600, 600),
        ("Visa US (2\u{00D7}2 in)", 600, 600),
        ("Passport UK (3.5\u{00D7}4.5 cm)", 413, 531),
        ("Aadhaar Card (2.5\u{00D7}3.5 cm)", 295, 413),
        ("PAN Card (2.5\u{00D7}3.5 cm)", 295, 413),
        ("Driving License India", 360, 450),
        ("Stamp Size (2\u{00D7}2.5 cm)", 236, 295),
        ("EU/Schengen Visa (3.5\u{00D7}4.5 cm)", 413, 531),
        ("China Visa (3.3\u{00D7}4.8 cm)", 390, 567),
        ("Japan Visa (4.5\u{00D7}4.5 cm)", 531, 531),
        ("LinkedIn/Profile Pic (Square)", 800, 800),
    ]

    private var targetWidth: Int {
        if isCustom { return Int(customWidth) ?? 600 }
        return presets[selectedPresetIndex].widthPx
    }

    private var targetHeight: Int {
        if isCustom { return Int(customHeight) ?? 600 }
        return presets[selectedPresetIndex].heightPx
    }

    private var currentLabel: String {
        if isCustom {
            return "Custom (\(targetWidth)\u{00D7}\(targetHeight) px)"
        }
        return presets[selectedPresetIndex].name
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
            // Preview
            let display = croppedImage ?? image
            Image(uiImage: display)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 280)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
                .padding(.horizontal)

            if croppedImage != nil {
                Text(currentLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            // Size picker
            VStack(alignment: .leading, spacing: 10) {
                Text("Photo Size")
                    .font(.headline)
                    .padding(.horizontal)

                // Preset or Custom toggle
                Picker("Mode", selection: $isCustom) {
                    Text("Preset").tag(false)
                    Text("Custom").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: isCustom) { croppedImage = nil }

                if isCustom {
                    // Custom H x W input
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
                } else {
                    // Preset list
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(presets.indices, id: \.self) { i in
                                Button {
                                    selectedPresetIndex = i
                                    croppedImage = nil
                                } label: {
                                    Text(presets[i].name)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(selectedPresetIndex == i ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                                        .foregroundStyle(selectedPresetIndex == i ? .white : .primary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
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
                .disabled(isCustom && (Int(customWidth) ?? 0) < 50 && (Int(customHeight) ?? 0) < 50)

                if let cropped = croppedImage {
                    ShareLink(item: Image(uiImage: cropped), preview: SharePreview("Passport Photo", image: Image(uiImage: cropped))) {
                        Label("Share Photo", systemImage: "square.and.arrow.up")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
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

    // MARK: - Crop

    private func cropImage(_ image: UIImage) {
        let tw = CGFloat(targetWidth)
        let th = CGFloat(targetHeight)
        guard tw > 0, th > 0 else { return }

        // Normalize orientation first
        let normalized = image.fixedOrientation()
        let imageSize = normalized.size
        let targetAspect = tw / th

        var cropRect: CGRect
        let imageAspect = imageSize.width / imageSize.height

        if imageAspect > targetAspect {
            // Image wider than target — crop sides
            let newWidth = imageSize.height * targetAspect
            let xOffset = (imageSize.width - newWidth) / 2
            cropRect = CGRect(x: xOffset, y: 0, width: newWidth, height: imageSize.height)
        } else {
            // Image taller than target — crop bottom, bias toward top (face)
            let newHeight = imageSize.width / targetAspect
            let yOffset = max(0, (imageSize.height - newHeight) * 0.25)
            cropRect = CGRect(x: 0, y: yOffset, width: imageSize.width, height: newHeight)
        }

        guard let cgImage = normalized.cgImage?.cropping(to: cropRect) else { return }

        // Resize to exact target pixels
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: tw, height: th))
        croppedImage = renderer.image { _ in
            UIImage(cgImage: cgImage).draw(in: CGRect(x: 0, y: 0, width: tw, height: th))
        }
    }
}
