import Vision
import UIKit

@MainActor
final class OCRService {

    enum OCRError: LocalizedError {
        case noTextFound
        case imageConversionFailed
        case recognitionFailed(Error)

        var errorDescription: String? {
            switch self {
            case .noTextFound:
                return "No text found in the image."
            case .imageConversionFailed:
                return "Could not process the image."
            case .recognitionFailed(let error):
                return "Recognition failed: \(error.localizedDescription)"
            }
        }
    }

    enum RecognitionMode {
        case fast
        case accurate
    }

    /// Extracts text from a UIImage using Apple Vision.
    nonisolated func recognizeText(
        in image: UIImage,
        mode: RecognitionMode = .accurate
    ) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.imageConversionFailed
        }

        // Higher resolution limit — 4096 preserves small text while staying in memory budget
        let downscaled = Self.downscaleIfNeeded(cgImage, maxDimension: 4096)

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: OCRError.recognitionFailed(error))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation],
                      !observations.isEmpty else {
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }

                // Sort observations top-to-bottom, left-to-right for proper reading order
                let sorted = observations.sorted { a, b in
                    let ay = 1 - a.boundingBox.origin.y  // Vision uses bottom-left origin
                    let by = 1 - b.boundingBox.origin.y
                    if abs(ay - by) < 0.01 {
                        // Same line — sort left to right
                        return a.boundingBox.origin.x < b.boundingBox.origin.x
                    }
                    return ay < by
                }

                let text = sorted
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")

                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continuation.resume(throwing: OCRError.noTextFound)
                } else {
                    continuation.resume(returning: text)
                }
            }

            // Maximum accuracy settings
            request.recognitionLevel = (mode == .fast) ? .fast : .accurate
            request.usesLanguageCorrection = true
            // Recognize all supported languages for better coverage
            request.automaticallyDetectsLanguage = true
            // Lower minimum text height to catch small text (default is ~1/32 of image)
            request.minimumTextHeight = 0.005

            let handler = VNImageRequestHandler(cgImage: downscaled, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.recognitionFailed(error))
            }
        }
    }

    /// Extracts text with bounding box positions for spatial analysis.
    nonisolated func recognizeTextWithPositions(
        in image: UIImage
    ) async throws -> [(text: String, boundingBox: CGRect)] {
        guard let cgImage = image.cgImage else {
            throw OCRError.imageConversionFailed
        }

        let downscaled = Self.downscaleIfNeeded(cgImage, maxDimension: 4096)

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: OCRError.recognitionFailed(error))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation],
                      !observations.isEmpty else {
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }

                let results = observations.compactMap { obs -> (String, CGRect)? in
                    guard let text = obs.topCandidates(1).first?.string else { return nil }
                    return (text, obs.boundingBox)
                }

                continuation.resume(returning: results)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true
            request.minimumTextHeight = 0.005

            let handler = VNImageRequestHandler(cgImage: downscaled, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.recognitionFailed(error))
            }
        }
    }

    /// Downscales a CGImage if its largest dimension exceeds maxDimension.
    nonisolated private static func downscaleIfNeeded(
        _ image: CGImage,
        maxDimension: Int
    ) -> CGImage {
        let width = image.width
        let height = image.height
        let longest = max(width, height)

        guard longest > maxDimension else { return image }

        let scale = CGFloat(maxDimension) / CGFloat(longest)
        let newWidth = Int(CGFloat(width) * scale)
        let newHeight = Int(CGFloat(height) * scale)

        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: image.bitmapInfo.rawValue
        ) else {
            return image
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        return context.makeImage() ?? image
    }
}
