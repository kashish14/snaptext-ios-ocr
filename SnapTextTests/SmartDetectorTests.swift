import Testing
@testable import SnapText

@MainActor
struct SmartDetectorTests {
    let detector = SmartDetector()

    private func types(in text: String) -> Set<DetectedEntity.EntityType> {
        Set(detector.detect(in: text).map(\.type))
    }

    @Test func detectsEmail() {
        #expect(types(in: "Write to hello@example.com today").contains(.email))
    }

    @Test func detectsURL() {
        #expect(types(in: "Docs at https://developer.apple.com/vision").contains(.url))
    }

    @Test func detectsPhoneNumber() {
        #expect(types(in: "Call me on +1 415 555 0132").contains(.phoneNumber))
    }

    @Test func detectsUPI() {
        #expect(types(in: "Pay to merchant@okaxis").contains(.upiId))
    }

    @Test func detectsIFSC() {
        #expect(types(in: "IFSC: HDFC0001234").contains(.ifscCode))
    }

    @Test func plainTextHasNoEntities() {
        #expect(detector.detect(in: "the quick brown fox jumps over the lazy dog").isEmpty)
    }
}

@MainActor
struct ContentClassifierTests {
    let classifier = ContentClassifier()

    @Test func detectsJSON() {
        let json = #"{"name": "SnapText", "version": 1, "tags": ["ocr", "ios"]}"#
        #expect(classifier.classify(text: json, entities: []).hasJSON)
    }

    @Test func shortTextIsNotJSON() {
        #expect(!classifier.classify(text: "hello world", entities: []).hasJSON)
    }
}
