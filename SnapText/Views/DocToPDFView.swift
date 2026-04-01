import SwiftUI
import UniformTypeIdentifiers

struct DocToPDFView: View {
    @State private var showFilePicker = false
    @State private var selectedFileURL: URL?
    @State private var fileName: String?
    @State private var pdfData: Data?
    @State private var pdfDataBW: Data?
    @State private var isConverting = false
    @State private var errorMessage: String?
    @State private var applyBW = false
    @State private var isImageSource = false

    var body: some View {
        VStack(spacing: 16) {
            if selectedFileURL == nil {
                Spacer()
                VStack(spacing: 24) {
                    Image(systemName: "doc.badge.arrow.up")
                        .font(.system(size: 64))
                        .foregroundStyle(.tint)

                    VStack(spacing: 8) {
                        Text("Doc to PDF")
                            .font(.title2.bold())
                        Text("Convert documents and images to PDF")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }
                }
                Spacer()

                Button {
                    showFilePicker = true
                } label: {
                    Label("Select File", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
                .padding(.bottom, 16)
            } else {
                resultView
            }
        }
        .navigationTitle("Doc to PDF")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.image, .plainText, .rtf, .rtfd, .html],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    private var resultView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "doc.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            if let name = fileName {
                Text(name)
                    .font(.headline)
            }

            if isConverting {
                ProgressView("Converting...")
                    .padding()
            }

            if let error = errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Spacer()

            VStack(spacing: 12) {
                if isImageSource {
                    Toggle("Black & White", isOn: $applyBW)
                        .onChange(of: applyBW) { pdfDataBW = nil }
                }

                if let data = activePDFData {
                    let transferable = PDFTransferable(data: data)
                    ShareLink(item: transferable, preview: SharePreview("Converted PDF", image: Image(systemName: "doc.fill"))) {
                        Label("Share PDF", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                Button {
                    selectedFileURL = nil
                    pdfData = nil
                    pdfDataBW = nil
                    fileName = nil
                    errorMessage = nil
                    isImageSource = false
                    applyBW = false
                    showFilePicker = true
                } label: {
                    Label("Select Another", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }

    private var activePDFData: Data? {
        if applyBW && isImageSource {
            return pdfDataBW
        }
        return pdfData
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Could not access file."
                return
            }
            selectedFileURL = url
            fileName = url.lastPathComponent
            convertToPDF(url: url)

        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func convertToPDF(url: URL) {
        isConverting = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async {
            var data: Data?
            var dataBW: Data?
            var isImage = false

            // Try to load as image first
            if let imageData = try? Data(contentsOf: url),
               let image = UIImage(data: imageData) {
                isImage = true
                data = PDFService.renderPDF(from: [image])
                dataBW = PDFService.renderPDF(from: [image.blackAndWhite()])
            }
            // Try to load as text
            else if let textContent = try? String(contentsOf: url, encoding: .utf8) {
                data = renderTextPDF(textContent)
            }
            // Try as attributed string (RTF/HTML)
            else if let attrString = try? NSAttributedString(
                url: url,
                options: [:],
                documentAttributes: nil
            ) {
                data = renderTextPDF(attrString.string)
            }

            url.stopAccessingSecurityScopedResource()

            DispatchQueue.main.async {
                isConverting = false
                isImageSource = isImage
                if let data {
                    pdfData = data
                    pdfDataBW = dataBW
                } else {
                    errorMessage = "Could not convert this file type."
                }
            }
        }
    }

    private func renderTextPDF(_ text: String) -> Data {
        let pageWidth: CGFloat = 612  // US Letter
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        let textRect = CGRect(x: margin, y: margin, width: pageWidth - margin * 2, height: pageHeight - margin * 2)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .paragraphStyle: paragraphStyle,
            .foregroundColor: UIColor.black
        ]

        let attrString = NSAttributedString(string: text, attributes: attributes)

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        return renderer.pdfData { context in
            let framesetter = CTFramesetterCreateWithAttributedString(attrString)
            var charIndex = 0
            let totalLength = attrString.length

            while charIndex < totalLength {
                context.beginPage()
                let path = CGPath(rect: textRect, transform: nil)
                let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(charIndex, 0), path, nil)
                let ctxRef = context.cgContext
                ctxRef.translateBy(x: 0, y: pageHeight)
                ctxRef.scaleBy(x: 1.0, y: -1.0)
                CTFrameDraw(frame, ctxRef)
                let visibleRange = CTFrameGetVisibleStringRange(frame)
                charIndex += max(visibleRange.length, 1)
            }
        }
    }
}
