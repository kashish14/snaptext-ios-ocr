import SwiftUI

struct ColorPickerImageView: View {
    @Environment(\.toolContext) private var toolContext
    @State private var showPicker = false
    @State private var selectedImage: UIImage?
    @State private var didApplyContext = false
    @State private var pickedColor: Color?
    @State private var hexString = ""
    @State private var rgbString = ""
    @State private var tapLocation: CGPoint = .zero
    @State private var copied = false

    var body: some View {
        VStack(spacing: 16) {
            if let image = selectedImage {
                // Image with tap-to-pick
                GeometryReader { geo in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: geo.size.width, maxHeight: geo.size.height)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    let imageSize = image.size
                                    let viewSize = geo.size

                                    // Calculate the fitted image frame
                                    let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
                                    let renderedWidth = imageSize.width * scale
                                    let renderedHeight = imageSize.height * scale
                                    let offsetX = (viewSize.width - renderedWidth) / 2
                                    let offsetY = (viewSize.height - renderedHeight) / 2

                                    let tapX = value.location.x - offsetX
                                    let tapY = value.location.y - offsetY

                                    guard tapX >= 0, tapY >= 0, tapX <= renderedWidth, tapY <= renderedHeight else { return }

                                    let pixelX = Int(tapX / scale)
                                    let pixelY = Int(tapY / scale)

                                    if let color = image.pixelColor(x: pixelX, y: pixelY) {
                                        pickedColor = Color(color)
                                        hexString = color.hexString
                                        rgbString = color.rgbString
                                        tapLocation = value.location
                                    }
                                }
                        )
                        .overlay {
                            if pickedColor != nil {
                                Circle()
                                    .stroke(.white, lineWidth: 2)
                                    .frame(width: 30, height: 30)
                                    .shadow(radius: 2)
                                    .position(tapLocation)
                            }
                        }
                }
                .padding(.horizontal)

                // Color result
                if let color = pickedColor {
                    HStack(spacing: 16) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(color)
                            .frame(width: 60, height: 60)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.separator), lineWidth: 1)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(hexString)
                                    .font(.title3.bold().monospaced())
                                Button {
                                    ClipboardManager.shared.copy(hexString, source: "Color Picker")
                                    copied = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                                } label: {
                                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                        .font(.caption)
                                        .foregroundStyle(copied ? .green : .secondary)
                                }
                            }
                            Text(rgbString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                } else {
                    Text("Tap anywhere on the image to pick a color")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    showPicker = true
                } label: {
                    Label("Change Image", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .padding(.horizontal)
                .padding(.bottom, 16)
            } else {
                Spacer()
                VStack(spacing: 24) {
                    Image(systemName: "eyedropper")
                        .font(.system(size: 64))
                        .foregroundStyle(.tint)

                    VStack(spacing: 8) {
                        Text("Color Picker")
                            .font(.title2.bold())
                        Text("Pick colors from any image")
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
        .navigationTitle("Color Picker")
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
                pickedColor = nil
                hexString = ""
                rgbString = ""
            }
        }
    }
}

// MARK: - UIImage pixel color extraction

extension UIImage {
    func pixelColor(x: Int, y: Int) -> UIColor? {
        guard let cgImage = cgImage,
              let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data else { return nil }

        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        let pixelData: UnsafePointer<UInt8> = CFDataGetBytePtr(data)

        guard x >= 0, y >= 0, x < cgImage.width, y < cgImage.height else { return nil }

        let offset = (y * bytesPerRow) + (x * bytesPerPixel)
        let r = CGFloat(pixelData[offset]) / 255.0
        let g = CGFloat(pixelData[offset + 1]) / 255.0
        let b = CGFloat(pixelData[offset + 2]) / 255.0
        let a = bytesPerPixel >= 4 ? CGFloat(pixelData[offset + 3]) / 255.0 : 1.0

        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}

extension UIColor {
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    var rgbString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return "RGB(\(Int(r * 255)), \(Int(g * 255)), \(Int(b * 255)))"
    }
}
