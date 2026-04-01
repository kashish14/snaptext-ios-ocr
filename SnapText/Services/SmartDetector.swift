import Foundation

struct DetectedEntity: Identifiable, Hashable {
    let id = UUID()
    let type: EntityType
    let value: String

    enum EntityType: String, Hashable {
        case phoneNumber
        case url
        case email
        case address
        case otp
    }

    var actionLabel: String {
        switch type {
        case .phoneNumber: return "Call \(value)"
        case .url: return "Open Link"
        case .email: return "Send Email"
        case .address: return "Open in Maps"
        case .otp: return "Copy OTP: \(value)"
        }
    }

    var iconName: String {
        switch type {
        case .phoneNumber: return "phone.fill"
        case .url: return "link"
        case .email: return "envelope.fill"
        case .address: return "map.fill"
        case .otp: return "lock.shield.fill"
        }
    }
}

final class SmartDetector {

    private static let otpPattern = try! NSRegularExpression(
        pattern: #"(?<!\d)\d{4,8}(?!\d)"#,
        options: []
    )

    private static let otpKeywords = [
        "otp", "code", "verify", "verification", "pin",
        "password", "passcode", "one.time", "one-time", "2fa"
    ]

    /// Detects smart entities (OTPs, phone numbers, links, emails, addresses) in text.
    func detect(in text: String) -> [DetectedEntity] {
        var entities: [DetectedEntity] = []

        // OTP detection first (highest priority — time-sensitive)
        entities.append(contentsOf: detectOTPs(in: text))

        // NSDataDetector for phone, links, emails, addresses
        let types: NSTextCheckingResult.CheckingType = [
            .phoneNumber, .link, .address
        ]

        guard let detector = try? NSDataDetector(types: types.rawValue) else {
            return entities
        }

        let range = NSRange(text.startIndex..., in: text)
        let matches = detector.matches(in: text, options: [], range: range)

        for match in matches {
            guard let matchRange = Range(match.range, in: text) else { continue }
            let value = String(text[matchRange])

            switch match.resultType {
            case .phoneNumber:
                entities.append(DetectedEntity(type: .phoneNumber, value: value))
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
                entities.append(DetectedEntity(type: .address, value: value))
            default:
                break
            }
        }

        return entities
    }

    private func detectOTPs(in text: String) -> [DetectedEntity] {
        let lowered = text.lowercased()
        let hasKeyword = Self.otpKeywords.contains { lowered.contains($0) }
        guard hasKeyword else { return [] }

        let range = NSRange(text.startIndex..., in: text)
        let matches = Self.otpPattern.matches(in: text, options: [], range: range)

        return matches.compactMap { match in
            guard let r = Range(match.range, in: text) else { return nil }
            return DetectedEntity(type: .otp, value: String(text[r]))
        }
    }
}
