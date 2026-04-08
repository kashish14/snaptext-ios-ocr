import Foundation
import SwiftData
import UIKit

@Model
final class ScanHistoryItem {
    var id: UUID
    var text: String
    var timestamp: Date
    @Attribute(.externalStorage) var imageData: Data?
    var isFavorite: Bool

    // Store entities as JSON for persistence
    var entitiesJSON: Data?

    init(text: String, image: UIImage?, entities: [DetectedEntity] = [], timestamp: Date = .now) {
        self.id = UUID()
        self.text = text
        self.timestamp = timestamp
        self.isFavorite = false
        self.imageData = image?.jpegData(compressionQuality: 0.5)
        self.entitiesJSON = try? JSONEncoder().encode(
            entities.map { StoredEntity(type: $0.type.rawValue, value: $0.value, secondaryValue: $0.secondaryValue) }
        )
    }

    var thumbnailImage: UIImage? {
        guard let data = imageData else { return nil }
        return UIImage(data: data)
    }

    var entities: [DetectedEntity] {
        guard let data = entitiesJSON,
              let stored = try? JSONDecoder().decode([StoredEntity].self, from: data) else {
            return []
        }
        return stored.compactMap { item in
            guard let type = DetectedEntity.EntityType(rawValue: item.type) else { return nil }
            return DetectedEntity(type: type, value: item.value, secondaryValue: item.secondaryValue)
        }
    }

    var phoneNumbers: [DetectedEntity] {
        entities.filter { $0.type == .phoneNumber }
    }

    var addresses: [DetectedEntity] {
        entities.filter { $0.type == .address }
    }

    var urls: [DetectedEntity] {
        entities.filter { $0.type == .url }
    }

    var emails: [DetectedEntity] {
        entities.filter { $0.type == .email }
    }

    var textPreview: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 100 { return trimmed }
        return String(trimmed.prefix(100)) + "..."
    }
}

// Codable wrapper for persisting DetectedEntity
private struct StoredEntity: Codable {
    let type: String
    let value: String
    let secondaryValue: String?
}
