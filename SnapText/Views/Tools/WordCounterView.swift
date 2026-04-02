import SwiftUI

struct WordCounterView: View {
    @Environment(\.toolContext) private var toolContext
    @State private var inputText = ""
    @State private var showGallery = false
    @State private var isProcessing = false
    @State private var didApplyContext = false

    private let ocrService = OCRService()

    private var stats: [(label: String, value: String, icon: String)] {
        let text = inputText
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let chars = trimmed.count
        let charsNoSpaces = trimmed.filter { !$0.isWhitespace }.count
        let words = trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        var sentences = 0
        trimmed.enumerateSubstrings(in: trimmed.startIndex..., options: [.bySentences, .localized]) { _, _, _, _ in
            sentences += 1
        }
        let paragraphs = trimmed.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        let lines = trimmed.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count

        return [
            ("Characters", "\(chars)", "character.cursor.ibeam"),
            ("No Spaces", "\(charsNoSpaces)", "textformat.abc"),
            ("Words", "\(words)", "text.word.spacing"),
            ("Sentences", "\(sentences)", "text.alignleft"),
            ("Paragraphs", "\(paragraphs)", "paragraphsign"),
            ("Lines", "\(lines)", "list.bullet"),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter or scan text")
                        .font(.headline)

                    TextEditor(text: $inputText)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.separator), lineWidth: 0.5)
                        )
                }
                .padding(.horizontal)

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
                    ProgressView("Scanning...")
                }

                if !stats.isEmpty {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(stats, id: \.label) { stat in
                            VStack(spacing: 6) {
                                Image(systemName: stat.icon)
                                    .font(.title3)
                                    .foregroundStyle(.tint)
                                Text(stat.value)
                                    .font(.title2.bold())
                                Text(stat.label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Word Counter")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !didApplyContext, let text = toolContext.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                didApplyContext = true
                inputText = text
            }
        }
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
}
