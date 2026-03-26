//
//  CardMappingService.swift
//  CreditCardBenefits
//
//  Persists user card selections in Firestore
//

import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

// MARK: - Card Mapping Model

struct CardMapping: Codable, Identifiable {
    var id: String { plaidAccountId }
    let plaidAccountId: String
    let creditCardId: String?       // nil = user chose "Other/Unknown"
    let plaidAccountName: String
    let plaidAccountMask: String?
    let isAutoDetected: Bool
    let createdAt: Date
    let updatedAt: Date
}

// MARK: - Card Mapping Service

class CardMappingService: ObservableObject {
    @Published var mappings: [String: CardMapping] = [:]  // keyed by plaidAccountId
    @Published var isLoading = false

    private let db = Firestore.firestore()

    // MARK: - Load Mappings

    /// Loads all card mappings for the current user
    func loadMappings(for userId: String) async {
        await MainActor.run {
            isLoading = true
        }

        do {
            let snapshot = try await db
                .collection("users")
                .document(userId)
                .collection("cardMappings")
                .getDocuments()

            var loadedMappings: [String: CardMapping] = [:]

            for doc in snapshot.documents {
                if let mapping = try? doc.data(as: CardMapping.self) {
                    loadedMappings[mapping.plaidAccountId] = mapping
                }
            }

            await MainActor.run {
                self.mappings = loadedMappings
                self.isLoading = false
            }

            print("✅ Loaded \(loadedMappings.count) card mappings")

        } catch {
            await MainActor.run {
                self.isLoading = false
            }
            print("❌ Error loading card mappings: \(error.localizedDescription)")
        }
    }

    // MARK: - Save Mapping

    /// Saves a card mapping for a Plaid account
    func saveMapping(_ mapping: CardMapping, userId: String) async throws {
        try await db
            .collection("users")
            .document(userId)
            .collection("cardMappings")
            .document(mapping.plaidAccountId)
            .setData(try Firestore.Encoder().encode(mapping))

        await MainActor.run {
            self.mappings[mapping.plaidAccountId] = mapping
        }

        print("✅ Saved mapping for account \(mapping.plaidAccountId)")
    }

    /// Creates and saves a mapping from a CardMatch
    func saveMappingFromMatch(_ match: CardMatch, userId: String, isAutoDetected: Bool) async throws {
        let now = Date()
        let mapping = CardMapping(
            plaidAccountId: match.plaidAccount.id,
            creditCardId: match.creditCard?.id,
            plaidAccountName: match.plaidAccount.name,
            plaidAccountMask: match.plaidAccount.mask,
            isAutoDetected: isAutoDetected,
            createdAt: now,
            updatedAt: now
        )

        try await saveMapping(mapping, userId: userId)
    }

    // MARK: - Get Card for Account

    /// Gets the CreditCard associated with a Plaid account ID
    func getCardForAccount(_ accountId: String) -> CreditCard? {
        guard let mapping = mappings[accountId],
              let cardId = mapping.creditCardId else {
            return nil
        }
        return CreditCardsData.getCard(by: cardId)
    }

    /// Gets all unique CreditCards from the mappings
    func getAllMappedCards() -> [CreditCard] {
        var uniqueCards: [String: CreditCard] = [:]

        for mapping in mappings.values {
            if let cardId = mapping.creditCardId,
               let card = CreditCardsData.getCard(by: cardId) {
                uniqueCards[cardId] = card
            }
        }

        return Array(uniqueCards.values)
    }

    // MARK: - Delete Mapping

    /// Deletes a card mapping
    func deleteMapping(accountId: String, userId: String) async throws {
        try await db
            .collection("users")
            .document(userId)
            .collection("cardMappings")
            .document(accountId)
            .delete()

        await MainActor.run {
            self.mappings.removeValue(forKey: accountId)
        }

        print("✅ Deleted mapping for account \(accountId)")
    }

    /// Clears all mappings (used when disconnecting)
    func clearAllMappings() {
        mappings.removeAll()
    }
}
