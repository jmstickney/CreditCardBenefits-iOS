//
//  BackgroundRefreshManager.swift
//  CreditCardBenefits
//
//  Periodically syncs transactions and reprocesses benefits in the background
//

import BackgroundTasks
import FirebaseAuth
import FirebaseCore
import UIKit

final class BackgroundRefreshManager {

    static let shared = BackgroundRefreshManager()
    static let refreshTaskIdentifier = "com.creditcardbenefits.refresh"
    static let processingTaskIdentifier = "com.creditcardbenefits.processing"

    private init() {}

    // MARK: - Registration

    /// Registers background tasks. Must be called during app launch.
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.refreshTaskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            self.handleAppRefresh(task: refreshTask)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.processingTaskIdentifier,
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else { return }
            self.handleProcessingTask(task: processingTask)
        }

        // Refresh when app returns to foreground with stale data
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleForegroundReturn),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    // MARK: - Scheduling

    /// Schedules both background refresh and processing tasks.
    func scheduleAppRefresh() {
        // App refresh task (~6 hours, lightweight)
        let refreshRequest = BGAppRefreshTaskRequest(identifier: Self.refreshTaskIdentifier)
        refreshRequest.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 60 * 60)

        do {
            try BGTaskScheduler.shared.submit(refreshRequest)
            benLog("Background refresh scheduled")
        } catch {
            benLog("Failed to schedule background refresh: \(error)")
        }

        // Processing task (~12 hours, more runtime allowed by OS)
        let processingRequest = BGProcessingTaskRequest(identifier: Self.processingTaskIdentifier)
        processingRequest.earliestBeginDate = Date(timeIntervalSinceNow: 12 * 60 * 60)
        processingRequest.requiresNetworkConnectivity = true

        do {
            try BGTaskScheduler.shared.submit(processingRequest)
            benLog("Background processing task scheduled")
        } catch {
            benLog("Failed to schedule background processing: \(error)")
        }
    }

    // MARK: - Foreground Return

    @objc private func handleForegroundReturn() {
        guard CacheManager.shared.needsForegroundRefresh else { return }
        benLog("Foreground return: cache is stale, triggering refresh")
        Task {
            await performBackgroundRefresh()
        }
    }

    // MARK: - Task Handlers

    private func handleAppRefresh(task: BGAppRefreshTask) {
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

    private func handleProcessingTask(task: BGProcessingTask) {
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
            benLog("BG Refresh: Firebase not initialized, skipping")
            return
        }

        guard let user = Auth.auth().currentUser else {
            benLog("BG Refresh: Not authenticated, skipping")
            return
        }

        guard let isLinked = CacheManager.shared.load(Bool.self, for: .isLinked), isLinked else {
            benLog("BG Refresh: No Plaid connection, skipping")
            return
        }

        benLog("BG Refresh: Starting background data refresh")

        let plaidService = PlaidService()
        let utilizationService = BenefitUtilizationService()
        let cache = CacheManager.shared

        let hasConnection = await plaidService.checkExistingConnection()
        guard hasConnection else {
            benLog("BG Refresh: Connection check failed, skipping")
            return
        }

        await plaidService.fetchTransactions()

        guard !plaidService.transactions.isEmpty else {
            benLog("BG Refresh: No transactions fetched")
            return
        }

        // Load user cards from cache (don't re-detect, use saved cards).
        // Rehydrate from CreditCardsData so new benefits added in code updates
        // are picked up instead of frozen at whatever was cached.
        let cachedCards = cache.load([CreditCard].self, for: .userCards) ?? []
        let userCards = cachedCards.compactMap { CreditCardsData.getCard(by: $0.id) ?? $0 }

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

        benLog("BG Refresh: Completed, cached \(plaidService.transactions.count) transactions")
    }
}
