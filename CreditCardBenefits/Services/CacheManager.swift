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
            try data.write(to: url, options: .atomic)
        } catch {
            print("Cache write error for \(key.rawValue): \(error)")
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

    func clearAll() {
        for key in CacheKey.allCases {
            let url = cacheDirectory.appendingPathComponent("\(key.rawValue).json")
            try? FileManager.default.removeItem(at: url)
        }
    }
}
