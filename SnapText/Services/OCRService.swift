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
    /// - Parameters:
    ///   - image: The source image.
    ///   - mode: `.fast` for share extension speed, `.accurate` for main app quality.
    /// - Returns: The recognized text as a single string.
    nonisolated func recognizeText(
        in image: UIImage,
        mode: RecognitionMode = .accurate
    ) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.imageConversionFailed
        }

        let downscaled = Self.downscaleIfNeeded(cgImage, maxDimension: 2048)

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

                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")

                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continuation.resume(throwing: OCRError.noTextFound)
                } else {
                    continuation.resume(returning: text)
                }
            }

            request.recognitionLevel = (mode == .fast) ? .fast : .accurate
            request.usesLanguageCorrection = (mode == .accurate)

            let handler = VNImageRequestHandler(cgImage: downscaled, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.recognitionFailed(error))
            }
        }
    }

    /// Downscales a CGImage if its largest dimension exceeds maxDimension.
    /// Keeps the Share Extension within the 120MB memory limit.
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
