import Foundation

/// Classifies scanned text into content types using rule-based heuristics.
/// No AI — pure pattern matching and statistical analysis.
final class ContentClassifier {

    struct Classification {
        let type: ContentType
        let confidence: Double // 0.0–1.0
        let textDensity: TextDensity
        let hasTable: Bool
        let hasReceipt: Bool
        let hasJSON: Bool
        let hasCode: Bool
    }

    enum TextDensity {
        case none       // 0 words
        case minimal    // 1–5 words
        case low        // 6–20 words
        case medium     // 21–100 words
        case high       // 101+ words
    }

    func classify(text: String, entities: [DetectedEntity]) -> Classification {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let lines = trimmed.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let wordCount = words.count
        let lineCount = lines.count

        let density = textDensity(wordCount: wordCount)
        let hasTable = detectTable(lines: lines)
        let hasReceipt = detectReceipt(text: trimmed, entities: entities)
        let hasJSON = detectJSON(text: trimmed)
        let hasCode = detectCode(text: trimmed, lines: lines)

        // Classification logic
        let type: ContentType
        let confidence: Double

        if hasReceipt {
            type = .receipt
            confidence = 0.85
        } else if hasTable {
            type = .receipt // tables use same action set as receipts
            confidence = 0.80
        } else if hasJSON || hasCode {
            type = .structured
            confidence = 0.90
        } else if density == .none || density == .minimal {
            type = .image
            confidence = density == .none ? 0.95 : 0.80
        } else if wordCount > 30 && lineCount > 3 {
            // Check if it looks like structured key-value data
            let kvRatio = keyValueRatio(lines: lines)
            if kvRatio > 0.5 {
                type = .structured
                confidence = 0.75
            } else {
                type = .document
                confidence = min(0.95, 0.6 + Double(wordCount) / 500.0)
            }
        } else if wordCount > 10 {
            type = .document
            confidence = 0.65
        } else {
            type = .mixed
            confidence = 0.50
        }

        return Classification(
            type: type,
            confidence: confidence,
            textDensity: density,
            hasTable: hasTable,
            hasReceipt: hasReceipt,
            hasJSON: hasJSON,
            hasCode: hasCode
        )
    }

    // MARK: - Density

    private func textDensity(wordCount: Int) -> TextDensity {
        switch wordCount {
        case 0: return .none
        case 1...5: return .minimal
        case 6...20: return .low
        case 21...100: return .medium
        default: return .high
        }
    }

    // MARK: - Table Detection

    private func detectTable(lines: [String]) -> Bool {
        guard lines.count >= 3 else { return false }

        // Check for consistent delimiters (tab, pipe, multiple spaces)
        var tabLines = 0
        var pipeLines = 0
        var multiSpaceLines = 0

        for line in lines {
            if line.contains("\t") { tabLines += 1 }
            if line.contains("|") { pipeLines += 1 }
            if line.range(of: #"\s{3,}"#, options: .regularExpression) != nil { multiSpaceLines += 1 }
        }

        let threshold = max(3, lines.count / 2)
        return tabLines >= threshold || pipeLines >= threshold || multiSpaceLines >= threshold
    }

    // MARK: - Receipt Detection

    private func detectReceipt(text: String, entities: [DetectedEntity]) -> Bool {
        let lowered = text.lowercased()
        let receiptKeywords = ["total", "subtotal", "tax", "gst", "receipt", "invoice",
                               "bill", "amount", "payment", "qty", "quantity", "price",
                               "item", "discount", "mrp", "net amount", "grand total"]

        let keywordCount = receiptKeywords.filter { lowered.contains($0) }.count
        let hasCurrency = entities.contains { $0.type == .currency }

        return keywordCount >= 3 || (keywordCount >= 2 && hasCurrency)
    }

    // MARK: - JSON Detection

    private func detectJSON(text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) ||
           (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) {
            // Quick validation
            if let data = trimmed.data(using: .utf8) {
                return (try? JSONSerialization.jsonObject(with: data)) != nil
            }
        }
        return false
    }

    // MARK: - Code Detection

    private func detectCode(text: String, lines: [String]) -> Bool {
        let codeIndicators = ["func ", "class ", "struct ", "import ", "var ", "let ",
                              "def ", "return ", "if (", "for (", "while (",
                              "function ", "const ", "=>", "->", "println", "print(",
                              "public ", "private ", "static "]
        let lowered = text.lowercased()
        let matchCount = codeIndicators.filter { lowered.contains($0.lowercased()) }.count

        // Also check for consistent indentation
        let indentedLines = lines.filter { $0.hasPrefix("  ") || $0.hasPrefix("\t") }.count
        let indentRatio = lines.isEmpty ? 0 : Double(indentedLines) / Double(lines.count)

        return matchCount >= 3 || (matchCount >= 2 && indentRatio > 0.4)
    }

    // MARK: - Key-Value Detection

    private func keyValueRatio(lines: [String]) -> Double {
        guard !lines.isEmpty else { return 0 }
        let kvPattern = try! NSRegularExpression(pattern: #"^.{1,30}\s*[:=\-]\s*.+"#)
        let kvCount = lines.filter { line in
            let range = NSRange(line.startIndex..., in: line)
            return kvPattern.firstMatch(in: line, range: range) != nil
        }.count
        return Double(kvCount) / Double(lines.count)
    }
}
