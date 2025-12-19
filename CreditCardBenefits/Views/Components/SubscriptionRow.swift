//
//  SubscriptionRow.swift
//  CreditCardBenefits
//
//  Created for Credit Card Benefits Tracker POC
//

import SwiftUI

struct SubscriptionRow: View {
    let subscription: Subscription

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(subscription.merchant)
                    .font(.system(size: 16, weight: .bold))

                Spacer()

                Text("\(formatCurrency(subscription.amount))\(subscription.frequencyDisplay)")
                    .font(.system(size: 16, weight: .bold))
            }

            Text(subscription.category.displayName)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            Text("Last charged: \(subscription.lastChargedString)")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}
