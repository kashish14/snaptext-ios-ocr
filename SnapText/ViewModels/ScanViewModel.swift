import SwiftUI
import SwiftData
import UIKit

@Observable
@MainActor
final class ScanViewModel {

    // MARK: - State

    var scanResult: ScanResult?
    var isProcessing = false
    var errorMessage: String?

    var showCamera = false
    var showGallery = false

    var modelContext: ModelContext?

    // MARK: - Services

    private let ocrService = OCRService()
    private let smartDetector = SmartDetector()

    // MARK: - Actions

    func processImage(_ image: UIImage) async {
        isProcessing = true
        errorMessage = nil

        do {
            let text = try await ocrService.recognizeText(in: image, mode: .accurate)
            let entities = smartDetector.detect(in: text)
            let result = ScanResult(image: image, text: text, entities: entities)

            scanResult = result
            saveToHistory(result)
        } catch let error as OCRService.OCRError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }

        isProcessing = false
    }

    func copyToClipboard(_ text: String) {
        ClipboardManager.shared.copy(text, source: "Scan")
    }

    func clearResult() {
        scanResult = nil
        errorMessage = nil
    }

    // MARK: - History persistence

    private func saveToHistory(_ result: ScanResult) {
        guard let modelContext else { return }
        let item = ScanHistoryItem(
            text: result.text,
            image: result.image,
            entities: result.entities,
            timestamp: result.timestamp
        )
        modelContext.insert(item)
        try? modelContext.save()
    }
}
