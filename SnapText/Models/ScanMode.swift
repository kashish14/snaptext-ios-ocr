import Foundation

enum ScanMode: String, CaseIterable, Identifiable {
    case ocrText = "Text"
    case qrCode = "QR Code"
    case documentScan = "Document"
    case batchScan = "Batch"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .ocrText: return "doc.text.viewfinder"
        case .qrCode: return "qrcode.viewfinder"
        case .documentScan: return "doc.viewfinder"
        case .batchScan: return "doc.on.doc"
        }
    }
}
