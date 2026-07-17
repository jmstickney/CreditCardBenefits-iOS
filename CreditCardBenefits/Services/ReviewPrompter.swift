//
//  ReviewPrompter.swift
//  CreditCardBenefits
//
//  Requests an App Store rating at a "delight moment": when Ben surfaces
//  savings worth more than a year of the subscription, the value is
//  self-evident — the sanctioned time to ask.
//
//  Notes: the system decides whether the prompt actually shows (Apple caps it
//  at ~3/year per app), so we spend our chances carefully — one ask per
//  device, only when the shown value clears the threshold.
//

import Foundation
import StoreKit
import UIKit

@MainActor
enum ReviewPrompter {

    /// Device-level (UserDefaults, survives sign-out): we only ever ask once
    /// for this trigger.
    private static let promptedKey = "didPromptReviewForSavings"

    /// Ask only when the surfaced annual value beats ~a year of Ben ($4.99/mo).
    static let savingsValueThreshold: Double = 60

    /// Call when savings opportunities are shown. Prompts (at most once ever)
    /// if their combined annual value clears the threshold.
    static func maybePromptForSavings(_ opportunities: [MissedBenefitOpportunity]) {
        guard !opportunities.isEmpty,
              !UserDefaults.standard.bool(forKey: promptedKey) else { return }

        let totalAnnualValue = opportunities.reduce(0.0) {
            $0 + $1.benefit.annualAmount
        }
        guard totalAnnualValue >= savingsValueThreshold else { return }

        UserDefaults.standard.set(true, forKey: promptedKey)

        // Small delay so the sheet doesn't collide with content animating in.
        Task {
            try? await Task.sleep(for: .seconds(2))
            guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive })
                as? UIWindowScene else { return }
            AppStore.requestReview(in: scene)
            benLog("⭐️ Requested App Store review (savings \(totalAnnualValue.asCurrency())/yr)")
        }
    }
}
