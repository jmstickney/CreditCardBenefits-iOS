//
//  CreditCardsData.swift
//  CreditCardBenefits
//
//  Created for Credit Card Benefits Tracker POC
//

import Foundation

struct CreditCardsData {

    // Database of major credit cards and their subscription-related benefits
    static let allCards: [CreditCard] = [
        CreditCard(
            id: "amex-platinum",
            name: "American Express Platinum",
            issuer: .amex,
            benefits: [
                CreditCardBenefit(
                    id: "amex-plat-streaming",
                    type: .subscriptionCredit,
                    name: "Streaming Credit",
                    description: "Up to $20/month in statement credits for eligible streaming services",
                    amount: 20,
                    frequency: .monthly,
                    eligibleMerchants: [
                        "Disney+", "Disney Plus", "Hulu", "ESPN+", "ESPN Plus",
                        "Peacock", "The New York Times", "NYT", "Audible"
                    ],
                    category: "streaming",
                    conditions: nil
                ),
                CreditCardBenefit(
                    id: "amex-plat-digital",
                    type: .subscriptionCredit,
                    name: "Digital Entertainment Credit",
                    description: "Up to $20/month for digital entertainment subscriptions",
                    amount: 20,
                    frequency: .monthly,
                    eligibleMerchants: [
                        "The Wall Street Journal", "WSJ", "Kindle Unlimited", "Scribd"
                    ],
                    category: "other",
                    conditions: nil
                )
            ]
        ),

        CreditCard(
            id: "chase-sapphire-reserve",
            name: "Chase Sapphire Reserve",
            issuer: .chase,
            benefits: [
                CreditCardBenefit(
                    id: "csr-doordash",
                    type: .subscriptionCredit,
                    name: "DoorDash Benefits",
                    description: "$10/month DoorDash credit with DashPass subscription",
                    amount: 10,
                    frequency: .monthly,
                    eligibleMerchants: ["DoorDash", "Doordash"],
                    category: "food",
                    conditions: "Requires active DashPass subscription"
                ),
                CreditCardBenefit(
                    id: "csr-lyft",
                    type: .subscriptionCredit,
                    name: "Lyft Credit",
                    description: "$10/month in Lyft credits",
                    amount: 10,
                    frequency: .monthly,
                    eligibleMerchants: ["Lyft"],
                    category: "other",
                    conditions: nil
                )
            ]
        ),

        CreditCard(
            id: "capital-one-venture-x",
            name: "Capital One Venture X",
            issuer: .capitalOne,
            benefits: [
                CreditCardBenefit(
                    id: "venture-x-lifestyle",
                    type: .subscriptionCredit,
                    name: "Lifestyle Credit",
                    description: "$10/month credit for select lifestyle subscriptions",
                    amount: 10,
                    frequency: .monthly,
                    eligibleMerchants: [
                        "Walmart+", "Walmart Plus", "Apple Music", "Spotify",
                        "DoorDash", "Instacart"
                    ],
                    category: "other",
                    conditions: nil
                )
            ]
        ),

        CreditCard(
            id: "amex-gold",
            name: "American Express Gold",
            issuer: .amex,
            benefits: [
                CreditCardBenefit(
                    id: "amex-gold-dining",
                    type: .subscriptionCredit,
                    name: "Dining Credit",
                    description: "$10/month dining credit at select merchants",
                    amount: 10,
                    frequency: .monthly,
                    eligibleMerchants: [
                        "Grubhub", "The Cheesecake Factory", "Goldbelly",
                        "Wine.com", "Milk Bar"
                    ],
                    category: "food",
                    conditions: nil
                ),
                CreditCardBenefit(
                    id: "amex-gold-uber",
                    type: .subscriptionCredit,
                    name: "Uber Cash",
                    description: "$10/month in Uber Cash ($35 in December)",
                    amount: 10,
                    frequency: .monthly,
                    eligibleMerchants: ["Uber", "Uber Eats"],
                    category: "food",
                    conditions: nil
                )
            ]
        ),

        CreditCard(
            id: "us-bank-altitude-reserve",
            name: "U.S. Bank Altitude Reserve",
            issuer: .usBank,
            benefits: [
                CreditCardBenefit(
                    id: "usb-altitude-streaming",
                    type: .subscriptionCredit,
                    name: "Streaming Credit",
                    description: "$15/month credit for streaming services",
                    amount: 15,
                    frequency: .monthly,
                    eligibleMerchants: [
                        "Netflix", "Hulu", "Disney+", "Spotify", "Apple Music",
                        "YouTube Premium", "HBO Max", "Amazon Music"
                    ],
                    category: "streaming",
                    conditions: nil
                )
            ]
        ),

        CreditCard(
            id: "citi-prestige",
            name: "Citi Prestige",
            issuer: .citi,
            benefits: [
                CreditCardBenefit(
                    id: "citi-prestige-dining",
                    type: .subscriptionCredit,
                    name: "Dining Credit",
                    description: "$250/year dining credit at select restaurants",
                    amount: 250,
                    frequency: .annual,
                    eligibleMerchants: nil,
                    category: "food",
                    conditions: "At participating restaurants"
                )
            ]
        )
    ]

    // Helper functions
    static func getAllBenefits() -> [(benefit: CreditCardBenefit, cardName: String, cardId: String)] {
        allCards.flatMap { card in
            card.benefits.map { (benefit: $0, cardName: card.name, cardId: card.id) }
        }
    }

    static func getCards(by issuer: CardIssuer) -> [CreditCard] {
        allCards.filter { $0.issuer == issuer }
    }

    static func getCard(by id: String) -> CreditCard? {
        allCards.first { $0.id == id }
    }
}
