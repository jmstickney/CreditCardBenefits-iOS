//
//  NotificationManager.swift
//  CreditCardBenefits
//
//  Local notifications for benefit reminders
//

import UserNotifications
import Foundation

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    private override init() { super.init() }

    // MARK: - Foreground Presentation

    /// Show benefit notifications even when the app is open (iOS suppresses the
    /// banner by default). Set as the center delegate at launch.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    // MARK: - Permission

    /// Requests notification permission. Call after onboarding completes.
    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            benLog(granted ? "✅ Notifications authorized" : "❌ Notifications denied")
            return granted
        } catch {
            benLog("❌ Notification permission error: \(error)")
            return false
        }
    }

    /// Checks current authorization status
    func isAuthorized() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    // MARK: - Schedule Benefit Reminders

    /// Reschedules all notifications based on current utilization data.
    /// Call this whenever utilization data changes.
    func scheduleReminders(
        utilizations: [BenefitUtilization],
        userCards: [CreditCard],
        cardMatches: [CardMatch]
    ) async {
        // Remove all existing scheduled notifications
        center.removeAllPendingNotificationRequests()

        guard await isAuthorized() else { return }

        var scheduled = 0

        for utilization in utilizations {
            guard let card = userCards.first(where: { $0.id == utilization.cardId }),
                  let benefit = card.benefits.first(where: { $0.id == utilization.benefitId }) else {
                continue
            }

            // Skip fully utilized benefits
            if utilization.utilizationPercentage >= 1.0 { continue }

            // Expiring soon: benefit period ends within 7 days
            let daysUntilExpiry = utilization.daysUntilExpiry
            if daysUntilExpiry > 0 && daysUntilExpiry <= 7 {
                let content = UNMutableNotificationContent()
                content.title = "Benefit expiring soon"
                content.body = "\(benefit.name) on your \(card.name) resets in \(daysUntilExpiry) day\(daysUntilExpiry == 1 ? "" : "s"). \(utilization.amountRemaining.asCurrency()) remaining."
                content.sound = .default

                // Notify tomorrow morning at 9 AM
                var dateComponents = DateComponents()
                dateComponents.hour = 9
                dateComponents.minute = 0
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

                let request = UNNotificationRequest(
                    identifier: "expiring-\(utilization.id)",
                    content: content,
                    trigger: trigger
                )
                try? await center.add(request)
                scheduled += 1
            }

            // Monthly reset reminder: notify on the 28th of each month for monthly benefits
            if benefit.period == .monthly && daysUntilExpiry > 0 && daysUntilExpiry <= 3 {
                let content = UNMutableNotificationContent()
                content.title = "Monthly credit resets soon"
                content.body = "Your \(benefit.name) (\(benefit.amount.asCurrency())) on \(card.name) resets in \(daysUntilExpiry) day\(daysUntilExpiry == 1 ? "" : "s"). Use it or lose it!"
                content.sound = .default

                var dateComponents = DateComponents()
                dateComponents.hour = 10
                dateComponents.minute = 0
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

                let request = UNNotificationRequest(
                    identifier: "monthly-reset-\(utilization.id)",
                    content: content,
                    trigger: trigger
                )
                try? await center.add(request)
                scheduled += 1
            }
        }

        // Weekly unused benefits nudge (every Sunday at 10 AM)
        let unusedCount = utilizations.filter { $0.amountUtilized == 0 }.count
        let unusedValue = utilizations.filter { $0.amountUtilized == 0 }.reduce(0.0) { $0 + $1.totalValue }
        if unusedCount > 0 {
            let content = UNMutableNotificationContent()
            content.title = "You have unused benefits"
            content.body = "\(unusedCount) benefit\(unusedCount == 1 ? "" : "s") worth \(unusedValue.asCurrency()) \(unusedCount == 1 ? "is" : "are") waiting. Open Ben to see what you're missing."
            content.sound = .default

            var dateComponents = DateComponents()
            dateComponents.weekday = 1  // Sunday
            dateComponents.hour = 10
            dateComponents.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

            let request = UNNotificationRequest(
                identifier: "weekly-unused",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
            scheduled += 1
        }

        // Anniversary date reminder
        for match in cardMatches {
            guard let anniversaryDate = match.anniversaryDate,
                  let card = match.creditCard else { continue }

            // Remind 7 days before anniversary
            let calendar = Calendar.current
            var nextAnniversary = calendar.date(
                bySetting: .year,
                value: calendar.component(.year, from: Date()),
                of: anniversaryDate
            ) ?? anniversaryDate

            // If anniversary already passed this year, use next year
            if nextAnniversary < Date() {
                nextAnniversary = calendar.date(byAdding: .year, value: 1, to: nextAnniversary) ?? nextAnniversary
            }

            if let reminderDate = calendar.date(byAdding: .day, value: -7, to: nextAnniversary),
               reminderDate > Date() {
                let content = UNMutableNotificationContent()
                content.title = "Card anniversary approaching"
                content.body = "Your \(card.name) anniversary is in 7 days. Annual benefits will reset — make sure you've used them!"
                content.sound = .default

                let components = calendar.dateComponents([.year, .month, .day, .hour], from: reminderDate)
                var triggerComponents = components
                triggerComponents.hour = 9
                let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)

                let request = UNNotificationRequest(
                    identifier: "anniversary-\(card.id)",
                    content: content,
                    trigger: trigger
                )
                try? await center.add(request)
                scheduled += 1
            }
        }

        benLog("✅ Scheduled \(scheduled) notification reminders")
    }

    // MARK: - Benefit Auto-Match Notifications

    /// How recent a matched transaction must be to be notification-worthy.
    /// Guards against a flood when older statement credits backfill (e.g. after
    /// assigning a newly-added card).
    private static let matchRecencyDays = 14

    /// UserDefaults key backing the "notify me when a benefit is auto-tracked"
    /// Settings toggle. Bound via @AppStorage in SettingsView; read here.
    static let benefitMatchNotificationsKey = "notifyOnBenefitMatch"

    /// UserDefaults key backing the "wrong-card alerts" Settings toggle.
    static let missedBenefitNotificationsKey = "notifyOnMissedBenefit"

    /// Whether the user wants benefit auto-match notifications. Defaults ON when
    /// they haven't set a preference.
    private var benefitMatchNotificationsEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.benefitMatchNotificationsKey) as? Bool ?? true
    }

    /// Whether the user wants wrong-card alerts. Defaults ON.
    private var missedBenefitNotificationsEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.missedBenefitNotificationsKey) as? Bool ?? true
    }

    /// Fires a local notification when Ben auto-detects that a benefit credit was
    /// used (a new transaction matched an auto-detect benefit). Safe to call after
    /// every processing pass — it de-dupes against a persisted set of already-
    /// notified transaction IDs and seeds a silent baseline on first run so it
    /// never fires for a user's historical matches.
    func notifyNewlyMatchedBenefits(
        utilizations: [BenefitUtilization],
        userCards: [CreditCard],
        transactions: [Transaction]
    ) async {
        let txnById = Dictionary(transactions.map { ($0.id, $0) },
                                 uniquingKeysWith: { first, _ in first })
        let recentCutoff = Calendar.current.date(
            byAdding: .day, value: -Self.matchRecencyDays, to: Date()
        ) ?? .distantPast

        let seenList = CacheManager.shared.load([String].self, for: .notifiedMatchIds)
        let seen = Set(seenList ?? [])

        var currentMatchedIds = Set<String>()
        var events: [MatchEvent] = []

        for utilization in utilizations {
            guard let benefit = CreditCardsData.getBenefit(by: utilization.benefitId),
                  benefit.canAutoDetect else { continue }
            let cardName = userCards.first(where: { $0.id == utilization.cardId })?.name
                ?? CreditCardsData.getCard(by: utilization.cardId)?.name
                ?? "your card"

            for txnId in utilization.matchedTransactionIds {
                currentMatchedIds.insert(txnId)
                guard !seen.contains(txnId), let txn = txnById[txnId] else { continue }
                if txn.date >= recentCutoff {
                    events.append(MatchEvent(benefit: benefit, cardName: cardName, transaction: txn))
                }
            }
        }

        // First run for this user: record the baseline silently so we don't
        // notify for everything that was already matched before this feature ran.
        guard seenList != nil else {
            CacheManager.shared.save(Array(currentMatchedIds), for: .notifiedMatchIds)
            return
        }

        guard !events.isEmpty else { return }

        // Even if we don't fire, mark these as seen so we don't queue a backlog
        // to fire the moment the user re-enables the toggle / grants permission.
        let persistSeen = { CacheManager.shared.save(Array(seen.union(currentMatchedIds)), for: .notifiedMatchIds) }

        guard benefitMatchNotificationsEnabled else {
            persistSeen()
            return
        }

        guard await isAuthorized() else {
            persistSeen()
            return
        }

        await fireMatchNotifications(events)
        persistSeen()
    }

    private struct MatchEvent {
        let benefit: CreditCardBenefit
        let cardName: String
        let transaction: Transaction
    }

    private func fireMatchNotifications(_ events: [MatchEvent]) async {
        // A handful → notify individually; a burst → collapse into one summary.
        if events.count <= 3 {
            for event in events {
                let content = UNMutableNotificationContent()
                content.title = "Benefit credit tracked ✅"
                content.body = "\(event.transaction.amount.asCurrency()) toward your "
                    + "\(event.benefit.name) on \(event.cardName)"
                    + " — detected at \(event.transaction.merchant)."
                content.sound = .default

                let request = UNNotificationRequest(
                    identifier: "match-\(event.transaction.id)",
                    content: content,
                    trigger: nil // deliver immediately
                )
                try? await center.add(request)
            }
        } else {
            let total = events.reduce(0.0) { $0 + $1.transaction.amount }
            let content = UNMutableNotificationContent()
            content.title = "Benefit credits tracked ✅"
            content.body = "Ben detected \(events.count) benefit credits worth "
                + "\(total.asCurrency()). Open Ben to see the details."
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "match-summary-\(Int(Date().timeIntervalSince1970))",
                content: content,
                trigger: nil
            )
            try? await center.add(request)
        }

        benLog("🔔 Fired benefit-match notifications: \(events.count)")
    }

    // MARK: - Wrong-Card (Missed Benefit) Alerts

    /// Alerts when spend is detected on a card that doesn't carry a benefit
    /// another connected card does. First run sends ONE summary for whatever
    /// already exists in history; afterwards only newly detected purchases
    /// (≤14 days old) alert. De-dupes via a persisted set of transaction ids.
    func notifyMissedBenefits(_ opportunities: [MissedBenefitOpportunity]) async {
        let currentIds = Set(
            opportunities.flatMap { $0.matchedTransactions.map(\.id) }
        )

        let seenList = CacheManager.shared.load(
            [String].self, for: .notifiedOpportunityTxnIds
        )
        let seen = Set(seenList ?? [])
        let persistSeen = {
            CacheManager.shared.save(
                Array(seen.union(currentIds)), for: .notifiedOpportunityTxnIds
            )
        }

        guard missedBenefitNotificationsEnabled, await isAuthorized() else {
            // Mark as seen so re-enabling doesn't dump a backlog of alerts.
            persistSeen()
            return
        }

        // First run: one summary covering the existing backlog (user opted in
        // to hearing about current misses once), then new-only.
        guard seenList != nil else {
            if !opportunities.isEmpty {
                let content = UNMutableNotificationContent()
                content.title = "You may be using the wrong card 💳"
                content.body = opportunities.count == 1
                    ? singleOpportunityBody(opportunities[0])
                    : "Ben found \(opportunities.count) purchases that a different card's benefits could cover. Check Savings Opportunities."
                content.sound = .default
                let request = UNNotificationRequest(
                    identifier: "missed-baseline",
                    content: content,
                    trigger: nil
                )
                try? await center.add(request)
                benLog("🔔 Missed-benefit baseline alert (\(opportunities.count))")
            }
            persistSeen()
            return
        }

        // Only opportunities with a NEW, recent transaction alert.
        let recentCutoff = Calendar.current.date(
            byAdding: .day, value: -Self.matchRecencyDays, to: Date()
        ) ?? .distantPast
        let newOpportunities = opportunities.filter { opp in
            opp.matchedTransactions.contains {
                !seen.contains($0.id) && $0.date >= recentCutoff
            }
        }
        guard !newOpportunities.isEmpty else {
            if !currentIds.subtracting(seen).isEmpty { persistSeen() }
            return
        }

        if newOpportunities.count <= 3 {
            for opp in newOpportunities {
                let content = UNMutableNotificationContent()
                content.title = "Wrong card for \(opp.merchantDisplayName)?"
                content.body = singleOpportunityBody(opp)
                content.sound = .default
                let request = UNNotificationRequest(
                    identifier: "missed-\(opp.key)-\(Int(opp.latestDate.timeIntervalSince1970))",
                    content: content,
                    trigger: nil
                )
                try? await center.add(request)
            }
        } else {
            let content = UNMutableNotificationContent()
            content.title = "You may be using the wrong card 💳"
            content.body = "Ben found \(newOpportunities.count) recent purchases that a different card's benefits could cover. Check Savings Opportunities."
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "missed-summary-\(Int(Date().timeIntervalSince1970))",
                content: content,
                trigger: nil
            )
            try? await center.add(request)
        }

        benLog("🔔 Missed-benefit alerts: \(newOpportunities.count)")
        persistSeen()
    }

    private func singleOpportunityBody(_ opp: MissedBenefitOpportunity) -> String {
        let paidOn = opp.paidCardNames.first ?? "another card"
        return "You paid \(opp.merchantDisplayName) with \(paidOn) — "
            + "your \(opp.coveringCard.name)'s \(opp.benefit.name) "
            + "(worth up to \(opp.benefit.annualAmount.asCurrency())/yr) could cover it."
    }

    // MARK: - Cancel All

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
