//
//  MockData.swift
//  CreditCardBenefits
//
//  Created for Credit Card Benefits Tracker POC
//

import Foundation

struct MockData {

    // Create date from string
    private static func date(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string) ?? Date()
    }

    // Mock transaction data for POC testing
    static let transactions: [Transaction] = [
        // Netflix - monthly subscription
        Transaction(id: "t1", date: date("2024-11-15"), merchant: "Netflix.com", amount: 15.99, category: "streaming", accountId: "acc1"),
        Transaction(id: "t2", date: date("2024-10-15"), merchant: "Netflix.com", amount: 15.99, category: "streaming", accountId: "acc1"),
        Transaction(id: "t3", date: date("2024-09-15"), merchant: "Netflix.com", amount: 15.99, category: "streaming", accountId: "acc1"),

        // Spotify - monthly subscription
        Transaction(id: "t4", date: date("2024-11-20"), merchant: "Spotify Premium", amount: 10.99, category: "streaming", accountId: "acc1"),
        Transaction(id: "t5", date: date("2024-10-20"), merchant: "Spotify Premium", amount: 10.99, category: "streaming", accountId: "acc1"),
        Transaction(id: "t6", date: date("2024-09-20"), merchant: "Spotify Premium", amount: 10.99, category: "streaming", accountId: "acc1"),

        // Disney+ - monthly subscription
        Transaction(id: "t7", date: date("2024-11-10"), merchant: "DisneyPlus", amount: 13.99, category: "streaming", accountId: "acc1"),
        Transaction(id: "t8", date: date("2024-10-10"), merchant: "DisneyPlus", amount: 13.99, category: "streaming", accountId: "acc1"),
        Transaction(id: "t9", date: date("2024-09-10"), merchant: "DisneyPlus", amount: 13.99, category: "streaming", accountId: "acc1"),

        // DoorDash - monthly subscription
        Transaction(id: "t10", date: date("2024-11-05"), merchant: "DoorDash", amount: 9.99, category: "food", accountId: "acc1"),
        Transaction(id: "t11", date: date("2024-10-05"), merchant: "DoorDash", amount: 9.99, category: "food", accountId: "acc1"),
        Transaction(id: "t12", date: date("2024-09-05"), merchant: "DoorDash", amount: 9.99, category: "food", accountId: "acc1"),

        // Planet Fitness - monthly subscription
        Transaction(id: "t13", date: date("2024-11-01"), merchant: "Planet Fitness", amount: 24.99, category: "fitness", accountId: "acc1"),
        Transaction(id: "t14", date: date("2024-10-01"), merchant: "Planet Fitness", amount: 24.99, category: "fitness", accountId: "acc1"),
        Transaction(id: "t15", date: date("2024-09-01"), merchant: "Planet Fitness", amount: 24.99, category: "fitness", accountId: "acc1"),

        // The New York Times - monthly subscription
        Transaction(id: "t16", date: date("2024-11-12"), merchant: "The New York Times", amount: 17.0, category: "other", accountId: "acc1"),
        Transaction(id: "t17", date: date("2024-10-12"), merchant: "The New York Times", amount: 17.0, category: "other", accountId: "acc1"),
        Transaction(id: "t18", date: date("2024-09-12"), merchant: "The New York Times", amount: 17.0, category: "other", accountId: "acc1"),

        // Adobe Creative Cloud - monthly subscription
        Transaction(id: "t19", date: date("2024-11-08"), merchant: "Adobe Systems", amount: 54.99, category: "software", accountId: "acc1"),
        Transaction(id: "t20", date: date("2024-10-08"), merchant: "Adobe Systems", amount: 54.99, category: "software", accountId: "acc1"),
        Transaction(id: "t21", date: date("2024-09-08"), merchant: "Adobe Systems", amount: 54.99, category: "software", accountId: "acc1"),
    ]

    // Mock user's credit cards
    static let userCards: [CreditCard] = [
        CreditCardsData.allCards[0], // Amex Platinum
        CreditCardsData.allCards[1], // Chase Sapphire Reserve
    ]
}
