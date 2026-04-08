import SwiftUI
import NaturalLanguage

/// On-device AI text analysis — language detection, sentiment, key phrases, and auto-summary.
struct SmartSummaryView: View {
    @State private var showPicker = false
    @State private var showCamera = false
    @State private var selectedImage: UIImage?
    @State private var inputText = ""
    @State private var analysis: TextAnalysis?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var copied = false

    private let ocrService = OCRService()

    struct TextAnalysis {
        let language: String
        let sentiment: Double       // -1 to 1
        let sentimentLabel: String
        let wordCount: Int
        let charCount: Int
        let sentenceCount: Int
        let keyPhrases: [String]
        let categories: [String]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if analysis != nil || !inputText.isEmpty {
                    resultSection
                } else if selectedImage != nil {
                    processingSection
                } else {
                    emptyState
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Smart Analyze")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) {
            ImagePicker { image in
                selectedImage = image
                analysis = nil
                processImage(image)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            LiveCameraView { image in
                selectedImage = image
                analysis = nil
                processImage(image)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 60)
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.08))
                        .frame(width: 120, height: 120)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.purple)
                }
                VStack(spacing: 8) {
                    Text("Smart Analyze")
                        .font(.title2.bold())
                    Text("AI-powered text analysis — language, sentiment, key phrases")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            Spacer(minLength: 40)

            // Manual text input
            VStack(alignment: .leading, spacing: 8) {
                Text("Paste or type text").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                TextEditor(text: $inputText)
                    .frame(height: 100)
                    .padding(8)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )

                if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        analyzeText(inputText)
                    } label: {
                        Label("Analyze Text", systemImage: "brain.head.profile")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal)

            // Or scan
            HStack {
                Rectangle().fill(Color(.separator)).frame(height: 0.5)
                Text("or scan from image").font(.caption).foregroundStyle(.tertiary)
                Rectangle().fill(Color(.separator)).frame(height: 0.5)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 12)

            HStack(spacing: 12) {
                Button { showCamera = true } label: {
                    Label("Camera", systemImage: "camera.fill")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Button { showPicker = true } label: {
                    Label("Gallery", systemImage: "photo.on.rectangle")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }

    private var processingSection: some View {
        VStack(spacing: 16) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
            }
            if isProcessing {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Analyzing...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if let error = errorMessage {
                Text(error).font(.callout).foregroundStyle(.red).padding(.horizontal)
            }
        }
    }

    // MARK: - Results

    private var resultSection: some View {
        VStack(spacing: 16) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
            }

            if isProcessing {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Analyzing...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let a = analysis {
                // Stats grid
                VStack(alignment: .leading, spacing: 12) {
                    Text("Analysis").font(.headline).padding(.horizontal)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        statCard("Language", a.language, icon: "globe", color: .blue)
                        statCard("Sentiment", a.sentimentLabel, icon: sentimentIcon(a.sentiment), color: sentimentColor(a.sentiment))
                        statCard("Words", "\(a.wordCount)", icon: "textformat.abc", color: .indigo)
                        statCard("Characters", "\(a.charCount)", icon: "character.cursor.ibeam", color: .teal)
                        statCard("Sentences", "\(a.sentenceCount)", icon: "text.alignleft", color: .orange)
                    }
                    .padding(.horizontal)
                }

                // Sentiment bar
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sentiment Score").font(.subheadline.weight(.medium))
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.systemGray5))
                            RoundedRectangle(cornerRadius: 6)
                                .fill(sentimentColor(a.sentiment).gradient)
                                .frame(width: geo.size.width * CGFloat((a.sentiment + 1) / 2))
                        }
                    }
                    .frame(height: 12)
                    HStack {
                        Text("Negative").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text("Neutral").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text("Positive").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

                // Key phrases
                if !a.keyPhrases.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "key.fill").foregroundStyle(.orange)
                            Text("Key Phrases").font(.headline)
                        }
                        .padding(.horizontal)

                        FlowLayout(spacing: 6) {
                            ForEach(a.keyPhrases, id: \.self) { phrase in
                                Text(phrase)
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.orange.opacity(0.12))
                                    .foregroundStyle(.orange)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Actions
                VStack(spacing: 10) {
                    Button {
                        let summary = buildSummaryText(a)
                        UIPasteboard.general.string = summary
                        Haptics.success()
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                    } label: {
                        Label(copied ? "Copied!" : "Copy Analysis", systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(copied ? .green : .purple)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    HStack(spacing: 12) {
                        Button { showCamera = true } label: {
                            Label("Retake", systemImage: "camera").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered).controlSize(.large)

                        Button { showPicker = true } label: {
                            Label("Gallery", systemImage: "photo").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered).controlSize(.large)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Helpers

    private func statCard(_ title: String, _ value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.caption.bold())
                .lineLimit(1)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func sentimentIcon(_ score: Double) -> String {
        if score > 0.2 { return "face.smiling" }
        if score < -0.2 { return "face.dashed" }
        return "minus.circle"
    }

    private func sentimentColor(_ score: Double) -> Color {
        if score > 0.2 { return .green }
        if score < -0.2 { return .red }
        return .gray
    }

    private func buildSummaryText(_ a: TextAnalysis) -> String {
        """
        Smart Analysis
        Language: \(a.language)
        Sentiment: \(a.sentimentLabel) (\(String(format: "%.2f", a.sentiment)))
        Words: \(a.wordCount) | Characters: \(a.charCount) | Sentences: \(a.sentenceCount)
        Key Phrases: \(a.keyPhrases.joined(separator: ", "))
        """
    }

    // MARK: - Processing

    private func processImage(_ image: UIImage) {
        isProcessing = true
        errorMessage = nil
        Task {
            do {
                let text = try await ocrService.recognizeText(in: image, mode: .accurate)
                await MainActor.run {
                    inputText = text
                    analyzeText(text)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isProcessing = false
                }
            }
        }
    }

    private func analyzeText(_ text: String) {
        isProcessing = true
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            isProcessing = false
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            // Language detection
            let recognizer = NLLanguageRecognizer()
            recognizer.processString(trimmed)
            let langCode = recognizer.dominantLanguage?.rawValue ?? "unknown"
            let locale = Locale(identifier: "en")
            let langName = locale.localizedString(forLanguageCode: langCode) ?? langCode

            // Sentiment
            let tagger = NLTagger(tagSchemes: [.sentimentScore])
            tagger.string = trimmed
            let sentimentTag = tagger.tag(at: trimmed.startIndex, unit: .paragraph, scheme: .sentimentScore).0
            let sentiment = Double(sentimentTag?.rawValue ?? "0") ?? 0

            let sentimentLabel: String
            if sentiment > 0.5 { sentimentLabel = "Very Positive" }
            else if sentiment > 0.2 { sentimentLabel = "Positive" }
            else if sentiment > -0.2 { sentimentLabel = "Neutral" }
            else if sentiment > -0.5 { sentimentLabel = "Negative" }
            else { sentimentLabel = "Very Negative" }

            // Word/char/sentence counts
            let words = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            let sentences = trimmed.components(separatedBy: CharacterSet(charactersIn: ".!?"))
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

            // Key phrases — extract nouns and named entities
            let nounTagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
            nounTagger.string = trimmed
            var phrases = [String]()
            var seen = Set<String>()

            nounTagger.enumerateTags(in: trimmed.startIndex..<trimmed.endIndex, unit: .word, scheme: .nameType) { tag, range in
                if let tag, [.personalName, .placeName, .organizationName].contains(tag) {
                    let word = String(trimmed[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if word.count > 1, seen.insert(word.lowercased()).inserted {
                        phrases.append(word)
                    }
                }
                return true
            }

            nounTagger.enumerateTags(in: trimmed.startIndex..<trimmed.endIndex, unit: .word, scheme: .lexicalClass) { tag, range in
                if tag == .noun {
                    let word = String(trimmed[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if word.count > 2, seen.insert(word.lowercased()).inserted, phrases.count < 15 {
                        phrases.append(word)
                    }
                }
                return true
            }

            let result = TextAnalysis(
                language: langName,
                sentiment: sentiment,
                sentimentLabel: sentimentLabel,
                wordCount: words.count,
                charCount: trimmed.count,
                sentenceCount: sentences.count,
                keyPhrases: Array(phrases.prefix(12)),
                categories: []
            )

            DispatchQueue.main.async {
                analysis = result
                isProcessing = false
            }
        }
    }
}

// MARK: - Flow Layout for tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions = [CGPoint]()
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}
