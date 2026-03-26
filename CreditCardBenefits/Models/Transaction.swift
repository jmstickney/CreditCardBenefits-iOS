//
//  Transaction.swift
//  CreditCardBenefits
//
//  Created for Credit Card Benefits Tracker POC
//

import Foundation

struct Transaction: Identifiable, Codable, Equatable {
    let id: String
    let date: Date
    let merchant: String
    let amount: Double
    let category: String?
    let accountId: String
    let isCredit: Bool  // true if this is a credit/refund (negative amount from Plaid)

    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    var displayAmount: Double {
        // Return signed amount for display purposes
        isCredit ? -amount : amount
    }
}
