import SwiftUI

struct ReceiptScannerView: View {
    @State private var showCamera = false
    @State private var showGallery = false
    @State private var isProcessing = false
    @State private var receiptInfo: ReceiptInfo?
    @State private var errorMessage: String?

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

    private func parseReceipt(text: String, image: UIImage) -> ReceiptInfo {
        let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let lowered = text.lowercased()

        // Merchant: usually the first non-empty line or one with address
        let merchant = lines.first { $0.count >= 3 && !$0.contains("$") && !$0.lowercased().contains("receipt") }

        // Total: look for keywords
        let totalPattern = try! NSRegularExpression(pattern: #"(?:total|grand total|amount due|net amount|payable)\s*[:=]?\s*[\$\u{20B9}]?\s*([\d,]+\.?\d{0,2})"#, options: [.caseInsensitive])
        let total = firstMatch(totalPattern, in: text, group: 0)?
            .trimmingCharacters(in: .whitespaces)

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
