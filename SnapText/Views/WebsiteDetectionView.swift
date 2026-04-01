import SwiftUI

struct WebsiteDetectionView: View {
    @State private var showPicker = false
    @State private var detectedURL: String?
    @State private var otherURLs: [String] = []
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var copied = false

    private let ocrService = OCRService()

    var body: some View {
        VStack(spacing: 16) {
            if detectedURL == nil && !isProcessing {
                Spacer()
                VStack(spacing: 24) {
                    Image(systemName: "globe")
                        .font(.system(size: 64))
                        .foregroundStyle(.tint)

                    VStack(spacing: 8) {
                        Text("Website from Screenshot")
                            .font(.title2.bold())
                        Text("Upload a browser screenshot to extract the URL")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
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
                    showPicker = true
                } label: {
                    Label("Select Screenshot", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
                .padding(.bottom, 16)

            } else if isProcessing {
                Spacer()
                ProgressView("Detecting website...")
                Spacer()

            } else if let url = detectedURL {
                resultView(url: url)
            }
        }
        .navigationTitle("Website Detection")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) {
            ImagePicker { image in
                Task { await detectWebsite(from: image) }
            }
        }
    }

    private func resultView(url: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "globe")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
                .padding(.top, 32)

            Text("Website Detected")
                .font(.title2.bold())

            // Main URL
            VStack(alignment: .leading, spacing: 8) {
                Text("URL from address bar")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(url)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)

            // Actions
            VStack(spacing: 12) {
                Button {
                    let urlStr = url.hasPrefix("http") ? url : "https://\(url)"
                    if let openURL = URL(string: urlStr) {
                        UIApplication.shared.open(openURL)
                    }
                } label: {
                    Label("Open in Safari", systemImage: "safari.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    ClipboardManager.shared.copy(url, source: "Website")
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                } label: {
                    Label(copied ? "Copied!" : "Copy URL", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal)

            // Other URLs found
            if !otherURLs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Other URLs found in page")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    ForEach(otherURLs, id: \.self) { otherURL in
                        HStack {
                            Text(otherURL)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Button {
                                UIPasteboard.general.string = otherURL
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    }
                }
            }

            Spacer()

            Button {
                detectedURL = nil
                otherURLs = []
                showPicker = true
            } label: {
                Label("Scan Another", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }

    private func detectWebsite(from image: UIImage) async {
        isProcessing = true
        errorMessage = nil

        do {
            let results = try await ocrService.recognizeTextWithPositions(in: image)

            // Find URLs and score by position (higher bounding box y = closer to top of screen)
            // Vision coordinates: origin at bottom-left, y goes up
            var urlsWithScore: [(url: String, score: Double)] = []

            let urlDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

            for (text, box) in results {
                let range = NSRange(text.startIndex..., in: text)
                if let matches = urlDetector?.matches(in: text, options: [], range: range) {
                    for match in matches {
                        guard let url = match.url else { continue }
                        let urlString = url.absoluteString
                        // Score: higher y position in Vision coords = top of screen = more likely URL bar
                        let score = box.origin.y + box.height
                        urlsWithScore.append((urlString, score))
                    }
                }

                // Also check for bare domains (e.g., "example.com/path")
                let domainPattern = try! NSRegularExpression(
                    pattern: #"\b[a-zA-Z0-9-]+\.[a-zA-Z]{2,}(?:/[^\s]*)?\b"#
                )
                let domainMatches = domainPattern.matches(in: text, range: range)
                for match in domainMatches {
                    guard let r = Range(match.range, in: text) else { continue }
                    let domain = String(text[r])
                    // Skip if too short or looks like a file extension
                    if domain.count > 5 && domain.contains(".") {
                        let score = box.origin.y + box.height
                        urlsWithScore.append((domain, score))
                    }
                }
            }

            await MainActor.run {
                isProcessing = false

                if urlsWithScore.isEmpty {
                    errorMessage = "No website URL found in this screenshot."
                    return
                }

                // Sort by score (highest = top of screen = URL bar)
                let sorted = urlsWithScore.sorted { $0.score > $1.score }

                // Top-scoring URL is the address bar
                detectedURL = sorted.first?.url

                // Remaining are page content URLs
                var seen = Set<String>()
                seen.insert(detectedURL ?? "")
                otherURLs = sorted.dropFirst().compactMap { item in
                    seen.insert(item.url).inserted ? item.url : nil
                }
            }
        } catch {
            await MainActor.run {
                isProcessing = false
                errorMessage = "Could not process screenshot."
            }
        }
    }
}
