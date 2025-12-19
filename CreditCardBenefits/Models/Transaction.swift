//
//  Transaction.swift
//  CreditCardBenefits
//
//  Created for Credit Card Benefits Tracker POC
//

import Foundation

struct Transaction: Identifiable, Codable {
    let id: String
    let date: Date
    let merchant: String
    let amount: Double
    let category: String?
    let accountId: String

    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
