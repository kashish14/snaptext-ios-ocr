import SwiftUI
import VisionKit
import UniformTypeIdentifiers

struct DocumentScannerTab: View {
    @State private var showScanner = false
    @State private var scannedPages: [UIImage] = []
    @State private var showResult = false
    @State private var applyBW = false

    var body: some View {
        VStack(spacing: 0) {
            if scannedPages.isEmpty {
                Spacer()
                VStack(spacing: 24) {
                    Image(systemName: "doc.viewfinder")
                        .font(.system(size: 64))
                        .foregroundStyle(.tint)

                    VStack(spacing: 8) {
                        Text("Document Scanner")
                            .font(.title2.bold())
                        Text("Auto edge detection & perspective correction")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()

                Button {
                    showScanner = true
                } label: {
                    Label("Scan Document", systemImage: "doc.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
                .padding(.bottom, 16)
            } else {
                documentResult
            }
        }
        .fullScreenCover(isPresented: $showScanner) {
            DocumentCameraRepresentable { pages in
                scannedPages = pages
            }
            .ignoresSafeArea()
        }
    }

    private var documentResult: some View {
        VStack(spacing: 16) {
            // Page thumbnails
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(scannedPages.enumerated()), id: \.offset) { index, page in
                        let displayImage = applyBW ? page.blackAndWhite() : page
                        Image(uiImage: displayImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(radius: 4)
                            .overlay(alignment: .topTrailing) {
                                Text("Page \(index + 1)")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                                    .padding(8)
                            }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top, 12)

            // B&W toggle
            Toggle("Black & White", isOn: $applyBW)
                .padding(.horizontal)

            Text("\(scannedPages.count) page\(scannedPages.count == 1 ? "" : "s") scanned")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            // Actions
            VStack(spacing: 12) {
                ShareLink(item: pdfTransferable, preview: SharePreview("Scanned Document", image: Image(systemName: "doc.fill"))) {
                    Label("Export PDF", systemImage: "arrow.down.doc.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                HStack(spacing: 12) {
                    Button {
                        showScanner = true
                    } label: {
                        Label("Re-scan", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button(role: .destructive) {
                        scannedPages = []
                    } label: {
                        Label("Clear", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }

    private var pdfTransferable: PDFTransferable {
        let images = applyBW ? scannedPages.map { $0.blackAndWhite() } : scannedPages
        let data = PDFService.renderPDF(from: images)
        return PDFTransferable(data: data)
    }
}

// MARK: - PDF Transferable for ShareLink

struct PDFTransferable: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { item in
            item.data
        }
    }
}

// MARK: - VNDocumentCameraViewController wrapper

struct DocumentCameraRepresentable: UIViewControllerRepresentable {
    let onScan: ([UIImage]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScan: ([UIImage]) -> Void

        init(onScan: @escaping ([UIImage]) -> Void) {
            self.onScan = onScan
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            for i in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: i))
            }
            controller.dismiss(animated: true) {
                self.onScan(images)
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true)
        }
    }
}

// MARK: - B&W Filter

extension UIImage {
    func blackAndWhite() -> UIImage {
        guard let ciImage = CIImage(image: self) else { return self }

        // Step 1: Remove color
        let mono = CIFilter(name: "CIColorControls")!
        mono.setValue(ciImage, forKey: kCIInputImageKey)
        mono.setValue(0.0, forKey: kCIInputSaturationKey)
        mono.setValue(1.0, forKey: kCIInputBrightnessKey)  // keep brightness
        guard let grayOutput = mono.outputImage else { return self }

        // Step 2: Threshold for crisp B&W (like a photocopy)
        // Use CIColorMap or a curve to push grays to black/white
        let threshold = CIFilter(name: "CIExposureAdjust")!
        threshold.setValue(grayOutput, forKey: kCIInputImageKey)
        threshold.setValue(0.3, forKey: kCIInputEVKey)  // slight brighten
        guard let brightened = threshold.outputImage else { return self }

        // Step 3: High contrast to make text crisp, background white
        let contrast = CIFilter(name: "CIColorControls")!
        contrast.setValue(brightened, forKey: kCIInputImageKey)
        contrast.setValue(2.5, forKey: kCIInputContrastKey)  // strong contrast
        contrast.setValue(0.0, forKey: kCIInputSaturationKey)
        guard let output = contrast.outputImage else { return self }

        let context = CIContext()
        guard let cgImage = context.createCGImage(output, from: output.extent) else { return self }
        return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
    }
}
