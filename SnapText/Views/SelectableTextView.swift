import SwiftUI
import UIKit

/// A UITextView wrapper that displays OCR text with clean formatting
/// and supports native text selection (cursor, handles, copy menu).
struct SelectableTextView: UIViewRepresentable {
    let text: String

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        textView.dataDetectorTypes = []
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.attributedText = Self.formatText(text)
    }

    /// Formats raw OCR text into clean, readable attributed string.
    /// Groups lines into paragraphs with proper spacing.
    private static func formatText(_ raw: String) -> NSAttributedString {
        let lines = raw.components(separatedBy: "\n")
        let result = NSMutableAttributedString()

        let bodyFont = UIFont.preferredFont(forTextStyle: .body)

        // Paragraph style with comfortable line spacing
        let bodyParagraph = NSMutableParagraphStyle()
        bodyParagraph.lineSpacing = 4
        bodyParagraph.paragraphSpacing = 2

        // Paragraph break style (for visual gaps between blocks)
        let blockBreakParagraph = NSMutableParagraphStyle()
        blockBreakParagraph.lineSpacing = 4
        blockBreakParagraph.paragraphSpacingBefore = 12
        blockBreakParagraph.paragraphSpacing = 2

        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: UIColor.label,
            .paragraphStyle: bodyParagraph,
        ]

        var previousLineWasEmpty = false
        var isFirstLine = true

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip consecutive empty lines
            if trimmed.isEmpty {
                previousLineWasEmpty = true
                continue
            }

            // Determine if this line starts a new visual block
            let startsNewBlock = previousLineWasEmpty && !isFirstLine

            var attrs = bodyAttrs

            // Apply block break spacing
            if startsNewBlock {
                let blockParagraph = NSMutableParagraphStyle()
                blockParagraph.lineSpacing = 4
                blockParagraph.paragraphSpacingBefore = 12
                blockParagraph.paragraphSpacing = 2
                attrs[.paragraphStyle] = blockParagraph
            }

            // Detect if line looks like a heading (short, all caps, or ends with colon)
            let isHeading = isHeadingLike(trimmed)
            if isHeading {
                attrs[.font] = UIFont.preferredFont(forTextStyle: .headline)
            }

            // Detect if line looks like a label:value pair
            if let colonIdx = trimmed.firstIndex(of: ":"), colonIdx != trimmed.startIndex {
                let label = String(trimmed[trimmed.startIndex..<colonIdx])
                let value = String(trimmed[trimmed.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)

                if !label.isEmpty && !value.isEmpty && label.count < 30 {
                    let lineStr = NSMutableAttributedString()

                    var labelAttrs = attrs
                    labelAttrs[.font] = UIFont.preferredFont(forTextStyle: .subheadline).bold()
                    labelAttrs[.foregroundColor] = UIColor.secondaryLabel
                    lineStr.append(NSAttributedString(string: label + ": ", attributes: labelAttrs))

                    var valueAttrs = attrs
                    valueAttrs[.paragraphStyle] = bodyParagraph // reset paragraph for value
                    lineStr.append(NSAttributedString(string: value, attributes: valueAttrs))

                    if !isFirstLine {
                        result.append(NSAttributedString(string: "\n"))
                    }
                    result.append(lineStr)
                    previousLineWasEmpty = false
                    isFirstLine = false
                    continue
                }
            }

            if !isFirstLine {
                result.append(NSAttributedString(string: "\n"))
            }
            result.append(NSAttributedString(string: trimmed, attributes: attrs))

            previousLineWasEmpty = false
            isFirstLine = false
        }

        return result
    }

    /// Heuristic: line looks like a heading if it's short, mostly uppercase, or ends with ":"
    private static func isHeadingLike(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .punctuationCharacters)
        if trimmed.count > 50 { return false }

        // Short all-caps line
        let letters = trimmed.filter { $0.isLetter }
        if !letters.isEmpty && letters == letters.uppercased() && letters.count >= 3 && trimmed.count <= 40 {
            return true
        }

        // Ends with colon (label line)
        if line.hasSuffix(":") && line.count <= 40 {
            return true
        }

        return false
    }
}

// Helper to get bold variant of a font
private extension UIFont {
    func bold() -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(.traitBold) else { return self }
        return UIFont(descriptor: descriptor, size: 0)
    }
}
