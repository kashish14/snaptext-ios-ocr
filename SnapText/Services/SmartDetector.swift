import Foundation

struct DetectedEntity: Identifiable, Hashable {
    let id = UUID()
    let type: EntityType
    let value: String
    /// Optional secondary value (e.g. wifi password, event time)
    let secondaryValue: String?

    init(type: EntityType, value: String, secondaryValue: String? = nil) {
        self.type = type
        self.value = value
        self.secondaryValue = secondaryValue
    }

    enum EntityType: String, Hashable, Identifiable, CaseIterable {
        case phoneNumber
        case address
        case email
        case url
        case date
        case upiId
        case trackingNumber
        case wifi
        case flightNumber
        case currency
        case socialHandle
        case ifscCode
        case panNumber
        case aadhaarNumber
        case gstNumber
        case coordinates
        case orderId
        case ipAddress
        case bankAccount

        var id: String { rawValue }
    }

    var actionLabel: String {
        switch type {
        case .phoneNumber: return "Call \(value)"
        case .url: return "Open Link"
        case .email: return "Send Email"
        case .address: return "Open in Maps"
        case .date: return value
        case .upiId: return value
        case .trackingNumber: return value
        case .wifi: return value
        case .flightNumber: return value
        case .currency: return value
        case .socialHandle: return value
        case .ifscCode: return value
        case .panNumber: return value
        case .aadhaarNumber: return value
        case .gstNumber: return value
        case .coordinates: return value
        case .orderId: return value
        case .ipAddress: return value
        case .bankAccount: return value
        }
    }

    var iconName: String {
        switch type {
        case .phoneNumber: return "phone.fill"
        case .url: return "link"
        case .email: return "envelope.fill"
        case .address: return "map.fill"
        case .date: return "calendar"
        case .upiId: return "indianrupeesign.circle.fill"
        case .trackingNumber: return "shippingbox.fill"
        case .wifi: return "wifi"
        case .flightNumber: return "airplane"
        case .currency: return "banknote.fill"
        case .socialHandle: return "at"
        case .ifscCode: return "building.columns.fill"
        case .panNumber: return "creditcard.fill"
        case .aadhaarNumber: return "person.text.rectangle.fill"
        case .gstNumber: return "doc.text.fill"
        case .coordinates: return "location.fill"
        case .orderId: return "bag.fill"
        case .ipAddress: return "network"
        case .bankAccount: return "banknote.fill"
        }
    }
}

// MARK: - Smart Detector

final class SmartDetector {

    // MARK: - Regex Patterns

    // Phone: +91 98765 43210, (123) 456-7890, 123-456-7890, etc.
    private static let phonePattern = try! NSRegularExpression(
        pattern: #"(?<!\d)(?:\+?\d{1,3}[\s.-]?)?(?:\(?\d{2,5}\)?[\s.-]?)?\d{3,5}[\s.-]?\d{3,5}(?!\d)"#
    )

    // UPI: user@bank format — common UPI handles
    private static let upiPattern = try! NSRegularExpression(
        pattern: #"[a-zA-Z0-9._-]+@(?:ybl|paytm|oksbi|okicici|okaxis|upi|ibl|sbi|apl|axisbank|icici|hdfcbank|kotak|indus|barodampay|unionbankofindia|federal|rbl|citi|dbs|jio|slice|freecharge|airtel|postbank|equitas|yesbank|hsbc|kvb|idfc|idbi|scb|pnb|cnrb|iob|boi|lvb)"#,
        options: [.caseInsensitive]
    )

    // Tracking: courier/order tracking numbers — explicit label patterns
    private static let trackingPattern = try! NSRegularExpression(
        pattern: #"(?:AWB|TRK|TRACK(?:ING)?|SHIP(?:MENT)?|CONSIGNMENT|WAYBILL|DOCKET|AIR\s*WAYBILL)[\s:.\-#No.]*([A-Z0-9]{6,22})"#,
        options: [.caseInsensitive]
    )
    // Common courier-specific patterns
    private static let courierPatterns = [
        try! NSRegularExpression(pattern: #"\b\d{8,11}\b"#),          // BlueDart, DTDC (8-11 digits)
        try! NSRegularExpression(pattern: #"\b\d{12,14}\b"#),          // Delhivery, India Post (12-14 digits)
        try! NSRegularExpression(pattern: #"\b[A-Z]{2}\d{9}[A-Z]{2}\b"#), // International postal (EE123456789IN)
        try! NSRegularExpression(pattern: #"\b1Z[A-Z0-9]{16}\b"#),     // UPS
        try! NSRegularExpression(pattern: #"\b\d{20,22}\b"#),          // FedEx (20-22 digits)
        try! NSRegularExpression(pattern: #"\b[A-Z]\d{9,11}\b"#),      // DTDC, Ekart (letter + 9-11 digits)
        try! NSRegularExpression(pattern: #"\b\d{4}\s?\d{4}\s?\d{4}\b"#), // Spaced 12-digit (India Post)
    ]
    // Keywords that indicate tracking context
    private static let trackingKeywords = [
        "tracking", "awb", "shipment", "courier", "consignment", "waybill",
        "docket", "delivery", "dispatched", "shipped", "out for delivery",
        "delhivery", "bluedart", "blue dart", "dtdc", "ecom express", "fedex", "dhl",
        "india post", "speed post", "ekart", "xpressbees", "shadowfax",
        "air waybill", "booking ref", "parcel", "package", "dispatch",
        "sender", "receiver", "consignee", "origin", "destination",
        "weight", "pieces", "pcs", "pickup"
    ]

    // Wifi SSID and password
    private static let wifiSSIDPattern = try! NSRegularExpression(
        pattern: #"(?:SSID|Wi-?Fi|Network(?:\s*Name)?)\s*[:=]\s*(.+?)(?:\n|$)"#,
        options: [.caseInsensitive]
    )
    private static let wifiPasswordPattern = try! NSRegularExpression(
        pattern: #"(?:Pass(?:word|key|phrase)?|Key|PSK|WPA|WEP)\s*[:=]\s*(.+?)(?:\n|$)"#,
        options: [.caseInsensitive]
    )

    // Flight: 2-letter airline code + 1-4 digit number
    private static let flightPattern = try! NSRegularExpression(
        pattern: #"\b(?:AI|6E|SG|UK|IX|QP|I5|G8|S5|AA|UA|DL|BA|EK|QR|SQ|LH|AF|KL|TK|QF|CX|NH|JL|AC|WS|FR|EI|VS|LX)\s?\d{1,4}\b"#,
        options: [.caseInsensitive]
    )

    // Currency: $49.99, Rs 1,500, EUR 120, INR 5000, etc.
    private static let currencyPattern = try! NSRegularExpression(
        pattern: #"(?:(?:Rs\.?|INR|USD|\$|EUR|€|GBP|£|¥|JPY|AUD|CAD|SGD|AED|SAR|MRP)\s*[\d,]+(?:\.\d{1,2})?)|(?:[\d,]+(?:\.\d{1,2})?\s*(?:Rs\.?|INR|USD|EUR|GBP|JPY|AUD|CAD|SGD|AED|SAR|rupees|dollars))"#,
        options: [.caseInsensitive]
    )

    // Social handles: @username (Twitter/Insta style)
    private static let socialHandlePattern = try! NSRegularExpression(
        pattern: #"(?<![a-zA-Z0-9.])@([a-zA-Z_][a-zA-Z0-9_.]{1,29})\b"#
    )

    // IFSC: 4 letter bank code + 0 + 6 alphanumeric
    private static let ifscPattern = try! NSRegularExpression(
        pattern: #"\b[A-Z]{4}0[A-Z0-9]{6}\b"#
    )

    // PAN: 5 uppercase + 4 digits + 1 uppercase
    private static let panPattern = try! NSRegularExpression(
        pattern: #"\b[A-Z]{5}\d{4}[A-Z]\b"#
    )

    // Aadhaar: 4-4-4 digit format or 12 consecutive digits
    private static let aadhaarPattern = try! NSRegularExpression(
        pattern: #"\b\d{4}\s\d{4}\s\d{4}\b"#
    )

    // GST: 2 digit state + PAN + 1 alphanumeric + Z + 1 alphanumeric
    private static let gstPattern = try! NSRegularExpression(
        pattern: #"\b\d{2}[A-Z]{5}\d{4}[A-Z][A-Z0-9]Z[A-Z0-9]\b"#
    )

    // Coordinates: lat,long format
    private static let coordinatesPattern = try! NSRegularExpression(
        pattern: #"(?<!\d)-?\d{1,3}\.\d{3,8}\s*[,/]\s*-?\d{1,3}\.\d{3,8}(?!\d)"#
    )

    // Order ID: various e-commerce formats
    private static let orderIdPattern = try! NSRegularExpression(
        pattern: #"(?:Order|ORD|OD|Invoice|INV|Booking|TXN|Transaction)[\s#:.\-]*([A-Z0-9\-]{5,25})"#,
        options: [.caseInsensitive]
    )

    // IP Address: IPv4
    private static let ipv4Pattern = try! NSRegularExpression(
        pattern: #"\b(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\.(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\.(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\.(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\b"#
    )

    // Bank Account: 9-18 digit numbers near keywords
    private static let bankAccountKeywords = ["a/c", "account", "acct", "bank a/c", "saving", "current"]

    // Date patterns: various formats
    private static let datePatterns = [
        // 15 Apr 2026, 15th April 2026
        try! NSRegularExpression(
            pattern: #"\b\d{1,2}(?:st|nd|rd|th)?\s+(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+\d{2,4}\b"#,
            options: [.caseInsensitive]
        ),
        // Apr 15, 2026
        try! NSRegularExpression(
            pattern: #"\b(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+\d{1,2}(?:st|nd|rd|th)?,?\s+\d{2,4}\b"#,
            options: [.caseInsensitive]
        ),
        // 15/04/2026 or 2026-04-15 or 15.04.2026
        try! NSRegularExpression(
            pattern: #"\b\d{1,4}[/.-]\d{1,2}[/.-]\d{1,4}\b"#
        ),
    ]

    // Time patterns for dates
    private static let timePattern = try! NSRegularExpression(
        pattern: #"\b\d{1,2}:\d{2}\s*(?:AM|PM|am|pm|hrs|h)?\b"#
    )

    // MARK: - Main Detection

    func detect(in text: String) -> [DetectedEntity] {
        var entities: [DetectedEntity] = []
        let lowered = text.lowercased()

        // 1. NSDataDetector for phone, links, emails, addresses
        var detectedPhoneValues = Set<String>()
        var detectedAddressValues = Set<String>()

        if let detector = try? NSDataDetector(types: (
            NSTextCheckingResult.CheckingType.phoneNumber.rawValue |
            NSTextCheckingResult.CheckingType.link.rawValue |
            NSTextCheckingResult.CheckingType.address.rawValue
        )) {
            let range = NSRange(text.startIndex..., in: text)
            let matches = detector.matches(in: text, options: [], range: range)

            for match in matches {
                guard let matchRange = Range(match.range, in: text) else { continue }
                let value = String(text[matchRange])

                switch match.resultType {
                case .phoneNumber:
                    let normalized = value.filter { $0.isNumber || $0 == "+" }
                    if !detectedPhoneValues.contains(normalized) {
                        detectedPhoneValues.insert(normalized)
                        entities.append(DetectedEntity(type: .phoneNumber, value: value))
                    }
                case .link:
                    if let url = match.url {
                        if url.scheme == "mailto" {
                            let email = url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
                            entities.append(DetectedEntity(type: .email, value: email))
                        } else {
                            entities.append(DetectedEntity(type: .url, value: url.absoluteString))
                        }
                    }
                case .address:
                    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    detectedAddressValues.insert(trimmed)
                    entities.append(DetectedEntity(type: .address, value: trimmed))
                default:
                    break
                }
            }
        }

        // 2. Phone regex fallback
        for phone in regexMatches(Self.phonePattern, in: text) {
            let normalized = phone.filter { $0.isNumber || $0 == "+" }
            if normalized.count >= 7, normalized.count <= 15,
               !detectedPhoneValues.contains(normalized) {
                detectedPhoneValues.insert(normalized)
                entities.append(DetectedEntity(type: .phoneNumber, value: phone))
            }
        }

        // 3. Line-by-line address detection
        let lines = text.components(separatedBy: .newlines)
        if let addrDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.address.rawValue) {
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedLine.isEmpty else { continue }
                let lineRange = NSRange(trimmedLine.startIndex..., in: trimmedLine)
                for match in addrDetector.matches(in: trimmedLine, options: [], range: lineRange) {
                    guard let matchRange = Range(match.range, in: trimmedLine) else { continue }
                    let value = String(trimmedLine[matchRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !detectedAddressValues.contains(value) {
                        detectedAddressValues.insert(value)
                        entities.append(DetectedEntity(type: .address, value: value))
                    }
                }
            }
        }

        // 4. Dates
        entities.append(contentsOf: detectDates(in: text))

        // 5. UPI IDs
        for match in regexMatches(Self.upiPattern, in: text) {
            entities.append(DetectedEntity(type: .upiId, value: match))
        }

        // 6. Tracking Numbers
        entities.append(contentsOf: detectTracking(in: text, lowered: lowered))

        // 7. Wifi Credentials
        if let wifi = detectWifi(in: text) {
            entities.append(wifi)
        }

        // 8. Flight Numbers
        for match in regexMatches(Self.flightPattern, in: text) {
            entities.append(DetectedEntity(type: .flightNumber, value: match.uppercased()))
        }

        // 9. Currency
        for match in regexMatches(Self.currencyPattern, in: text) {
            entities.append(DetectedEntity(type: .currency, value: match))
        }

        // 10. Social Handles
        let detectedEmails = Set(entities.filter { $0.type == .email }.map { $0.value.lowercased() })
        let detectedUPIs = Set(entities.filter { $0.type == .upiId }.map { $0.value.lowercased() })
        for match in regexMatches(Self.socialHandlePattern, in: text) {
            let handle = match.hasPrefix("@") ? String(match.dropFirst()) : match
            // Skip if it's part of an already detected email or UPI ID
            let isEmail = detectedEmails.contains(where: { $0.contains(handle.lowercased()) })
            let isUPI = detectedUPIs.contains(where: { $0.hasPrefix(handle.lowercased()) })
            if !isEmail && !isUPI {
                entities.append(DetectedEntity(type: .socialHandle, value: match))
            }
        }

        // 11. IFSC Codes
        for match in regexMatches(Self.ifscPattern, in: text) {
            entities.append(DetectedEntity(type: .ifscCode, value: match))
        }

        // 12. PAN Numbers
        for match in regexMatches(Self.panPattern, in: text) {
            // Avoid false positives with IFSC (already detected)
            let isIFSC = entities.contains { $0.type == .ifscCode && $0.value.contains(match) }
            let isGST = entities.contains { $0.type == .gstNumber && $0.value.contains(match) }
            if !isIFSC && !isGST {
                entities.append(DetectedEntity(type: .panNumber, value: match))
            }
        }

        // 13. Aadhaar Numbers
        for match in regexMatches(Self.aadhaarPattern, in: text) {
            entities.append(DetectedEntity(type: .aadhaarNumber, value: match))
        }

        // 14. GST Numbers
        for match in regexMatches(Self.gstPattern, in: text) {
            entities.append(DetectedEntity(type: .gstNumber, value: match))
        }

        // 15. Coordinates
        for match in regexMatches(Self.coordinatesPattern, in: text) {
            entities.append(DetectedEntity(type: .coordinates, value: match))
        }

        // 16. Order IDs (exclude already-detected tracking numbers)
        let trackingValues = Set(entities.filter { $0.type == .trackingNumber }.map { $0.value })
        entities.append(contentsOf: detectOrderIds(in: text, excludeTracking: trackingValues))

        // 17. IP Addresses
        for match in regexMatches(Self.ipv4Pattern, in: text) {
            entities.append(DetectedEntity(type: .ipAddress, value: match))
        }

        // 18. Bank Account Numbers (exclude already-detected values)
        let allDetectedValues = Set(entities.map { $0.value })
        entities.append(contentsOf: detectBankAccounts(in: text, lowered: lowered, exclude: allDetectedValues))

        return entities
    }

    // MARK: - Specialized Detectors

    /// Represents a raw date match with its position in the source text
    private struct DateMatch {
        let value: String
        let date: Date?
        let location: Int   // NSRange.location in the source text
        let length: Int     // NSRange.length
    }

    private func detectDates(in text: String) -> [DetectedEntity] {
        var rawMatches: [DateMatch] = []
        var coveredRanges: [NSRange] = []

        // NSDataDetector — gives us both the matched text AND the parsed Date
        if let dateDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let fullRange = NSRange(text.startIndex..., in: text)
            for match in dateDetector.matches(in: text, options: [], range: fullRange) {
                guard let matchRange = Range(match.range, in: text) else { continue }
                let value = String(text[matchRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                guard value.count >= 4 else { continue }
                rawMatches.append(DateMatch(value: value, date: match.date, location: match.range.location, length: match.range.length))
                coveredRanges.append(match.range)
            }
        }

        // Regex fallback for dates NSDataDetector missed
        for pattern in Self.datePatterns {
            let fullRange = NSRange(text.startIndex..., in: text)
            for match in pattern.matches(in: text, options: [], range: fullRange) {
                guard let r = Range(match.range, in: text) else { continue }
                let value = String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
                // Skip if already covered by NSDataDetector
                let overlaps = coveredRanges.contains { NSIntersectionRange($0, match.range).length > 0 }
                if !overlaps {
                    rawMatches.append(DateMatch(value: value, date: nil, location: match.range.location, length: match.range.length))
                    coveredRanges.append(match.range)
                }
            }
        }

        guard !rawMatches.isEmpty else { return [] }

        // Sort by position in text
        rawMatches.sort { $0.location < $1.location }

        // Merge adjacent date + time fragments that are within 20 characters of each other
        // e.g. "15 Apr 2026" at pos 10 and "3:00 PM" at pos 25 → "15 Apr 2026, 3:00 PM"
        var merged: [DetectedEntity] = []
        var i = 0
        while i < rawMatches.count {
            var combined = rawMatches[i]
            // Try to absorb the next match if it's close by (within 20 chars gap)
            while i + 1 < rawMatches.count {
                let next = rawMatches[i + 1]
                let gap = next.location - (combined.location + combined.length)
                if gap <= 20 {
                    // Grab the full text span including the gap
                    let startIdx = text.index(text.startIndex, offsetBy: combined.location)
                    let endIdx = text.index(text.startIndex, offsetBy: next.location + next.length)
                    let fullSpan = String(text[startIdx..<endIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let mergedDate = next.date ?? combined.date
                    combined = DateMatch(
                        value: fullSpan,
                        date: mergedDate,
                        location: combined.location,
                        length: next.location + next.length - combined.location
                    )
                    i += 1
                } else {
                    break
                }
            }
            merged.append(DetectedEntity(
                type: .date,
                value: combined.value,
                secondaryValue: combined.date.map { ISO8601DateFormatter().string(from: $0) }
            ))
            i += 1
        }

        // Deduplicate
        var seen = Set<String>()
        return merged.filter { seen.insert($0.value).inserted }
    }

    private func detectTracking(in text: String, lowered: String) -> [DetectedEntity] {
        var results: [DetectedEntity] = []
        var detectedValues = Set<String>()

        // Collect phone numbers to exclude from tracking (avoid false positives)
        var phoneNumbers = Set<String>()
        for phone in regexMatches(Self.phonePattern, in: text) {
            phoneNumbers.insert(phone.filter { $0.isNumber })
        }

        // Helper: skip values that look like phone numbers, pin codes, or dates
        func isValidTracking(_ val: String) -> Bool {
            let digits = val.filter { $0.isNumber }
            // Skip 6-digit values (likely pin codes)
            if digits.count == 6, val.allSatisfy({ $0.isNumber || $0 == " " }) { return false }
            // Skip if it matches a detected phone number
            if phoneNumbers.contains(digits) { return false }
            return true
        }

        // 1. Explicit tracking patterns (AWB:, TRK:, TRACKING:, etc.) — always match
        for match in regexGroupMatches(Self.trackingPattern, in: text, group: 1) {
            if detectedValues.insert(match).inserted && isValidTracking(match) {
                results.append(DetectedEntity(type: .trackingNumber, value: match))
            }
        }

        let hasKeyword = Self.trackingKeywords.contains(where: { lowered.contains($0) })

        if hasKeyword {
            // 2. Courier-specific patterns
            for pattern in Self.courierPatterns {
                for match in regexMatches(pattern, in: text) {
                    let cleaned = match.replacingOccurrences(of: " ", with: "")
                    if detectedValues.insert(cleaned).inserted && isValidTracking(cleaned) {
                        results.append(DetectedEntity(type: .trackingNumber, value: cleaned))
                    }
                }
            }

            // 3. Generic long alphanumeric near tracking keywords
            let genericPattern = try! NSRegularExpression(pattern: #"\b[A-Z0-9]{10,22}\b"#)
            for match in regexMatches(genericPattern, in: text) {
                if detectedValues.insert(match).inserted && isValidTracking(match) {
                    results.append(DetectedEntity(type: .trackingNumber, value: match))
                }
            }
        }

        return results
    }

    private func detectWifi(in text: String) -> DetectedEntity? {
        let ssid = regexGroupMatches(Self.wifiSSIDPattern, in: text, group: 1).first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let password = regexGroupMatches(Self.wifiPasswordPattern, in: text, group: 1).first?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let ssid, !ssid.isEmpty {
            return DetectedEntity(type: .wifi, value: ssid, secondaryValue: password)
        } else if let password, !password.isEmpty {
            return DetectedEntity(type: .wifi, value: "Wifi Password", secondaryValue: password)
        }
        return nil
    }

    private func detectOrderIds(in text: String, excludeTracking: Set<String> = []) -> [DetectedEntity] {
        regexGroupMatches(Self.orderIdPattern, in: text, group: 1).compactMap { match in
            guard !excludeTracking.contains(match) else { return nil }
            return DetectedEntity(type: .orderId, value: match)
        }
    }

    private func detectBankAccounts(in text: String, lowered: String, exclude: Set<String>) -> [DetectedEntity] {
        guard Self.bankAccountKeywords.contains(where: { lowered.contains($0) }) else { return [] }
        let pattern = try! NSRegularExpression(pattern: #"\b\d{9,18}\b"#)
        return regexMatches(pattern, in: text).compactMap { match in
            guard !exclude.contains(match) else { return nil }
            return DetectedEntity(type: .bankAccount, value: match)
        }
    }

    // MARK: - Regex Helpers

    private func regexMatches(_ regex: NSRegularExpression, in text: String) -> [String] {
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, options: [], range: range).compactMap { match in
            guard let r = Range(match.range, in: text) else { return nil }
            return String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func regexGroupMatches(_ regex: NSRegularExpression, in text: String, group: Int) -> [String] {
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, options: [], range: range).compactMap { match in
            guard match.numberOfRanges > group,
                  let r = Range(match.range(at: group), in: text) else { return nil }
            return String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
