import Foundation
import UIKit

struct ScanResult: Identifiable {
    let id = UUID()
    let image: UIImage
    let text: String
    let entities: [DetectedEntity]
    let timestamp: Date

    init(image: UIImage, text: String, entities: [DetectedEntity] = [], timestamp: Date = .now) {
        self.image = image
        self.text = text
        self.entities = entities
        self.timestamp = timestamp
    }
}
