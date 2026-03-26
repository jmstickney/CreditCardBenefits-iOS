//
//  PlaidService.swift
//  CreditCardBenefits
//
//  Plaid Link integration service
//

import Foundation
import FirebaseCore
import FirebaseFunctions
import Combine
import LinkKit

class PlaidService: ObservableObject {
    @Published var isLinked = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var transactions: [Transaction] = []
    @Published var accounts: [PlaidAccount] = []
    @Published var dataSource: DataSource = .none

    private let functions = Functions.functions()

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
                print("✅ Restored connection: Found \(parsedAccounts.count) accounts")
                return true
            } else {
                print("ℹ️ No existing Plaid accounts found")
                return false
            }

        } catch {
            await MainActor.run {
                self.isLinked = false
                self.dataSource = .none
                self.isLoading = false
            }
            print("ℹ️ No existing Plaid connection: \(error.localizedDescription)")
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

            print("✅ Link token created: \(linkToken.prefix(20))...")
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
                print("🟢 Creating LinkTokenConfiguration...")
                var linkConfiguration = LinkTokenConfiguration(
                    token: linkToken
                ) { [weak self] success in
                    print("✅ Plaid Link success: \(success.publicToken)")
                    Task {
                        await self?.exchangePublicToken(success.publicToken)
                    }
                }

                linkConfiguration.onExit = { [weak self] exit in
                    print("ℹ️ User exited Plaid Link: \(exit.metadata)")
                    Task { @MainActor in
                        self?.isLoading = false
                    }
                }

                print("🟢 Calling Plaid.create()...")
                let result = Plaid.create(linkConfiguration)
                switch result {
                case .success(let handler):
                    print("🟢 Plaid.create() succeeded, opening handler...")
                    print("🟢 View controller type: \(type(of: viewController))")

                    // Use .custom presentation mode for better compatibility
                    handler.open(presentUsing: .custom { linkViewController in
                        print("🟢 Custom presentation block called")
                        // Ensure presentation happens on main thread
                        DispatchQueue.main.async {
                            print("🟢 Presenting on main thread...")
                            viewController.present(linkViewController, animated: true) {
                                print("🟢 Modal presented successfully")
                            }
                        }
                    })
                    print("🟢 Handler.open() called")
                    self.isLoading = false
                case .failure(let error):
                    self.error = error.localizedDescription
                    self.isLoading = false
                    print("❌ Plaid.create() failed: \(error)")
                }
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
            print("❌ Error creating link token: \(error.localizedDescription)")
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

            print("✅ Public token exchanged successfully")

            // Fetch accounts and transactions after linking
            await fetchAccounts()
            await fetchTransactions()

        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
            print("❌ Error exchanging token: \(error.localizedDescription)")
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

            print("✅ Demo data populated: \(transactionCount) transactions created")

            // Automatically fetch the demo transactions we just created
            await fetchTransactions()

        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
            print("❌ Error populating demo data: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Disconnect

    /// Disconnects the bank account and clears local data
    func disconnect() async {
        await MainActor.run {
            self.isLinked = false
            self.dataSource = .none
            self.transactions = []
            self.accounts = []
        }
        print("✅ Bank disconnected locally")
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

            print("✅ Fetched \(parsedAccounts.count) accounts")

        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
            print("❌ Error fetching accounts: \(error.localizedDescription)")
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

    // MARK: - Fetch Transactions

    /// Fetches transactions from Plaid via Firebase Cloud Function
    func fetchTransactions() async {
        await MainActor.run {
            isLoading = true
        }

        do {
            let calendar = Calendar.current
            let endDate = Date()
            let startDate = calendar.date(byAdding: .year, value: -1, to: endDate) ?? endDate

            let dateFormatter = ISO8601DateFormatter()
            let startDateString = String(dateFormatter.string(from: startDate).split(separator: "T")[0])
            let endDateString = String(dateFormatter.string(from: endDate).split(separator: "T")[0])

            let result = try await functions.httpsCallable("getTransactions").call([
                "startDate": startDateString,
                "endDate": endDateString
            ])

            guard let data = result.data as? [String: Any],
                  let transactionsData = data["transactions"] as? [[String: Any]] else {
                throw PlaidError.invalidResponse
            }

            // Parse transactions
            let parsedTransactions = parseTransactions(transactionsData)

            await MainActor.run {
                self.transactions = parsedTransactions
                self.isLoading = false
            }

            print("✅ Fetched \(parsedTransactions.count) transactions")

        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
            print("❌ Error fetching transactions: \(error.localizedDescription)")
        }
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
                  let amount = dict["amount"] as? Double,
                  let accountId = dict["account_id"] as? String else {
                print("⚠️ Skipping transaction with missing required fields: \(dict)")
                return nil
            }

            guard let date = dateFormatter.date(from: dateString) else {
                print("⚠️ Skipping transaction with invalid date: \(dateString)")
                return nil
            }

            // Plaid returns positive amounts for debits, negative for credits
            let isCredit = amount < 0
            let absAmount = abs(amount)

            // Skip zero-amount transactions
            guard absAmount > 0 else {
                return nil
            }

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
