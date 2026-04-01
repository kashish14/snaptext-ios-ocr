import SwiftUI

struct TextSummarizerView: View {
    @State private var inputText = ""
    @State private var summary = ""
    @State private var showGallery = false
    @State private var isProcessing = false

    private let ocrService = OCRService()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Input Text")
                        .font(.headline)

                    TextEditor(text: $inputText)
                        .frame(minHeight: 150)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.separator), lineWidth: 0.5)
                        )
                }
                .padding(.horizontal)

                // Or scan
                Button {
                    showGallery = true
                } label: {
                    Label("Scan from Image", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .padding(.horizontal)

                if isProcessing {
                    ProgressView("Processing...")
                }

                // Summarize button
                Button {
                    summarize()
                } label: {
                    Label("Summarize", systemImage: "text.badge.checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                // Output
                if !summary.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Summary")
                                .font(.headline)
                            Spacer()
                            Button {
                                ClipboardManager.shared.copy(summary, source: "Summarizer")
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        Text(summary)
                            .font(.body)
                            .textSelection(.enabled)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Text Summarizer")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showGallery) {
            ImagePicker { image in
                Task {
                    isProcessing = true
                    if let text = try? await ocrService.recognizeText(in: image, mode: .accurate) {
                        inputText = text
                    }
                    isProcessing = false
                }
            }
        }
    }

    private func summarize() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Extractive summarization: score sentences by word frequency
        let sentences = splitSentences(text)
        guard sentences.count > 2 else {
            summary = text
            return
        }

        // Word frequency
        let words = text.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count > 3 }
        let stopWords: Set<String> = ["that", "this", "with", "from", "your", "have", "been",
                                       "will", "would", "could", "should", "their", "there",
                                       "were", "what", "when", "which", "about", "also", "them",
                                       "than", "then", "some", "each", "into", "more", "other"]
        var freq: [String: Int] = [:]
        for w in words where !stopWords.contains(w) {
            freq[w, default: 0] += 1
        }

        // Score each sentence
        let scored = sentences.enumerated().map { index, sentence -> (Int, String, Double) in
            let sentWords = sentence.lowercased()
                .components(separatedBy: .alphanumerics.inverted)
                .filter { $0.count > 3 }
            let score = sentWords.reduce(0.0) { $0 + Double(freq[$1] ?? 0) }
            let normalized = sentWords.isEmpty ? 0 : score / Double(sentWords.count)
            // Slight boost for first/second sentence (usually important)
            let positionBoost = index < 2 ? 1.2 : 1.0
            return (index, sentence, normalized * positionBoost)
        }

        // Pick top ~30% sentences, maintain original order
        let count = max(1, sentences.count / 3)
        let topIndices = Set(scored.sorted { $0.2 > $1.2 }.prefix(count).map { $0.0 })
        let result = scored.filter { topIndices.contains($0.0) }.map { $0.1 }

        summary = result.joined(separator: " ")
    }

    private func splitSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: [.bySentences, .localized]) { sub, _, _, _ in
            if let s = sub?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
                sentences.append(s)
            }
        }
        return sentences
    }
}
