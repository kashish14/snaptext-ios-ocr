import SwiftUI

struct CodeFormatterView: View {
    @State private var inputText = ""
    @State private var formattedText = ""
    @State private var selectedFormat = FormatType.json
    @State private var errorMessage: String?
    @State private var copied = false

    enum FormatType: String, CaseIterable {
        case json = "JSON"
        case xml = "XML"
        case minify = "Minify"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Format type picker
                Picker("Format", selection: $selectedFormat) {
                    ForEach(FormatType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Input")
                        .font(.headline)
                    TextEditor(text: $inputText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 140)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.separator), lineWidth: 0.5)
                        )
                }
                .padding(.horizontal)

                if let error = errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                Button {
                    format()
                } label: {
                    Label("Format", systemImage: "text.alignleft")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                // Output
                if !formattedText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Formatted")
                                .font(.headline)
                            Spacer()
                            Button {
                                ClipboardManager.shared.copy(formattedText, source: "Formatter")
                                copied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                            } label: {
                                Label(copied ? "Copied!" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        ScrollView(.horizontal, showsIndicators: true) {
                            Text(formattedText)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .padding()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Code Formatter")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func format() {
        errorMessage = nil
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch selectedFormat {
        case .json:
            formattedText = formatJSON(text)
        case .xml:
            formattedText = formatXML(text)
        case .minify:
            formattedText = minify(text)
        }
    }

    private func formatJSON(_ text: String) -> String {
        guard let data = text.data(using: .utf8) else {
            errorMessage = "Invalid text encoding"
            return ""
        }
        do {
            let obj = try JSONSerialization.jsonObject(with: data)
            let pretty = try JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys])
            return String(data: pretty, encoding: .utf8) ?? text
        } catch {
            errorMessage = "Invalid JSON: \(error.localizedDescription)"
            return ""
        }
    }

    private func formatXML(_ text: String) -> String {
        // Simple XML indentation
        var result = ""
        var indent = 0
        var inTag = false
        var i = text.startIndex

        while i < text.endIndex {
            let ch = text[i]
            if ch == "<" {
                if text.index(after: i) < text.endIndex && text[text.index(after: i)] == "/" {
                    indent = max(0, indent - 1)
                }
                if !result.isEmpty && result.last != "\n" {
                    result += "\n"
                }
                result += String(repeating: "  ", count: indent)
                result.append(ch)
                inTag = true
            } else if ch == ">" {
                result.append(ch)
                inTag = false
                // Check if this was an opening tag (not self-closing or closing)
                let tagContent = extractLastTag(from: result)
                if !tagContent.hasPrefix("/") && !tagContent.hasSuffix("/") {
                    indent += 1
                }
            } else {
                result.append(ch)
            }
            i = text.index(after: i)
        }
        return result
    }

    private func extractLastTag(from text: String) -> String {
        guard let openIdx = text.lastIndex(of: "<") else { return "" }
        let start = text.index(after: openIdx)
        let end = text.endIndex
        return String(text[start..<end]).trimmingCharacters(in: CharacterSet(charactersIn: "<> "))
    }

    private func minify(_ text: String) -> String {
        // Remove extra whitespace, newlines
        let lines = text.components(separatedBy: .newlines)
        return lines.map { $0.trimmingCharacters(in: .whitespaces) }.joined()
    }
}
