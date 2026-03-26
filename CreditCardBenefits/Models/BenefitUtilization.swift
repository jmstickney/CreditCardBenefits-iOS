//
//  BenefitUtilization.swift
//  CreditCardBenefits
//
//  Tracks actual usage of credit card benefits
//

import Foundation

/// Represents the utilization status of a benefit for a specific period
struct BenefitUtilization: Identifiable, Codable {
    let id: String
    let benefitId: String
    let cardId: String
    let userId: String

    // Period tracking
    let periodStart: Date
    let periodEnd: Date
    let periodType: BenefitPeriod

    // Utilization tracking
    var totalValue: Double              // How much the benefit is worth this period
    var amountUtilized: Double          // How much has been used
    var matchedTransactionIds: [String] // Transaction IDs that matched this benefit

    // Manual tracking
    var isManuallyMarked: Bool          // User marked as claimed
    var manualNote: String?             // User note
    var manualClaimDate: Date?          // When user marked it

    // Timestamps
    let createdAt: Date
    var updatedAt: Date

    // MARK: - Computed Properties

    var amountRemaining: Double {
        max(0, totalValue - amountUtilized)
    }

    var utilizationPercentage: Double {
        guard totalValue > 0 else { return 0 }
        return min(1.0, amountUtilized / totalValue)
    }

    var status: UtilizationStatus {
        if periodEnd < Date() && utilizationPercentage < 1.0 {
            return .expired
        }
        if requiresAction {
            return .requiresAction
        }
        if utilizationPercentage >= 0.95 {
            return .maximized
        }
        if utilizationPercentage > 0 {
            return .inProgress
        }
        return .notStarted
    }

    var requiresAction: Bool {
        // Placeholder - will be populated based on benefit.requiresEnrollment
        false
    }

    var isExpiringSoon: Bool {
        let daysUntilExpiry = Calendar.current.dateComponents([.day], from: Date(), to: periodEnd).day ?? 0
        return daysUntilExpiry <= 30 && daysUntilExpiry > 0 && utilizationPercentage < 1.0
    }

    var daysUntilExpiry: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: periodEnd).day ?? 0
    }

    // MARK: - Initializers

    init(
        id: String = UUID().uuidString,
        benefitId: String,
        cardId: String,
        userId: String,
        periodStart: Date,
        periodEnd: Date,
        periodType: BenefitPeriod,
        totalValue: Double,
        amountUtilized: Double = 0,
        matchedTransactionIds: [String] = [],
        isManuallyMarked: Bool = false,
        manualNote: String? = nil,
        manualClaimDate: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.benefitId = benefitId
        self.cardId = cardId
        self.userId = userId
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.periodType = periodType
        self.totalValue = totalValue
        self.amountUtilized = amountUtilized
        self.matchedTransactionIds = matchedTransactionIds
        self.isManuallyMarked = isManuallyMarked
        self.manualNote = manualNote
        self.manualClaimDate = manualClaimDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Utilization Status

enum UtilizationStatus: String, Codable {
    case notStarted      // Period active, nothing used
    case inProgress      // Partially used
    case maximized       // Fully used (95%+)
    case expired         // Period ended, not fully used
    case requiresAction  // Needs enrollment or manual claim

    var displayName: String {
        switch self {
        case .notStarted: return "Not Used"
        case .inProgress: return "In Progress"
        case .maximized: return "Maximized"
        case .expired: return "Expired"
        case .requiresAction: return "Action Needed"
        }
    }

    var iconName: String {
        switch self {
        case .notStarted: return "circle"
        case .inProgress: return "circle.lefthalf.filled"
        case .maximized: return "checkmark.circle.fill"
        case .expired: return "xmark.circle"
        case .requiresAction: return "exclamationmark.circle.fill"
        }
    }
}

// MARK: - Manual Benefit Claim

/// Represents a manual claim for a benefit that can't be auto-detected
struct ManualBenefitClaim: Identifiable, Codable {
    let id: String
    let benefitId: String
    let cardId: String
    let userId: String
    let claimDate: Date
    let amount: Double
    let note: String?
    let receiptImageUrl: String?
    let createdAt: Date

    init(
        id: String = UUID().uuidString,
        benefitId: String,
        cardId: String,
        userId: String,
        claimDate: Date = Date(),
        amount: Double,
        note: String? = nil,
        receiptImageUrl: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.benefitId = benefitId
        self.cardId = cardId
        self.userId = userId
        self.claimDate = claimDate
        self.amount = amount
        self.note = note
        self.receiptImageUrl = receiptImageUrl
        self.createdAt = createdAt
    }
}

// MARK: - Period Helpers

struct BenefitPeriodHelper {

    /// Get current period boundaries for a benefit
    static func currentPeriod(
        for period: BenefitPeriod,
        cardAnniversaryDate: Date? = nil
    ) -> (start: Date, end: Date) {
        let now = Date()
        let calendar = Calendar.current

        switch period {
        case .monthly:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let end = calendar.date(byAdding: .month, value: 1, to: start)!.addingTimeInterval(-1)
            return (start, end)

        case .calendarYear:
            let year = calendar.component(.year, from: now)
            let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
            let end = calendar.date(from: DateComponents(year: year, month: 12, day: 31, hour: 23, minute: 59, second: 59))!
            return (start, end)

        case .cardmemberYear:
            guard let anniversary = cardAnniversaryDate else {
                // Fall back to calendar year if no anniversary date
                return currentPeriod(for: .calendarYear)
            }
            let anniversaryMonth = calendar.component(.month, from: anniversary)
            let anniversaryDay = calendar.component(.day, from: anniversary)
            let thisYear = calendar.component(.year, from: now)

            var start = calendar.date(from: DateComponents(
                year: thisYear, month: anniversaryMonth, day: anniversaryDay
            ))!

            if start > now {
                start = calendar.date(byAdding: .year, value: -1, to: start)!
            }
            let end = calendar.date(byAdding: .year, value: 1, to: start)!.addingTimeInterval(-1)
            return (start, end)

        case .oneTime:
            // Use a 4-year period for one-time benefits (e.g., Global Entry valid for 4 years)
            // Using actual dates to avoid Firestore timestamp range issues
            let year = calendar.component(.year, from: now)
            let start = calendar.date(from: DateComponents(year: year - 4, month: 1, day: 1))!
            let end = calendar.date(from: DateComponents(year: year + 4, month: 12, day: 31, hour: 23, minute: 59, second: 59))!
            return (start, end)
        }
    }

    /// Calculate benefit value for a specific period
    static func periodValue(for benefit: CreditCardBenefit, periodStart: Date, periodEnd: Date) -> Double {
        switch benefit.frequency {
        case .annual:
            return benefit.amount
        case .monthly:
            // Calculate how many months in this period
            let calendar = Calendar.current
            var total = 0.0
            var currentDate = periodStart

            while currentDate < periodEnd {
                let month = calendar.component(.month, from: currentDate)
                total += benefit.amountForMonth(month)
                currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? periodEnd
            }
            return total
        case .perTransaction:
            return benefit.amount * 12 // Simplified
        }
    }
}
