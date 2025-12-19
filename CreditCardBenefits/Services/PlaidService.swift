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

    private let functions = Functions.functions()

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
    @MainActor
    func presentPlaidLink(from viewController: UIViewController) async {
        isLoading = true

        do {
            let linkToken = try await createLinkToken()

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

            let result = Plaid.create(linkConfiguration)
            switch result {
            case .success(let handler):
                handler.open(presentUsing: .viewController(viewController))
            case .failure(let error):
                self.error = error.localizedDescription
                self.isLoading = false
                print("❌ Plaid Link error: \(error)")
            }
        } catch {
            self.error = error.localizedDescription
            self.isLoading = false
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
                self.isLoading = false
            }

            print("✅ Public token exchanged successfully")

            // Automatically fetch transactions after linking
            await fetchTransactions()

        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
            print("❌ Error exchanging token: \(error.localizedDescription)")
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
            let startDate = calendar.date(byAdding: .day, value: -90, to: endDate) ?? endDate

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
        return data.compactMap { dict -> Transaction? in
            guard let transactionId = dict["transaction_id"] as? String,
                  let dateString = dict["date"] as? String,
                  let merchant = dict["name"] as? String,
                  let amount = dict["amount"] as? Double,
                  let accountId = dict["account_id"] as? String else {
                return nil
            }

            let dateFormatter = ISO8601DateFormatter()
            let date = dateFormatter.date(from: dateString) ?? Date()
            
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
                amount: amount,
                category: category,
                accountId: accountId
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
