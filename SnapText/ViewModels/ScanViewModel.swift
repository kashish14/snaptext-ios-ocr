import SwiftUI
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

    // History of scans in this session (SwiftData persistence comes in Sprint 4)
    var scanHistory: [ScanResult] = []

    // MARK: - Free tier tracking

    private let dailyScanLimitKey = "dailyScanCount"
    private let dailyScanDateKey = "dailyScanDate"
    private let freeScanLimit = 15

    var scansUsedToday: Int {
        resetCountIfNewDay()
        return UserDefaults.standard.integer(forKey: dailyScanLimitKey)
    }

    var scansRemaining: Int {
        max(0, freeScanLimit - scansUsedToday)
    }

    var hasReachedLimit: Bool {
        scansUsedToday >= freeScanLimit
    }

    // MARK: - Services

    private let ocrService = OCRService()
    private let smartDetector = SmartDetector()

    // MARK: - Actions

    func processImage(_ image: UIImage) async {
        guard !hasReachedLimit else {
            errorMessage = "You've used all \(freeScanLimit) free scans today. Come back tomorrow or go Pro!"
            return
        }

        isProcessing = true
        errorMessage = nil

        do {
            let text = try await ocrService.recognizeText(in: image, mode: .accurate)
            let entities = smartDetector.detect(in: text)
            let result = ScanResult(image: image, text: text, entities: entities)

            scanResult = result
            scanHistory.insert(result, at: 0)
            incrementScanCount()
        } catch let error as OCRService.OCRError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }

        isProcessing = false
    }

    func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
    }

    func clearResult() {
        scanResult = nil
        errorMessage = nil
    }

    // MARK: - Scan counting

    private func incrementScanCount() {
        resetCountIfNewDay()
        let current = UserDefaults.standard.integer(forKey: dailyScanLimitKey)
        UserDefaults.standard.set(current + 1, forKey: dailyScanLimitKey)
    }

    private func resetCountIfNewDay() {
        let storedDate = UserDefaults.standard.string(forKey: dailyScanDateKey) ?? ""
        let today = Self.todayString()

        if storedDate != today {
            UserDefaults.standard.set(0, forKey: dailyScanLimitKey)
            UserDefaults.standard.set(today, forKey: dailyScanDateKey)
        }
    }

    private static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
