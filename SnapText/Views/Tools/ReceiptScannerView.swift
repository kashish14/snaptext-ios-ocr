import SwiftUI

struct ReceiptScannerView: View {
    @Environment(\.toolContext) private var toolContext
    @State private var showCamera = false
    @State private var showGallery = false
    @State private var isProcessing = false
    @State private var receiptInfo: ReceiptInfo?
    @State private var errorMessage: String?
    @State private var didApplyContext = false
    @State private var splitCount = 2
    @State private var showSplit = false
    @State private var manualTotal = ""

    private let ocrService = OCRService()

    var body: some View {
        VStack(spacing: 0) {
            if let info = receiptInfo {
                receiptResultView(info)
            } else {
                emptyState
            }
        }
        .navigationTitle("Receipt Scanner")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !didApplyContext, let img = toolContext.image, img.size.width > 0 {
                didApplyContext = true
                Task { await scanReceipt(img) }
            } else if !didApplyContext, let text = toolContext.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                didApplyContext = true
                receiptInfo = parseReceipt(text: text, image: nil)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { image in
                Task { await scanReceipt(image) }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showGallery) {
            ImagePicker { image in
                Task { await scanReceipt(image) }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 24) {
                Image(systemName: "receipt")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                VStack(spacing: 8) {
                    Text("Receipt Scanner")
                        .font(.title2.bold())
                    Text("Extract merchant, total, date, and items from receipts")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                if isProcessing { ProgressView("Scanning...") }
                if let error = errorMessage {
                    Text(error).font(.callout).foregroundStyle(.red)
                }
            }
            .padding(.horizontal)
            Spacer()

            HStack(spacing: 12) {
                Button { showCamera = true } label: {
                    Label("Camera", systemImage: "camera.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)

                Button { showGallery = true } label: {
                    Label("Gallery", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).controlSize(.large)
            }
            .padding(.horizontal).padding(.bottom, 16)
        }
    }

    private func receiptResultView(_ info: ReceiptInfo) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                if let img = info.image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 4)
                }

                // Key fields
                VStack(spacing: 0) {
                    if let merchant = info.merchant {
                        receiptField(icon: "storefront.fill", label: "Merchant", value: merchant)
                    }
                    if let date = info.date {
                        receiptField(icon: "calendar", label: "Date", value: date)
                    }
                    if let total = info.total {
                        receiptField(icon: "indianrupeesign.circle.fill", label: "Total", value: total, highlight: true)
                    }
                    if let subtotal = info.subtotal {
                        receiptField(icon: "number", label: "Subtotal", value: subtotal)
                    }
                    if let tax = info.tax {
                        receiptField(icon: "percent", label: "Tax", value: tax)
                    }
                    if let paymentMethod = info.paymentMethod {
                        receiptField(icon: "creditcard.fill", label: "Payment", value: paymentMethod)
                    }
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                // Items
                if !info.lineItems.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Items")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(info.lineItems, id: \.self) { item in
                            Text(item)
                                .font(.subheadline)
                                .padding(.horizontal)
                                .padding(.vertical, 4)
                        }
                    }
                }

                // Bill Split — always show, with manual entry fallback
                billSplitSection(totalStr: info.total)

                // Full text
                VStack(alignment: .leading, spacing: 8) {
                    Text("Full Text")
                        .font(.headline)
                        .padding(.horizontal)

                    SelectableTextView(text: info.fullText)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                }

                // Actions
                VStack(spacing: 12) {
                    Button {
                        let summary = info.summaryText
                        ClipboardManager.shared.copy(summary, source: "Receipt")
                    } label: {
                        Label("Copy Summary", systemImage: "doc.on.doc.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large)

                    ShareLink(item: info.summaryText) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).controlSize(.large)

                    HStack(spacing: 12) {
                        Button { showCamera = true } label: {
                            Label("Re-scan", systemImage: "camera.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered).controlSize(.large)

                        Button(role: .destructive) { receiptInfo = nil } label: {
                            Label("Clear", systemImage: "trash").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered).controlSize(.large)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .padding(.vertical)
        }
    }

    private func receiptField(icon: String, label: String, value: String, highlight: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(highlight ? .green : Color.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Text(value)
                    .font(highlight ? .title3.bold() : .body)
                    .foregroundStyle(highlight ? .green : .primary)
            }
            Spacer()

            Button { ClipboardManager.shared.copy(value, source: "Receipt") } label: {
                Image(systemName: "doc.on.doc").font(.caption).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private func billSplitSection(totalStr: String?) -> some View {
        VStack(spacing: 10) {
            Button {
                withAnimation { showSplit.toggle() }
            } label: {
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(.blue)
                    Text("Split Bill")
                        .font(.headline)
                    Spacer()
                    Image(systemName: showSplit ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }
            .buttonStyle(.plain)

            if showSplit {
                VStack(spacing: 12) {
                    // If no total detected, show manual entry
                    if totalStr == nil || extractAmount(from: totalStr ?? "") <= 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Enter Total Amount")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("e.g. 1250.00", text: $manualTotal)
                                .keyboardType(.decimalPad)
                                .padding(10)
                                .background(Color(.tertiarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    } else if let t = totalStr {
                        HStack {
                            Text("Total")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(t)
                                .font(.headline.bold())
                        }
                    }

                    HStack(spacing: 16) {
                        Text("People")
                            .font(.subheadline)
                        Spacer()
                        HStack(spacing: 0) {
                            Button {
                                if splitCount > 2 { splitCount -= 1 }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(splitCount > 2 ? .blue : .gray)
                            }
                            .disabled(splitCount <= 2)

                            Text("\(splitCount)")
                                .font(.title3.bold().monospaced())
                                .frame(width: 44)

                            Button {
                                if splitCount < 20 { splitCount += 1 }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }

                    let amount = splitAmount(totalStr: totalStr)
                    if amount > 0 {
                        Divider()

                        HStack {
                            Text("Per person")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "\u{20B9}%.2f", amount / Double(splitCount)))
                                .font(.title2.bold())
                                .foregroundStyle(.green)
                        }

                        Button {
                            let totalLabel = totalStr ?? "\u{20B9}\(manualTotal)"
                            let text = "Bill split: \(totalLabel) \u{00F7} \(splitCount) = \(String(format: "\u{20B9}%.2f", amount / Double(splitCount))) per person"
                            ClipboardManager.shared.copy(text, source: "Receipt")
                        } label: {
                            Label("Copy Split", systemImage: "doc.on.doc")
                                .font(.caption.weight(.medium))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
        }
    }

    private func splitAmount(totalStr: String?) -> Double {
        if let t = totalStr {
            let amt = extractAmount(from: t)
            if amt > 0 { return amt }
        }
        return Double(manualTotal) ?? 0
    }

    private func extractAmount(from text: String) -> Double {
        // Extract numeric value from strings like "Total: Rs 1,234.50" or "$49.99"
        let cleaned = text.replacingOccurrences(of: ",", with: "")
        let pattern = try! NSRegularExpression(pattern: #"[\d]+\.?\d{0,2}"#)
        let range = NSRange(cleaned.startIndex..., in: cleaned)
        let matches = pattern.matches(in: cleaned, range: range)

        // Take the last number (usually the amount)
        if let last = matches.last, let r = Range(last.range, in: cleaned) {
            return Double(cleaned[r]) ?? 0
        }
        return 0
    }

    private func scanReceipt(_ image: UIImage) async {
        isProcessing = true
        errorMessage = nil
        do {
            let text = try await ocrService.recognizeText(in: image, mode: .accurate)
            let info = parseReceipt(text: text, image: image)
            await MainActor.run {
                receiptInfo = info
                isProcessing = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Could not scan receipt."
                isProcessing = false
            }
        }
    }

    private func parseReceipt(text: String, image: UIImage?) -> ReceiptInfo {
        let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let lowered = text.lowercased()

        // Merchant: usually the first non-empty line or one with address
        let merchant = lines.first { $0.count >= 3 && !$0.contains("$") && !$0.lowercased().contains("receipt") }

        // Total: look for keywords — try multiple patterns
        let totalPatterns = [
            #"(?:grand\s*total|amount\s*due|net\s*amount|payable|total\s*amount|total\s*due)\s*[:=\-]?\s*[Rs.₹$]?\s*([\d,]+\.?\d{0,2})"#,
            #"(?:total)\s*[:=\-]?\s*[Rs.₹$]?\s*([\d,]+\.?\d{0,2})"#,
            #"[Rs.₹$]\s*([\d,]+\.\d{2})\s*$"#,
        ]
        var total: String?
        for pattern in totalPatterns {
            let regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .anchorsMatchLines])
            if let match = firstMatch(regex, in: text, group: 0)?.trimmingCharacters(in: .whitespaces) {
                total = match
                break
            }
        }
        // Fallback: find the largest currency amount in text
        if total == nil {
            let fallbackPattern = try! NSRegularExpression(pattern: #"[Rs.₹$]?\s*([\d,]+\.\d{2})"#)
            let range = NSRange(text.startIndex..., in: text)
            let matches = fallbackPattern.matches(in: text, range: range)
            var largest: (String, Double) = ("", 0)
            for match in matches {
                if let r = Range(match.range, in: text) {
                    let str = String(text[r])
                    let num = extractAmount(from: str)
                    if num > largest.1 { largest = (str.trimmingCharacters(in: .whitespaces), num) }
                }
            }
            if largest.1 > 0 { total = largest.0 }
        }

        // Subtotal
        let subtotalPattern = try! NSRegularExpression(pattern: #"(?:subtotal|sub-total|sub total)\s*[:=]?\s*[\$\u{20B9}]?\s*([\d,]+\.?\d{0,2})"#, options: [.caseInsensitive])
        let subtotal = firstMatch(subtotalPattern, in: text, group: 0)?
            .trimmingCharacters(in: .whitespaces)

        // Tax
        let taxPattern = try! NSRegularExpression(pattern: #"(?:tax|gst|vat|cgst|sgst|igst)\s*[:=]?\s*[\$\u{20B9}]?\s*([\d,]+\.?\d{0,2})"#, options: [.caseInsensitive])
        let tax = firstMatch(taxPattern, in: text, group: 0)?
            .trimmingCharacters(in: .whitespaces)

        // Date
        let dateDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        var date: String?
        if let detector = dateDetector {
            let range = NSRange(text.startIndex..., in: text)
            if let match = detector.firstMatch(in: text, range: range),
               let r = Range(match.range, in: text) {
                date = String(text[r])
            }
        }

        // Payment method
        let paymentKeywords = ["cash", "card", "upi", "visa", "mastercard", "debit", "credit", "gpay", "phonepe", "paytm", "netbanking"]
        let paymentMethod = paymentKeywords.first { lowered.contains($0) }?.capitalized

        // Line items: lines with a price-like pattern
        let pricePattern = try! NSRegularExpression(pattern: #"[\$\u{20B9}]?\s*\d+[.,]\d{2}\b"#)
        let lineItems = lines.filter { line in
            let range = NSRange(line.startIndex..., in: line)
            return pricePattern.firstMatch(in: line, range: range) != nil &&
                   !line.lowercased().contains("total") &&
                   !line.lowercased().contains("subtotal") &&
                   !line.lowercased().contains("tax")
        }

        return ReceiptInfo(
            merchant: merchant,
            date: date,
            total: total,
            subtotal: subtotal,
            tax: tax,
            paymentMethod: paymentMethod,
            lineItems: lineItems,
            fullText: text,
            image: image
        )
    }

    private func firstMatch(_ regex: NSRegularExpression, in text: String, group: Int) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let r = Range(match.range(at: group), in: text) else { return nil }
        return String(text[r])
    }
}

private struct ReceiptInfo {
    let merchant: String?
    let date: String?
    let total: String?
    let subtotal: String?
    let tax: String?
    let paymentMethod: String?
    let lineItems: [String]
    let fullText: String
    let image: UIImage?

    var summaryText: String {
        var parts: [String] = []
        if let m = merchant { parts.append("Merchant: \(m)") }
        if let d = date { parts.append("Date: \(d)") }
        if let t = total { parts.append("Total: \(t)") }
        if let s = subtotal { parts.append("Subtotal: \(s)") }
        if let t = tax { parts.append("Tax: \(t)") }
        if let p = paymentMethod { parts.append("Payment: \(p)") }
        if !lineItems.isEmpty {
            parts.append("\nItems:")
            parts.append(contentsOf: lineItems)
        }
        return parts.joined(separator: "\n")
    }
}
