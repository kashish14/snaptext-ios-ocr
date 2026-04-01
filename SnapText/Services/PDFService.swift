import UIKit

final class PDFService {

    /// Renders an array of images into a single PDF.
    static func renderPDF(from images: [UIImage]) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: .zero)
        return renderer.pdfData { context in
            for image in images {
                let size = image.size
                let pageRect = CGRect(origin: .zero, size: size)
                context.beginPage(withBounds: pageRect, pageInfo: [:])
                image.draw(in: pageRect)
            }
        }
    }

    /// Saves PDF data to a temporary file and returns the URL.
    static func saveTempPDF(_ data: Data, name: String = "SnapText") -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)_\(Int(Date().timeIntervalSince1970)).pdf")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}
