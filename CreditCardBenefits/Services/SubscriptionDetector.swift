//
//  SubscriptionDetector.swift
//  CreditCardBenefits
//
//  Created for Credit Card Benefits Tracker POC
//

import Foundation

class SubscriptionDetector {

    // Common subscription merchant patterns
    private struct MerchantPattern {
        let pattern: String
        let name: String
        let category: SubscriptionCategory
    }

    private static let patterns: [MerchantPattern] = [
        // Streaming
        MerchantPattern(pattern: "netflix", name: "Netflix", category: .streaming),
        MerchantPattern(pattern: "hulu", name: "Hulu", category: .streaming),
        MerchantPattern(pattern: "disney", name: "Disney+", category: .streaming),
        MerchantPattern(pattern: "espn", name: "ESPN+", category: .streaming),
        MerchantPattern(pattern: "hbo", name: "HBO Max", category: .streaming),
        MerchantPattern(pattern: "peacock", name: "Peacock", category: .streaming),
        MerchantPattern(pattern: "paramount", name: "Paramount+", category: .streaming),
        MerchantPattern(pattern: "apple tv", name: "Apple TV+", category: .streaming),
        MerchantPattern(pattern: "youtube premium", name: "YouTube Premium", category: .streaming),
        MerchantPattern(pattern: "spotify", name: "Spotify", category: .streaming),
        MerchantPattern(pattern: "apple music", name: "Apple Music", category: .streaming),
        MerchantPattern(pattern: "amazon music", name: "Amazon Music", category: .streaming),
        MerchantPattern(pattern: "audible", name: "Audible", category: .streaming),

        // Fitness
        MerchantPattern(pattern: "peloton", name: "Peloton", category: .fitness),
        MerchantPattern(pattern: "planet fitness", name: "Planet Fitness", category: .fitness),
        MerchantPattern(pattern: "la fitness", name: "LA Fitness", category: .fitness),
        MerchantPattern(pattern: "24 hour fitness", name: "24 Hour Fitness", category: .fitness),
        MerchantPattern(pattern: "equinox", name: "Equinox", category: .fitness),
        MerchantPattern(pattern: "classpass", name: "ClassPass", category: .fitness),

        // Food
        MerchantPattern(pattern: "doordash", name: "DoorDash", category: .food),
        MerchantPattern(pattern: "uber eats", name: "Uber Eats", category: .food),
        MerchantPattern(pattern: "grubhub", name: "Grubhub", category: .food),
        MerchantPattern(pattern: "instacart", name: "Instacart", category: .food),
        MerchantPattern(pattern: "walmart", name: "Walmart+", category: .food),

        // Software
        MerchantPattern(pattern: "adobe", name: "Adobe Creative Cloud", category: .software),
        MerchantPattern(pattern: "microsoft 365", name: "Microsoft 365", category: .software),
        MerchantPattern(pattern: "dropbox", name: "Dropbox", category: .software),
        MerchantPattern(pattern: "google one", name: "Google One", category: .software),
        MerchantPattern(pattern: "icloud", name: "iCloud+", category: .software),
        MerchantPattern(pattern: "github", name: "GitHub", category: .software),
        MerchantPattern(pattern: "notion", name: "Notion", category: .software),
        MerchantPattern(pattern: "chatgpt", name: "ChatGPT Plus", category: .software),

        // Other
        MerchantPattern(pattern: "new york times", name: "The New York Times", category: .other),
        MerchantPattern(pattern: "nytimes", name: "The New York Times", category: .other),
        MerchantPattern(pattern: "wall street journal", name: "The Wall Street Journal", category: .other),
        MerchantPattern(pattern: "kindle unlimited", name: "Kindle Unlimited", category: .other),
        MerchantPattern(pattern: "amazon prime", name: "Amazon Prime", category: .other),
    ]

    // Detect subscriptions from transactions
    static func detectSubscriptions(from transactions: [Transaction]) -> [Subscription] {
        let merchantGroups = groupByMerchant(transactions)
        var subscriptions: [Subscription] = []

        for (merchantKey, merchantTransactions) in merchantGroups {
            if isRecurring(merchantTransactions) {
                let category = detectCategory(for: merchantKey)
                let cleanMerchant = cleanMerchantName(merchantKey)
                let avgAmount = calculateAverageAmount(merchantTransactions)
                let frequency = detectFrequency(merchantTransactions)

                let subscription = Subscription(
                    id: "sub-\(merchantKey.replacingOccurrences(of: " ", with: "-"))",
                    merchant: cleanMerchant,
                    amount: avgAmount,
                    frequency: frequency,
                    lastCharged: merchantTransactions.first?.date ?? Date(),
                    nextCharge: estimateNextCharge(
                        from: merchantTransactions.first?.date ?? Date(),
                        frequency: frequency
                    ),
                    category: category,
                    transactions: merchantTransactions
                )

                subscriptions.append(subscription)
            }
        }

        return subscriptions.sorted { $0.amount > $1.amount }
    }

    // Group transactions by merchant
    private static func groupByMerchant(_ transactions: [Transaction]) -> [String: [Transaction]] {
        var groups: [String: [Transaction]] = [:]

        for transaction in transactions {
            let key = normalizeMerchant(transaction.merchant)
            groups[key, default: []].append(transaction)
        }

        return groups
    }

    // Normalize merchant name for grouping
    private static func normalizeMerchant(_ merchant: String) -> String {
        return merchant
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    // Clean up merchant name for display
    private static func cleanMerchantName(_ merchant: String) -> String {
        // Try to match against known patterns
        let lowerMerchant = merchant.lowercased()
        for pattern in patterns {
            if lowerMerchant.contains(pattern.pattern.lowercased()) {
                return pattern.name
            }
        }

        // Otherwise capitalize each word
        return merchant
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    // Detect if transactions are recurring
    private static func isRecurring(_ transactions: [Transaction]) -> Bool {
        guard transactions.count >= 2 else { return false }

        // Check if amounts are consistent (within 10% variance)
        let amounts = transactions.map { $0.amount }
        let avgAmount = amounts.reduce(0, +) / Double(amounts.count)
        let amountsConsistent = amounts.allSatisfy { abs($0 - avgAmount) / avgAmount < 0.1 }

        guard amountsConsistent else { return false }

        // Check if transactions occur at regular intervals
        let intervals = calculateIntervals(transactions)
        guard !intervals.isEmpty else { return false }

        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)

        // Consider it recurring if intervals are consistent (within 7 days variance)
        return intervals.allSatisfy { abs($0 - avgInterval) < 7 }
    }

    // Calculate intervals between transactions in days
    private static func calculateIntervals(_ transactions: [Transaction]) -> [Double] {
        let sortedTransactions = transactions.sorted { $0.date < $1.date }
        var intervals: [Double] = []

        for i in 1..<sortedTransactions.count {
            let interval = sortedTransactions[i].date.timeIntervalSince(sortedTransactions[i-1].date)
            let days = interval / (60 * 60 * 24)
            intervals.append(days)
        }

        return intervals
    }

    // Detect frequency based on transaction intervals
    private static func detectFrequency(_ transactions: [Transaction]) -> SubscriptionFrequency {
        let intervals = calculateIntervals(transactions)
        guard !intervals.isEmpty else { return .monthly }

        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)

        if avgInterval >= 300 { return .annual }     // ~365 days
        if avgInterval >= 75 { return .quarterly }   // ~90 days
        return .monthly                              // ~30 days
    }

    // Calculate average amount
    private static func calculateAverageAmount(_ transactions: [Transaction]) -> Double {
        let sum = transactions.reduce(0) { $0 + $1.amount }
        let avg = sum / Double(transactions.count)
        return round(avg * 100) / 100
    }

    // Detect category based on merchant name
    private static func detectCategory(for merchant: String) -> SubscriptionCategory {
        let lowerMerchant = merchant.lowercased()

        for pattern in patterns {
            if lowerMerchant.contains(pattern.pattern.lowercased()) {
                return pattern.category
            }
        }

        return .other
    }

    // Estimate next charge date
    private static func estimateNextCharge(from lastCharge: Date, frequency: SubscriptionFrequency) -> Date {
        var components = DateComponents()

        switch frequency {
        case .monthly:
            components.month = 1
        case .quarterly:
            components.month = 3
        case .annual:
            components.year = 1
        }

        return Calendar.current.date(byAdding: components, to: lastCharge) ?? lastCharge
    }
}
