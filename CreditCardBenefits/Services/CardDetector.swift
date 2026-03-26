//
//  CardDetector.swift
//  CreditCardBenefits
//
//  Handles credit card account filtering from Plaid
//  Card selection is manual - user picks from supported cards
//

import Foundation

// MARK: - Card Match Result

struct CardMatch: Identifiable {
    let id = UUID()
    let plaidAccount: PlaidAccount
    var creditCard: CreditCard?       // nil until user selects
    var isConfirmed: Bool             // true after user confirms selection
    var anniversaryDate: Date?        // Card account opening/anniversary date for cardmemberYear benefits

    init(plaidAccount: PlaidAccount, creditCard: CreditCard? = nil, isConfirmed: Bool = false, anniversaryDate: Date? = nil) {
        self.plaidAccount = plaidAccount
        self.creditCard = creditCard
        self.isConfirmed = isConfirmed
        self.anniversaryDate = anniversaryDate
    }
}

// MARK: - Card Detector

class CardDetector {

    /// Filter to only credit card accounts from Plaid, removing duplicates
    static func creditCardAccounts(from accounts: [PlaidAccount]) -> [PlaidAccount] {
        // First filter to credit cards only
        let creditCards = accounts.filter { $0.isCreditCard }

        // Deduplicate by mask (last 4 digits) - this catches the same physical card
        // appearing multiple times with different Plaid account IDs
        var seenMasks = Set<String>()
        var seenIds = Set<String>()

        let uniqueCreditCards = creditCards.filter { account in
            // Skip if we've seen this exact account ID
            if seenIds.contains(account.id) {
                print("⚠️ Skipping duplicate account ID: \(account.name)")
                return false
            }

            // Skip if we've seen this mask (same physical card)
            if let mask = account.mask, !mask.isEmpty {
                if seenMasks.contains(mask) {
                    print("⚠️ Skipping duplicate card (same last 4): \(account.name) (**** \(mask))")
                    return false
                }
                seenMasks.insert(mask)
            }

            seenIds.insert(account.id)
            return true
        }

        print("💳 Found \(uniqueCreditCards.count) unique credit card accounts out of \(accounts.count) total")
        if creditCards.count != uniqueCreditCards.count {
            print("   (removed \(creditCards.count - uniqueCreditCards.count) duplicates)")
        }

        return uniqueCreditCards
    }

    /// Creates CardMatch entries for all credit card accounts
    /// User will manually select which card each account is
    static func createMatches(from accounts: [PlaidAccount]) -> [CardMatch] {
        let creditCardAccounts = creditCardAccounts(from: accounts)

        return creditCardAccounts.map { account in
            print("📋 Created match entry for: \(account.name) (**** \(account.mask ?? ""))")
            return CardMatch(plaidAccount: account)
        }
    }
}
