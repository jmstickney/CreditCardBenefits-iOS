//
//  NotificationManager.swift
//  CreditCardBenefits
//
//  Local notifications for benefit reminders
//

import UserNotifications
import Foundation

final class NotificationManager {

    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    private init() {}

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

    // MARK: - Cancel All

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
