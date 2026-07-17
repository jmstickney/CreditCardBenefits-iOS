//
//  CacheManager.swift
//  CreditCardBenefits
//
//  Local JSON file caching for instant app launch
//

import Foundation

final class CacheManager {

    static let shared = CacheManager()

    private let cacheDirectory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    enum CacheKey: String, CaseIterable {
        case transactions
        case subscriptions
        case cardMappings
        case benefitUtilizations
        case benefitMatches
        case userStats
        case plaidAccounts
        case dataSource
        case isLinked
        case userCards
        case lastRefreshDate
        // Transaction IDs we've already surfaced a "benefit matched" notification
        // for (per user; cleared on sign-out). nil file == baseline not yet seeded.
        case notifiedMatchIds
        // Wrong-card suggestion keys the user dismissed (permanently).
        case dismissedOpportunities
        // Transaction IDs already covered by a wrong-card alert. nil file ==
        // first run (one summary alert for existing misses, then new-only).
        case notifiedOpportunityTxnIds
        // Card IDs whose "benefits captured beat the annual fee" confetti has
        // already played (once per card, per user).
        case celebratedCards
    }

    private init() {
        let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesURL.appendingPathComponent("AppCache", isDirectory: true)

        try? FileManager.default.createDirectory(at: cacheDirectory,
                                                   withIntermediateDirectories: true)

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Generic Save/Load

    func save<T: Encodable>(_ value: T, for key: CacheKey) {
        let url = cacheDirectory.appendingPathComponent("\(key.rawValue).json")
        do {
            let data = try encoder.encode(value)
            // Encrypt the cache at rest. `untilFirstUserAuthentication` keeps the
            // file readable for background refresh after the first post-boot unlock
            // while still protecting financial data when the device is at rest.
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            benLog("Cache write error for \(key.rawValue): \(error)")
        }
    }

    func load<T: Decodable>(_ type: T.Type, for key: CacheKey) -> T? {
        let url = cacheDirectory.appendingPathComponent("\(key.rawValue).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    // MARK: - Convenience

    var lastRefreshDate: Date? {
        load(Date.self, for: .lastRefreshDate)
    }

    var needsRefresh: Bool {
        guard let lastRefresh = lastRefreshDate else { return true }
        return Date().timeIntervalSince(lastRefresh) > 6 * 60 * 60
    }

    /// Returns true if data is stale enough to warrant a refresh when the app returns to foreground
    var needsForegroundRefresh: Bool {
        guard let lastRefresh = lastRefreshDate else { return true }
        return Date().timeIntervalSince(lastRefresh) > 1 * 60 * 60  // 1 hour
    }

    func clearAll() {
        for key in CacheKey.allCases {
            let url = cacheDirectory.appendingPathComponent("\(key.rawValue).json")
            try? FileManager.default.removeItem(at: url)
        }
    }
}
