import SwiftUI
import NetworkExtension

/// The brain of the app. Takes content classification + entities → ranked actions.
/// Shows top 3–5 as Quick Actions, rest go to "Do More".
@MainActor
final class ActionPriorityEngine {

    private let classifier = ContentClassifier()
    private let behaviorTracker = UserBehaviorTracker.shared

    struct RankedResult {
        let contentType: ContentType
        let quickActions: [QuickAction]   // Top 3–5
        let doMoreActions: [QuickAction]  // Everything else, grouped
        let entityActions: [QuickAction]  // Direct entity actions (copy OTP, call, etc.)
    }

    /// Main entry: classify content, score actions, return ranked result.
    func rank(text: String, image: UIImage?, entities: [DetectedEntity]) -> RankedResult {
        let classification = classifier.classify(text: text, entities: entities)

        // 1. Build entity-driven direct actions
        let entityActions = buildEntityActions(entities: entities)

        // 2. Build all tool actions with base scores
        var allActions = buildToolActions(
            classification: classification,
            text: text,
            image: image,
            entities: entities
        )

        // 3. Apply detection boosts (entity presence overrides)
        applyDetectionBoosts(&allActions, entities: entities)

        // 4. Apply behavior boosts
        for i in allActions.indices {
            allActions[i].score += behaviorTracker.totalBoost(for: allActions[i].id)
        }

        // 5. Apply suppression rules
        let filtered = applySuppression(allActions, classification: classification)

        // 6. Sort descending by score
        let sorted = filtered.sorted { $0.score > $1.score }

        // 7. Split: top 5 = Quick Actions, rest = Do More
        let quickCount = min(5, max(3, sorted.count))
        let quick = Array(sorted.prefix(quickCount))
        let doMore = Array(sorted.dropFirst(quickCount))

        return RankedResult(
            contentType: classification.type,
            quickActions: quick,
            doMoreActions: doMore,
            entityActions: entityActions
        )
    }

    // MARK: - Entity Actions (direct, 1-tap)

    private func buildEntityActions(entities: [DetectedEntity]) -> [QuickAction] {
        var actions: [QuickAction] = []
        var seenTypes = Set<DetectedEntity.EntityType>()

        for entity in entities {
            // For each entity type, show first occurrence
            guard !seenTypes.contains(entity.type) else { continue }
            seenTypes.insert(entity.type)

            switch entity.type {
            case .phoneNumber:
                actions.append(QuickAction(
                    id: "entity_phone",
                    title: "Call \(entity.value)",
                    icon: "phone.fill",
                    color: .green,
                    score: 95,
                    category: .text,
                    toolDestination: nil,
                    directAction: {
                        let num = entity.value.filter { $0.isNumber || $0 == "+" }
                        if let url = URL(string: "tel:\(num)") {
                            UIApplication.shared.open(url)
                        }
                    }
                ))
            case .email:
                actions.append(QuickAction(
                    id: "entity_email",
                    title: "Email \(entity.value)",
                    icon: "envelope.fill",
                    color: .purple,
                    score: 90,
                    category: .text,
                    toolDestination: nil,
                    directAction: {
                        if let url = URL(string: "mailto:\(entity.value)") {
                            UIApplication.shared.open(url)
                        }
                    }
                ))
            case .url:
                actions.append(QuickAction(
                    id: "entity_url",
                    title: "Open Link",
                    icon: "safari.fill",
                    color: .blue,
                    score: 95,
                    category: .text,
                    toolDestination: nil,
                    directAction: {
                        if let url = URL(string: entity.value) {
                            UIApplication.shared.open(url)
                        }
                    }
                ))
            case .address:
                actions.append(QuickAction(
                    id: "entity_address",
                    title: "Open in Maps",
                    icon: "map.fill",
                    color: .blue,
                    score: 95,
                    category: .text,
                    toolDestination: nil,
                    directAction: {
                        let encoded = entity.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                        if let url = URL(string: "maps://?q=\(encoded)") {
                            UIApplication.shared.open(url)
                        }
                    }
                ))
            case .upiId:
                actions.append(QuickAction(
                    id: "entity_upi",
                    title: "Pay via UPI",
                    icon: "indianrupeesign.circle.fill",
                    color: .green,
                    score: 90,
                    category: .text,
                    toolDestination: nil,
                    directAction: {
                        if let url = URL(string: "upi://pay?pa=\(entity.value)") {
                            UIApplication.shared.open(url)
                        }
                    }
                ))
            case .coordinates:
                actions.append(QuickAction(
                    id: "entity_coords",
                    title: "Open Location",
                    icon: "location.fill",
                    color: .blue,
                    score: 90,
                    category: .text,
                    toolDestination: nil,
                    directAction: {
                        let parts = entity.value.components(separatedBy: CharacterSet(charactersIn: ",/"))
                        let lat = parts.first?.trimmingCharacters(in: .whitespaces) ?? ""
                        let lon = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
                        if let url = URL(string: "maps://?ll=\(lat),\(lon)") {
                            UIApplication.shared.open(url)
                        }
                    }
                ))
            case .trackingNumber:
                let trackNum = entity.value
                actions.append(QuickAction(
                    id: "entity_tracking",
                    title: "Track \(trackNum)",
                    icon: "shippingbox.fill",
                    color: .indigo,
                    score: 95,
                    category: .utility,
                    toolDestination: nil,
                    directAction: {
                        let encoded = trackNum.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trackNum
                        if let url = URL(string: "https://parcelsapp.com/en/tracking/\(encoded)") {
                            UIApplication.shared.open(url)
                        }
                    }
                ))
            case .wifi:
                let ssid = entity.value
                let password = entity.secondaryValue
                if ssid != "Wifi Password" {
                    actions.append(QuickAction(
                        id: "entity_wifi",
                        title: "Connect to \(ssid)",
                        icon: "wifi",
                        color: .cyan,
                        score: 95,
                        category: .utility,
                        toolDestination: nil,
                        directAction: {
                            let config: NEHotspotConfiguration
                            if let password, !password.isEmpty {
                                config = NEHotspotConfiguration(ssid: ssid, passphrase: password, isWEP: false)
                            } else {
                                config = NEHotspotConfiguration(ssid: ssid)
                            }
                            config.joinOnce = false
                            NEHotspotConfigurationManager.shared.apply(config) { error in
                                if error == nil || (error as? NSError)?.code == 13 {
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                }
                            }
                        }
                    ))
                }
            default:
                break
            }
        }

        return actions
    }

    // MARK: - Tool Actions with Base Scores

    private func buildToolActions(
        classification: ContentClassifier.Classification,
        text: String,
        image: UIImage?,
        entities: [DetectedEntity]
    ) -> [QuickAction] {
        let ct = classification.type
        var actions: [QuickAction] = []

        // --- Document actions ---
        actions.append(QuickAction(
            id: "copy_text",
            title: "Copy Clean Text",
            icon: "doc.on.doc.fill",
            color: .blue,
            score: ct == .structured ? 90 : (ct == .document ? 85 : 60),
            category: .document,
            toolDestination: nil,
            directAction: { ClipboardManager.shared.copy(text, source: "Scan") }
        ))

        actions.append(QuickAction(
            id: "convert_pdf",
            title: "Convert to PDF",
            icon: "doc.fill",
            color: .red,
            score: ct == .document ? 90 : 50,
            category: .document,
            toolDestination: { AnyView(ImageToPDFView()) },
            directAction: nil
        ))

        actions.append(QuickAction(
            id: "sign_document",
            title: "Sign Document",
            icon: "signature",
            color: .green,
            score: ct == .document ? 85 : 30,
            category: .document,
            toolDestination: { AnyView(DocumentSigningView()) },
            directAction: nil
        ))

        actions.append(QuickAction(
            id: "notes_from_scan",
            title: "Create Note",
            icon: "note.text",
            color: .yellow,
            score: ct == .document ? 70 : 45,
            category: .document,
            toolDestination: { AnyView(NotesFromScanView()) },
            directAction: nil
        ))

        actions.append(QuickAction(
            id: "doc_to_pdf",
            title: "Doc to PDF",
            icon: "doc.badge.arrow.up",
            color: .indigo,
            score: ct == .document ? 65 : 25,
            category: .document,
            toolDestination: { AnyView(DocToPDFView()) },
            directAction: nil
        ))

        // --- Image actions ---
        actions.append(QuickAction(
            id: "passport_photo",
            title: "Resize / Passport",
            icon: "person.crop.rectangle",
            color: .purple,
            score: ct == .image ? 90 : 25,
            category: .image,
            toolDestination: { AnyView(PassportPhotoView()) },
            directAction: nil
        ))

        actions.append(QuickAction(
            id: "remove_bg",
            title: "Remove Background",
            icon: "person.and.background.strikethrough",
            color: .pink,
            score: ct == .image ? 85 : 20,
            category: .image,
            toolDestination: { AnyView(RemoveBackgroundView()) },
            directAction: nil
        ))

        actions.append(QuickAction(
            id: "compress_image",
            title: "Compress Image",
            icon: "arrow.down.right.and.arrow.up.left",
            color: .blue,
            score: ct == .image ? 75 : 20,
            category: .image,
            toolDestination: { AnyView(ImageCompressorView()) },
            directAction: nil
        ))

        actions.append(QuickAction(
            id: "image_to_pdf",
            title: "Image to PDF",
            icon: "photo.on.rectangle.angled",
            color: .red,
            score: ct == .image ? 70 : 40,
            category: .image,
            toolDestination: { AnyView(ImageToPDFView()) },
            directAction: nil
        ))

        // --- Structured/Text actions ---
        actions.append(QuickAction(
            id: "json_formatter",
            title: "Format JSON",
            icon: "curlybraces",
            color: .purple,
            score: classification.hasJSON ? 95 : (ct == .structured ? 85 : 15),
            category: .text,
            toolDestination: { AnyView(CodeFormatterView()) },
            directAction: nil
        ))

        actions.append(QuickAction(
            id: "summarize",
            title: "Summarize",
            icon: "text.badge.checkmark",
            color: .green,
            score: ct == .document ? 75 : (ct == .structured ? 70 : 30),
            category: .text,
            toolDestination: { AnyView(TextSummarizerView()) },
            directAction: nil
        ))

        actions.append(QuickAction(
            id: "compare_text",
            title: "Compare Text",
            icon: "doc.text.magnifyingglass",
            color: .orange,
            score: ct == .structured ? 75 : 25,
            category: .text,
            toolDestination: { AnyView(TextCompareView()) },
            directAction: nil
        ))

        actions.append(QuickAction(
            id: "word_counter",
            title: "Word Count",
            icon: "number",
            color: .blue,
            score: ct == .document ? 50 : 20,
            category: .text,
            toolDestination: { AnyView(WordCounterView()) },
            directAction: nil
        ))

        // --- Receipt/Table actions ---
        actions.append(QuickAction(
            id: "extract_receipt",
            title: "Extract Receipt",
            icon: "receipt",
            color: .mint,
            score: classification.hasReceipt ? 90 : 15,
            category: .document,
            toolDestination: { AnyView(ReceiptScannerView()) },
            directAction: nil
        ))

        actions.append(QuickAction(
            id: "extract_table",
            title: "Extract Table / CSV",
            icon: "tablecells",
            color: .cyan,
            score: classification.hasTable ? 90 : (ct == .receipt ? 85 : 15),
            category: .document,
            toolDestination: { AnyView(TableExtractorView()) },
            directAction: nil
        ))

        // --- Utility actions (always low base, only in Do More unless boosted) ---
        actions.append(QuickAction(
            id: "color_picker",
            title: "Pick Color",
            icon: "eyedropper",
            color: .pink,
            score: ct == .image ? 30 : 5,
            category: .utility,
            toolDestination: { AnyView(ColorPickerImageView()) },
            directAction: nil
        ))

        actions.append(QuickAction(
            id: "unit_converter",
            title: "Unit Converter",
            icon: "arrow.left.arrow.right",
            color: .teal,
            score: 10,
            category: .utility,
            toolDestination: { AnyView(UnitConverterView()) },
            directAction: nil
        ))

        actions.append(QuickAction(
            id: "ruler",
            title: "Ruler",
            icon: "ruler",
            color: .brown,
            score: ct == .image ? 15 : 5,
            category: .utility,
            toolDestination: { AnyView(RulerView()) },
            directAction: nil
        ))

        // --- Scan tools (for re-scanning / different modes) ---
        actions.append(QuickAction(
            id: "qr_scanner",
            title: "Scan QR Code",
            icon: "qrcode.viewfinder",
            color: .purple,
            score: 10,
            category: .utility,
            toolDestination: { AnyView(QRScannerTab()) },
            directAction: nil
        ))

        actions.append(QuickAction(
            id: "batch_scan",
            title: "Batch Scan",
            icon: "doc.on.doc",
            color: .orange,
            score: 10,
            category: .document,
            toolDestination: { AnyView(BatchScanView()) },
            directAction: nil
        ))

        actions.append(QuickAction(
            id: "doc_scanner",
            title: "Document Scanner",
            icon: "doc.viewfinder",
            color: .teal,
            score: ct == .document ? 40 : 10,
            category: .document,
            toolDestination: { AnyView(DocumentScannerTab()) },
            directAction: nil
        ))

        actions.append(QuickAction(
            id: "website_detect",
            title: "Detect URLs",
            icon: "globe",
            color: .orange,
            score: entities.contains(where: { $0.type == .url }) ? 50 : 10,
            category: .text,
            toolDestination: { AnyView(WebsiteDetectionView()) },
            directAction: nil
        ))

        return actions
    }

    // MARK: - Detection Boosts

    private func applyDetectionBoosts(_ actions: inout [QuickAction], entities: [DetectedEntity]) {
        let entityTypes = Set(entities.map { $0.type })

        for i in actions.indices {
            switch actions[i].id {
            case "extract_receipt":
                if entityTypes.contains(.currency) { actions[i].score += 20 }
            case "convert_pdf", "sign_document":
                if entityTypes.contains(.date) || entityTypes.contains(.address) { actions[i].score += 10 }
            case "extract_table":
                if entityTypes.contains(.currency) { actions[i].score += 15 }
            default:
                break
            }
        }
    }

    // MARK: - Suppression

    private func applySuppression(_ actions: [QuickAction], classification: ContentClassifier.Classification) -> [QuickAction] {
        actions.filter { action in
            switch action.id {
            // Don't show JSON formatter for images/receipts with no JSON
            case "json_formatter":
                return classification.hasJSON || classification.type == .structured
            // Don't show sign document for photos
            case "sign_document":
                return classification.type != .image
            // Don't promote receipt for non-receipt content
            case "extract_receipt":
                return classification.hasReceipt || action.score > 30
            // Don't promote table extraction unless there's evidence
            case "extract_table":
                return classification.hasTable || classification.hasReceipt || action.score > 30
            default:
                return true
            }
        }
    }
}
