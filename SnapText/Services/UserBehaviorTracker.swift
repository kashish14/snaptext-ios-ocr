import Foundation

/// Tracks user behavior (action frequency + recency) to boost relevant actions.
/// Persists to UserDefaults — no SwiftData needed.
final class UserBehaviorTracker {
    static let shared = UserBehaviorTracker()

    private let defaults = UserDefaults.standard
    private let frequencyKey = "actionFrequency"
    private let recencyKey = "actionRecency"

    private init() {}

    /// Record that the user tapped an action
    func recordAction(_ actionId: String) {
        // Frequency
        var freq = frequencies
        freq[actionId, default: 0] += 1
        defaults.set(freq, forKey: frequencyKey)

        // Recency — store timestamp
        var recency = recencyTimestamps
        recency[actionId] = Date().timeIntervalSince1970
        defaults.set(recency, forKey: recencyKey)
    }

    /// Frequency boost: +15 for frequently used actions (top 5 by count)
    func frequencyBoost(for actionId: String) -> Double {
        let freq = frequencies
        guard !freq.isEmpty else { return 0 }

        let sorted = freq.sorted { $0.value > $1.value }
        let topIds = Set(sorted.prefix(5).map { $0.key })
        return topIds.contains(actionId) ? 15.0 : 0.0
    }

    /// Recency boost: +10 if used in last 24 hours
    func recencyBoost(for actionId: String) -> Double {
        let recency = recencyTimestamps
        guard let lastUsed = recency[actionId] else { return 0 }
        let elapsed = Date().timeIntervalSince1970 - lastUsed
        let twentyFourHours: TimeInterval = 86400
        return elapsed < twentyFourHours ? 10.0 : 0.0
    }

    /// Total behavior boost for an action
    func totalBoost(for actionId: String) -> Double {
        frequencyBoost(for: actionId) + recencyBoost(for: actionId)
    }

    /// Get usage count for an action
    func usageCount(for actionId: String) -> Int {
        frequencies[actionId] ?? 0
    }

    // MARK: - Private

    private var frequencies: [String: Int] {
        defaults.dictionary(forKey: frequencyKey) as? [String: Int] ?? [:]
    }

    private var recencyTimestamps: [String: TimeInterval] {
        defaults.dictionary(forKey: recencyKey) as? [String: TimeInterval] ?? [:]
    }
}
