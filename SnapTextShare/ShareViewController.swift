import UIKit
import UniformTypeIdentifiers

/// Share Extension: Screenshot → Share → SnapText → text copied. No app switch.
/// Uses the fast Vision path to stay inside the extension memory budget.
final class ShareViewController: UIViewController {

    private let label = UILabel()
    private let spinner = UIActivityIndicatorView(style: .large)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        label.font = .preferredFont(forTextStyle: .headline)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = "Reading text…"
        let stack = UIStackView(arrangedSubviews: [spinner, label])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
        ])
        spinner.startAnimating()
        Task { await run() }
    }

    private func run() async {
        do {
            let image = try await loadImage()
            let text = try await OCRService().recognizeText(in: image, mode: .fast)
            UIPasteboard.general.string = text
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            finish("Copied \(text.count) characters")
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            finish(error.localizedDescription)
        }
    }

    private func loadImage() async throws -> UIImage {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }) else {
            throw OCRService.OCRError.imageConversionFailed
        }
        let data: Data = try await withCheckedThrowingContinuation { cont in
            _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                if let data { cont.resume(returning: data) }
                else { cont.resume(throwing: error ?? OCRService.OCRError.imageConversionFailed) }
            }
        }
        guard let image = UIImage(data: data) else { throw OCRService.OCRError.imageConversionFailed }
        return image
    }

    private func finish(_ message: String) {
        spinner.stopAnimating()
        label.text = message
        Task {
            try? await Task.sleep(for: .seconds(1))
            extensionContext?.completeRequest(returningItems: nil)
        }
    }
}
