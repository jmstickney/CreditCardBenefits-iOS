//
//  PlaidService.swift
//  CreditCardBenefits
//
//  Plaid Link integration service
//

import Foundation
import FirebaseCore
import FirebaseFunctions
import FirebaseFirestore
import FirebaseAuth
import Combine
import LinkKit

class PlaidService: ObservableObject {
    @Published var isLinked = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var transactions: [Transaction] = []
    @Published var accounts: [PlaidAccount] = []
    @Published var dataSource: DataSource = .none
    /// Per-item connection status (which banks need re-authentication).
    @Published var itemStatuses: [PlaidItemStatus] = []

    /// Items whose bank login expired and need the user to reconnect.
    var itemsNeedingReconnect: [PlaidItemStatus] {
        itemStatuses.filter { $0.needsReconnect }
    }

    var needsReconnect: Bool { !itemsNeedingReconnect.isEmpty }

    /// True while a freshly connected bank's transaction history is still
    /// backfilling (drives the "importing history" notice).
    var isImportingHistory: Bool {
        itemStatuses.contains { !$0.historicalComplete }
    }

    private var historyMonitorTask: Task<Void, Never>?

    private let functions = Functions.functions()
    private let db = Firestore.firestore()
    private var transactionsListener: ListenerRegistration?

    // MARK: - Check Existing Connection

    /// Checks if the user has an existing Plaid connection by attempting to fetch accounts
    /// Returns true if connected, false otherwise
    func checkExistingConnection() async -> Bool {
        await MainActor.run {
            isLoading = true
        }

        do {
            // Try to fetch accounts - if this succeeds, we're connected
            let result = try await functions.httpsCallable("getAccounts").call()

            guard let data = result.data as? [String: Any],
                  let accountsData = data["accounts"] as? [[String: Any]] else {
                await MainActor.run {
                    self.isLinked = false
                    self.dataSource = .none
                    self.isLoading = false
                }
                return false
            }

            // We have accounts, so we're connected
            let parsedAccounts = parseAccounts(accountsData)

            await MainActor.run {
                self.accounts = parsedAccounts
                self.isLinked = !parsedAccounts.isEmpty
                self.dataSource = parsedAccounts.isEmpty ? .none : .plaid
                self.isLoading = false
            }

            if !parsedAccounts.isEmpty {
                benLog("✅ Restored connection: Found \(parsedAccounts.count) accounts")
                return true
            } else {
                benLog("ℹ️ No existing Plaid accounts found")
                return false
            }

        } catch {
            await MainActor.run {
                self.isLinked = false
                self.dataSource = .none
                self.isLoading = false
            }
            benLog("ℹ️ No existing Plaid connection: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Create Link Token

    /// Creates a link token from Firebase Cloud Function
    func createLinkToken() async throws -> String {
        await MainActor.run {
            isLoading = true
        }

        do {
            let result = try await functions.httpsCallable("createLinkToken").call()

            guard let data = result.data as? [String: Any],
                  let linkToken = data["link_token"] as? String else {
                await MainActor.run {
                    isLoading = false
                }
                throw PlaidError.invalidResponse
            }

            await MainActor.run {
                isLoading = false
            }

            benLog("✅ Link token created")
            return linkToken

        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
            throw error
        }
    }

    // MARK: - Present Plaid Link

    /// Presents Plaid Link UI to user
    func presentPlaidLink(from viewController: UIViewController) async {
        await MainActor.run {
            isLoading = true
        }

        do {
            // Create link token on background thread (network call)
            let linkToken = try await createLinkToken()

            // UI operations must be on main thread
            await MainActor.run {
                benLog("🟢 Creating LinkTokenConfiguration...")
                var linkConfiguration = LinkTokenConfiguration(
                    token: linkToken
                ) { [weak self] success in
                    benLog("✅ Plaid Link success (public token received)")
                    Task {
                        await self?.exchangePublicToken(success.publicToken)
                    }
                }

                linkConfiguration.onExit = { [weak self] exit in
                    benLog("ℹ️ User exited Plaid Link: \(exit.metadata)")
                    Task { @MainActor in
                        self?.isLoading = false
                    }
                }

                benLog("🟢 Calling Plaid.create()...")
                let result = Plaid.create(linkConfiguration)
                switch result {
                case .success(let handler):
                    benLog("🟢 Plaid.create() succeeded, opening handler...")
                    benLog("🟢 View controller type: \(type(of: viewController))")

                    // Use .custom presentation mode for better compatibility
                    handler.open(presentUsing: .custom { linkViewController in
                        benLog("🟢 Custom presentation block called")
                        // Ensure presentation happens on main thread
                        DispatchQueue.main.async {
                            benLog("🟢 Presenting on main thread...")
                            viewController.present(linkViewController, animated: true) {
                                benLog("🟢 Modal presented successfully")
                            }
                        }
                    })
                    benLog("🟢 Handler.open() called")
                    self.isLoading = false
                case .failure(let error):
                    self.error = error.localizedDescription
                    self.isLoading = false
                    benLog("❌ Plaid.create() failed: \(error)")
                }
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
            benLog("❌ Error creating link token: \(error.localizedDescription)")
        }
    }

    // MARK: - Exchange Public Token

    /// Exchanges public token for access token (called after user connects bank)
    func exchangePublicToken(_ publicToken: String) async {
        await MainActor.run {
            isLoading = true
        }

        do {
            let result = try await functions.httpsCallable("exchangePublicToken").call([
                "publicToken": publicToken
            ])

            guard let data = result.data as? [String: Any],
                  let success = data["success"] as? Bool,
                  success else {
                throw PlaidError.exchangeFailed
            }

            await MainActor.run {
                self.isLinked = true
                self.dataSource = .plaid
                self.isLoading = false
            }

            benLog("✅ Public token exchanged successfully")

            // Fetch accounts; start the live transactions listener; and ask the
            // server to pull transactions now (a safety net beyond the webhook).
            await fetchAccounts()
            startTransactionsListener()
            await refreshTransactions()
            // Surfaces the "importing history" notice + starts its monitor.
            await fetchItemsStatus()

        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
            benLog("❌ Error exchanging token: \(error.localizedDescription)")
        }
    }

    // MARK: - Populate Demo Data

    /// Populates Firestore with demo transaction data (no Plaid needed)
    func populateDemoData() async throws {
        await MainActor.run {
            isLoading = true
        }

        do {
            let result = try await functions.httpsCallable("populateDemoData").call()

            guard let data = result.data as? [String: Any],
                  let success = data["success"] as? Bool,
                  let transactionCount = data["transactionCount"] as? Int,
                  success else {
                throw PlaidError.invalidResponse
            }

            await MainActor.run {
                self.isLinked = true
                self.dataSource = .demo
                self.isLoading = false
            }

            benLog("✅ Demo data populated: \(transactionCount) transactions created")

            // Demo transactions were written server-side; stream them in.
            startTransactionsListener()

        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
            benLog("❌ Error populating demo data: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Disconnect

    /// Disconnects the bank account and clears local data
    func disconnect() async {
        // Remove the items at Plaid + delete their stored data so nothing is
        // left orphaned server-side (which previously caused duplicate
        // connections on reconnect). Best-effort: clear locally regardless.
        do {
            _ = try await functions.httpsCallable("disconnectAllBanks").call()
            benLog("✅ Bank disconnected server-side")
        } catch {
            benLog("⚠️ Server disconnect failed, clearing locally anyway: \(error.localizedDescription)")
        }

        stopTransactionsListener()
        historyMonitorTask?.cancel()
        historyMonitorTask = nil
        await MainActor.run {
            self.isLinked = false
            self.dataSource = .none
            self.transactions = []
            self.accounts = []
            self.itemStatuses = []
        }
        benLog("✅ Bank disconnected locally")
    }

    // MARK: - Fetch Accounts

    /// Fetches account metadata from Plaid via Firebase Cloud Function
    func fetchAccounts() async {
        await MainActor.run {
            isLoading = true
        }

        do {
            let result = try await functions.httpsCallable("getAccounts").call()

            guard let data = result.data as? [String: Any],
                  let accountsData = data["accounts"] as? [[String: Any]] else {
                throw PlaidError.invalidResponse
            }

            // Parse accounts
            let parsedAccounts = parseAccounts(accountsData)

            await MainActor.run {
                self.accounts = parsedAccounts
                self.isLoading = false
            }

            benLog("✅ Fetched \(parsedAccounts.count) accounts")

        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
            benLog("❌ Error fetching accounts: \(error.localizedDescription)")
        }
    }

    private func parseAccounts(_ data: [[String: Any]]) -> [PlaidAccount] {
        return data.compactMap { dict -> PlaidAccount? in
            guard let accountId = dict["account_id"] as? String,
                  let name = dict["name"] as? String,
                  let type = dict["type"] as? String else {
                return nil
            }

            return PlaidAccount(
                id: accountId,
                name: name,
                officialName: dict["official_name"] as? String,
                type: type,
                subtype: dict["subtype"] as? String,
                mask: dict["mask"] as? String,
                itemId: dict["item_id"] as? String
            )
        }
    }

    // MARK: - Transactions (Firestore-backed)

    /// Firestore query for the signed-in user's transactions, newest first.
    private func transactionsQuery() -> Query? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return db.collection("users").document(uid)
            .collection("transactions")
            .order(by: "date", descending: true)
    }

    /// Streams the user's transactions from Firestore so the UI updates live as
    /// the server syncs them in. Safe to call repeatedly.
    func startTransactionsListener() {
        guard let query = transactionsQuery() else { return }
        transactionsListener?.remove()
        transactionsListener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            if let error = error {
                benLog("❌ Transactions listener error: \(error.localizedDescription)")
                return
            }
            let dicts = snapshot?.documents.map { $0.data() } ?? []
            let parsed = self.parseTransactions(dicts)
            self.transactions = parsed
            if !parsed.isEmpty { self.isLinked = true }
            benLog("✅ Transactions updated: \(parsed.count)")
        }
    }

    /// Stops the live transactions listener (e.g. on sign-out / disconnect).
    func stopTransactionsListener() {
        transactionsListener?.remove()
        transactionsListener = nil
    }

    /// One-shot read of stored transactions, for contexts where a listener is
    /// not appropriate (e.g. background refresh).
    func fetchStoredTransactions() async {
        guard let query = transactionsQuery() else { return }
        do {
            let snapshot = try await query.getDocuments()
            let parsed = parseTransactions(snapshot.documents.map { $0.data() })
            await MainActor.run { self.transactions = parsed }
            benLog("✅ Loaded \(parsed.count) stored transactions")
        } catch {
            benLog("❌ Error loading stored transactions: \(error.localizedDescription)")
        }
    }

    /// Asks the server to pull the latest transactions from Plaid (via
    /// /transactions/sync). Results arrive through the Firestore listener.
    func refreshTransactions() async {
        do {
            _ = try await functions.httpsCallable("refreshTransactions").call()
            benLog("✅ Requested server transaction sync")
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
            benLog("❌ refreshTransactions error: \(error.localizedDescription)")
        }
    }

    // MARK: - Reconnect (Plaid update mode)

    /// Fetches each item's connection status so the UI can prompt a reconnect
    /// when a bank login has expired. Never touches access tokens.
    func fetchItemsStatus() async {
        do {
            let result = try await functions.httpsCallable("getItemsStatus").call()
            guard let data = result.data as? [String: Any],
                  let items = data["items"] as? [[String: Any]] else { return }
            let parsed = items.compactMap { dict -> PlaidItemStatus? in
                guard let itemId = dict["itemId"] as? String else { return nil }
                let ms = (dict["lastSyncedAt"] as? NSNumber)?.doubleValue
                return PlaidItemStatus(
                    itemId: itemId,
                    needsReconnect: dict["needsReconnect"] as? Bool ?? false,
                    errorCode: dict["errorCode"] as? String,
                    lastSyncedAt: ms.map { Date(timeIntervalSince1970: $0 / 1000) },
                    historicalComplete: dict["historicalComplete"] as? Bool ?? true
                )
            }
            await MainActor.run { self.itemStatuses = parsed }
            benLog("✅ Item statuses: \(parsed.count), reconnect needed: \(parsed.filter { $0.needsReconnect }.count)")
            startHistoryImportMonitorIfNeeded()
        } catch {
            benLog("❌ getItemsStatus error: \(error.localizedDescription)")
        }
    }

    // MARK: - History Import Monitor

    /// While any item's historical backfill is pending, periodically pulls the
    /// latest transactions + status so the history fills in even if a webhook
    /// is missed. Stops when every item completes (or after a 15-minute cap,
    /// at which point statuses are marked complete locally so the notice
    /// doesn't linger forever).
    private func startHistoryImportMonitorIfNeeded() {
        guard isImportingHistory, historyMonitorTask == nil else { return }

        benLog("⏳ History import in progress — starting monitor")
        historyMonitorTask = Task { [weak self] in
            let deadline = Date().addingTimeInterval(15 * 60)
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(45))
                guard Auth.auth().currentUser != nil else { break }
                guard self.isImportingHistory else { break }

                if Date() > deadline {
                    // Assume done rather than showing the notice indefinitely.
                    await MainActor.run {
                        self.itemStatuses = self.itemStatuses.map { status in
                            var updated = status
                            updated.historicalComplete = true
                            return updated
                        }
                    }
                    break
                }

                await self.refreshTransactions()
                await self.fetchStatusOnly()
            }
            await MainActor.run { [weak self] in self?.historyMonitorTask = nil }
            benLog("✅ History import monitor finished")
        }
    }

    /// Status refresh without re-triggering the monitor (used by the monitor).
    private func fetchStatusOnly() async {
        do {
            let result = try await functions.httpsCallable("getItemsStatus").call()
            guard let data = result.data as? [String: Any],
                  let items = data["items"] as? [[String: Any]] else { return }
            let complete = Dictionary(uniqueKeysWithValues: items.compactMap { dict -> (String, Bool)? in
                guard let itemId = dict["itemId"] as? String else { return nil }
                return (itemId, dict["historicalComplete"] as? Bool ?? true)
            })
            await MainActor.run {
                self.itemStatuses = self.itemStatuses.map { status in
                    var updated = status
                    updated.historicalComplete = complete[status.itemId] ?? true
                    return updated
                }
            }
        } catch {
            benLog("❌ status poll error: \(error.localizedDescription)")
        }
    }

    /// Creates a Plaid Link token in update mode for an existing item, so the
    /// user can re-authenticate without re-adding the card. In update mode the
    /// Link success does NOT produce a token to exchange — the item is fixed in
    /// place, so callers just refresh afterward.
    func createUpdateLinkToken(itemId: String) async throws -> String {
        let result = try await functions
            .httpsCallable("createUpdateLinkToken")
            .call(["itemId": itemId])
        guard let data = result.data as? [String: Any],
              let token = data["link_token"] as? String else {
            throw PlaidError.invalidResponse
        }
        return token
    }

    // MARK: - Helper Methods

    private func parseTransactions(_ data: [[String: Any]]) -> [Transaction] {
        // Plaid returns dates as "YYYY-MM-DD" format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        return data.compactMap { dict -> Transaction? in
            guard let transactionId = dict["transaction_id"] as? String,
                  let dateString = dict["date"] as? String,
                  let merchant = dict["name"] as? String,
                  let accountId = dict["account_id"] as? String else {
                benLog("⚠️ Skipping transaction with missing required fields")
                return nil
            }

            // Firestore may return whole-number amounts as Int, so bridge via
            // NSNumber to robustly get a Double.
            guard let amount = (dict["amount"] as? NSNumber)?.doubleValue else {
                benLog("⚠️ Skipping transaction with invalid amount")
                return nil
            }

            guard let date = dateFormatter.date(from: dateString) else {
                benLog("⚠️ Skipping transaction with invalid date: \(dateString)")
                return nil
            }

            // Plaid returns positive amounts for debits, negative for credits
            let isCredit = amount < 0
            let absAmount = abs(amount)

            // Skip zero-amount transactions
            guard absAmount > 0 else {
                return nil
            }

            // Extract merchant_name if available (Plaid's cleaned merchant name)
            let merchantName = dict["merchant_name"] as? String

            // Extract category if available (Plaid provides category as an array)
            let category: String?
            if let categories = dict["category"] as? [String], !categories.isEmpty {
                category = categories.joined(separator: " > ")
            } else {
                category = nil
            }

            return Transaction(
                id: transactionId,
                date: date,
                merchant: merchant,
                merchantName: merchantName,
                amount: absAmount,
                category: category,
                accountId: accountId,
                isCredit: isCredit
            )
        }
    }
}

// MARK: - Errors

enum PlaidError: Error, LocalizedError {
    case invalidResponse
    case exchangeFailed
    case missingLinkToken

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .exchangeFailed:
            return "Failed to exchange public token"
        case .missingLinkToken:
            return "Link token is missing"
        }
    }
}

// MARK: - Data Source

enum DataSource: String, Codable {
    case none
    case demo
    case plaid

    var displayName: String {
        switch self {
        case .none:
            return "No Data"
        case .demo:
            return "Demo Data"
        case .plaid:
            return "Live Plaid Data"
        }
    }

    var badgeColor: String {
        switch self {
        case .none:
            return "gray"
        case .demo:
            return "orange"
        case .plaid:
            return "green"
        }
    }
}

// MARK: - Plaid Item Status

struct PlaidItemStatus: Identifiable, Equatable {
    let itemId: String
    let needsReconnect: Bool
    let errorCode: String?
    let lastSyncedAt: Date?
    /// False while Plaid is still backfilling the item's transaction history
    /// (a fresh connection returns recent transactions first; the deep
    /// history arrives asynchronously a few minutes later).
    var historicalComplete: Bool = true

    var id: String { itemId }
}

// MARK: - Plaid Account

struct PlaidAccount: Identifiable, Codable, Equatable {
    let id: String           // account_id from Plaid
    let name: String         // User-friendly name (often the card product name)
    let officialName: String?  // Official institution name
    let type: String         // "credit", "depository", etc.
    let subtype: String?     // "credit card", "checking", etc.
    let mask: String?        // Last 4 digits
    let itemId: String?      // Reference to the Plaid item

    /// Returns true if this is a credit card account
    /// Checks multiple variations to catch all credit card accounts from Plaid
    var isCreditCard: Bool {
        let typeLower = type.lowercased()
        let subtypeLower = (subtype ?? "").lowercased()

        // Check type
        if typeLower == "credit" {
            return true
        }

        // Check subtype variations
        let creditSubtypes = ["credit card", "credit", "creditcard"]
        if creditSubtypes.contains(subtypeLower) {
            return true
        }

        // Check if subtype contains "credit"
        if subtypeLower.contains("credit") {
            return true
        }

        return false
    }
}
