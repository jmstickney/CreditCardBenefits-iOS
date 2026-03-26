//
//  BackgroundRefreshManager.swift
//  CreditCardBenefits
//
//  Periodically syncs transactions and reprocesses benefits in the background
//

import BackgroundTasks
import FirebaseAuth
import FirebaseCore

final class BackgroundRefreshManager {

    static let shared = BackgroundRefreshManager()
    static let taskIdentifier = "com.creditcardbenefits.refresh"

    private init() {}

    // MARK: - Registration

    /// Registers the background refresh task. Must be called during app launch.
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            self.handleAppRefresh(task: refreshTask)
        }
    }

    // MARK: - Scheduling

    /// Schedules the next background refresh (~6 hours from now).
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 60 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background refresh scheduled")
        } catch {
            print("Failed to schedule background refresh: \(error)")
        }
    }

    // MARK: - Task Handler

    private func handleAppRefresh(task: BGAppRefreshTask) {
        // Schedule the next refresh immediately
        scheduleAppRefresh()

        let refreshOperation = Task {
            await performBackgroundRefresh()
        }

        task.expirationHandler = {
            refreshOperation.cancel()
        }

        Task {
            await refreshOperation.value
            task.setTaskCompleted(success: true)
        }
    }

    // MARK: - Background Refresh Logic

    @MainActor
    private func performBackgroundRefresh() async {
        guard FirebaseApp.app() != nil else {
            print("BG Refresh: Firebase not initialized, skipping")
            return
        }

        guard let user = Auth.auth().currentUser else {
            print("BG Refresh: Not authenticated, skipping")
            return
        }

        guard let isLinked = CacheManager.shared.load(Bool.self, for: .isLinked), isLinked else {
            print("BG Refresh: No Plaid connection, skipping")
            return
        }

        print("BG Refresh: Starting background data refresh")

        let plaidService = PlaidService()
        let utilizationService = BenefitUtilizationService()
        let cache = CacheManager.shared

        let hasConnection = await plaidService.checkExistingConnection()
        guard hasConnection else {
            print("BG Refresh: Connection check failed, skipping")
            return
        }

        await plaidService.fetchTransactions()

        guard !plaidService.transactions.isEmpty else {
            print("BG Refresh: No transactions fetched")
            return
        }

        // Load user cards from cache (don't re-detect, use saved cards)
        let userCards = cache.load([CreditCard].self, for: .userCards) ?? []

        // Reprocess subscriptions and benefit matches
        let subscriptions = (try? SubscriptionDetector.detectSubscriptions(
            from: plaidService.transactions
        )) ?? []

        let benefitMatches = (try? BenefitMatcher.matchBenefits(
            subscriptions: subscriptions,
            userCards: userCards
        )) ?? []

        // Process utilizations
        await utilizationService.loadUtilizations(for: user.uid)
        let _ = await utilizationService.processTransactions(
            plaidService.transactions,
            userCards: userCards,
            userId: user.uid
        )
        try? await utilizationService.saveAllUtilizations(userId: user.uid)

        // Save everything to cache
        cache.save(plaidService.transactions, for: .transactions)
        cache.save(plaidService.accounts, for: .plaidAccounts)
        cache.save(plaidService.isLinked, for: .isLinked)
        cache.save(plaidService.dataSource, for: .dataSource)
        cache.save(subscriptions, for: .subscriptions)
        cache.save(benefitMatches, for: .benefitMatches)
        cache.save(utilizationService.utilizations, for: .benefitUtilizations)
        cache.save(Date(), for: .lastRefreshDate)

        print("BG Refresh: Completed, cached \(plaidService.transactions.count) transactions")
    }
}
