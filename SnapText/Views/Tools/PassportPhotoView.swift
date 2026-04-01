import SwiftUI

struct PassportPhotoView: View {
    @State private var showPicker = false
    @State private var selectedImage: UIImage?
    @State private var selectedSize = 0
    @State private var croppedImage: UIImage?

    private let sizes: [(name: String, width: CGFloat, height: CGFloat)] = [
        ("Passport (2\u{00D7}2 in)", 600, 600),
        ("Visa (2\u{00D7}2.5 in)", 600, 750),
        ("ID Card (1.4\u{00D7}1.8 in)", 420, 540),
        ("Aadhaar (3.5\u{00D7}4.5 cm)", 413, 531),
        ("Custom Square", 600, 600),
    ]

    var body: some View {
        VStack(spacing: 16) {
            if let image = selectedImage {
                // Preview
                VStack(spacing: 8) {
                    let display = croppedImage ?? image
                    Image(uiImage: display)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 4)

                    if croppedImage != nil {
                        let size = sizes[selectedSize]
                        Text("\(size.name)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

                // Size picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Photo Size")
                        .font(.headline)

                    Picker("Size", selection: $selectedSize) {
                        ForEach(sizes.indices, id: \.self) { i in
                            Text(sizes[i].name).tag(i)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedSize) { cropImage() }
                }
                .padding(.horizontal)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        cropImage()
                    } label: {
                        Label("Crop to Size", systemImage: "crop")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    if let cropped = croppedImage {
                        ShareLink(item: Image(uiImage: cropped), preview: SharePreview("Passport Photo", image: Image(uiImage: cropped))) {
                            Label("Share Photo", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
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
                .padding(.bottom, 16)
            } else {
                Spacer()
                VStack(spacing: 24) {
                    Image(systemName: "person.crop.rectangle")
                        .font(.system(size: 64))
                        .foregroundStyle(.tint)
                    VStack(spacing: 8) {
                        Text("Passport Photo")
                            .font(.title2.bold())
                        Text("Crop photos to passport, visa, or ID sizes")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                Spacer()
                Button {
                    showPicker = true
                } label: {
                    Label("Select Photo", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
        .navigationTitle("Passport Photo")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) {
            ImagePicker { image in
                selectedImage = image
                croppedImage = nil
            }
        }
    }

    private func cropImage() {
        guard let image = selectedImage else { return }
        let targetSize = sizes[selectedSize]
        let aspectRatio = targetSize.width / targetSize.height

        let imageSize = image.size
        var cropRect: CGRect

        let imageAspect = imageSize.width / imageSize.height
        if imageAspect > aspectRatio {
            // Image is wider — crop sides
            let newWidth = imageSize.height * aspectRatio
            let xOffset = (imageSize.width - newWidth) / 2
            cropRect = CGRect(x: xOffset, y: 0, width: newWidth, height: imageSize.height)
        } else {
            // Image is taller — crop top (keep face area more centered toward top)
            let newHeight = imageSize.width / aspectRatio
            let yOffset = max(0, (imageSize.height - newHeight) * 0.3) // bias toward top where face usually is
            cropRect = CGRect(x: 0, y: yOffset, width: imageSize.width, height: newHeight)
        }

        guard let cgImage = image.cgImage?.cropping(to: cropRect) else { return }
        let cropped = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)

        // Resize to target pixels
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: targetSize.width, height: targetSize.height))
        croppedImage = renderer.image { _ in
            cropped.draw(in: CGRect(origin: .zero, size: CGSize(width: targetSize.width, height: targetSize.height)))
        }
    }
}
