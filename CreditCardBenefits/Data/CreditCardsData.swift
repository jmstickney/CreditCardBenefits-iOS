//
//  CreditCardsData.swift
//  CreditCardBenefits
//
//  Comprehensive database of credit cards and their benefits
//

import Foundation

struct CreditCardsData {

    // MARK: - All Cards Database

    static let allCards: [CreditCard] = [

        // MARK: - American Express Platinum

        CreditCard(
            id: "amex-platinum",
            name: "American Express Platinum",
            issuer: .amex,
            benefits: [
                // Monthly Credits
                CreditCardBenefit(
                    id: "amex-plat-uber",
                    type: .rideshareCredit,
                    name: "Uber Cash",
                    description: "$15/month in Uber Cash ($20 in December)",
                    amount: 15,
                    frequency: .monthly,
                    eligibleMerchants: [
                        "AMEX UBER CASH", "UBER CASH CREDIT",
                        "Uber", "Uber Eats", "UBER"
                    ],
                    category: "rideshare",
                    conditions: "Must add Platinum Card to Uber account. $15/month, $20 in December",
                    period: .monthly,
                    monthlyAmounts: [12: 20],  // December gets $20
                    canAutoDetect: false,  // Credits added to Uber app
                    requiresEnrollment: true,
                    enrollmentUrl: "https://www.uber.com/amex"
                ),
                CreditCardBenefit(
                    id: "amex-plat-streaming",
                    type: .subscriptionCredit,
                    name: "Digital Entertainment Credit",
                    description: "$25/month for streaming ($300/year)",
                    amount: 25,
                    frequency: .monthly,
                    eligibleMerchants: [
                        "AMEX ENTERTAINMENT CREDIT", "ENTERTAINMENT CREDIT",
                        "PLATINUM DIGITAL ENTERTAINMENT", "DIGITAL ENTERTAINMENT CREDIT",
                        "Disney+", "Disney Plus", "Disney Bundle", "DisneyPlus", 
                        "Hulu", "ESPN+", "ESPN Plus",
                        "Peacock", "The New York Times", "NYT", "Audible",
                        "DISNEY", "DISNEYPLUS"
                    ],
                    category: "streaming",
                    conditions: "Must enroll in Amex Offers",
                    period: .monthly,
                    canAutoDetect: true,
                    requiresEnrollment: true,
                    enrollmentUrl: "https://www.americanexpress.com/us/credit-cards/features-benefits/policies/streaming-credit.html",
                    matchCreditTransactions: true
                ),
                CreditCardBenefit(
                    id: "amex-plat-walmart",
                    type: .shoppingCredit,
                    name: "Walmart+ Credit",
                    description: "$12.95/month Walmart+ membership ($155.40/year)",
                    amount: 12.95,
                    frequency: .monthly,
                    eligibleMerchants: [
                        "WALMART+ CREDIT", "AMEX WALMART",
                        "Walmart+", "Walmart Plus", "WALMART"
                    ],
                    category: "shopping",
                    conditions: "Statement credit for Walmart+ monthly fee",
                    period: .monthly,
                    canAutoDetect: true,
                    requiresEnrollment: true,
                    enrollmentUrl: "https://www.walmart.com/plus",
                    matchCreditTransactions: true
                ),
                
                // Quarterly Credits
                CreditCardBenefit(
                    id: "amex-plat-resy",
                    type: .diningCredit,
                    name: "Resy Credit",
                    description: "$100/quarter for Resy restaurants ($400/year)",
                    amount: 100,
                    frequency: .annual,
                    eligibleMerchants: [
                        "RESY CREDIT", "AMEX RESY",
                        "Resy", "RESY"
                    ],
                    category: "dining",
                    conditions: "$100 per quarter available",
                    period: .calendarYear,
                    canAutoDetect: false,  // Must book through Resy
                    requiresEnrollment: false
                ),
                CreditCardBenefit(
                    id: "amex-plat-lululemon",
                    type: .shoppingCredit,
                    name: "Lululemon Credit",
                    description: "$75/quarter for Lululemon ($300/year)",
                    amount: 75,
                    frequency: .annual,
                    eligibleMerchants: [
                        "LULULEMON CREDIT", "AMEX LULULEMON",
                        "Lululemon", "LULULEMON"
                    ],
                    category: "shopping",
                    conditions: "$75 per quarter available",
                    period: .calendarYear,
                    canAutoDetect: true,
                    requiresEnrollment: false,
                    matchCreditTransactions: true
                ),
                
                // Semi-Annual Credits
                CreditCardBenefit(
                    id: "amex-plat-hotel",
                    type: .hotelCredit,
                    name: "Hotel Credit",
                    description: "$300 semi-annually for hotels ($600/year)",
                    amount: 300,
                    frequency: .annual,
                    eligibleMerchants: nil,
                    category: "travel",
                    conditions: "Book through Amex Travel for FHR or The Hotel Collection. $300 per 6 months.",
                    period: .calendarYear,
                    canAutoDetect: false,  // Must book through Amex portal
                    requiresEnrollment: false
                ),
                CreditCardBenefit(
                    id: "amex-plat-saks",
                    type: .shoppingCredit,
                    name: "Saks Fifth Avenue Credit",
                    description: "$50 semi-annually ($100/year)",
                    amount: 50,
                    frequency: .annual,
                    eligibleMerchants: [
                        "SAKS FIFTH AVENUE CREDIT", "AMEX SAKS",
                        "Saks Fifth Avenue", "Saks OFF 5TH", "SAKS"
                    ],
                    category: "shopping",
                    conditions: "$50 Jan-Jun, $50 Jul-Dec",
                    period: .calendarYear,
                    canAutoDetect: true,
                    requiresEnrollment: true,
                    enrollmentUrl: "https://www.americanexpress.com/en-us/benefits/saks-fifth-avenue/",
                    matchCreditTransactions: true
                ),

                // Annual Credits
                CreditCardBenefit(
                    id: "amex-plat-airline",
                    type: .airlineIncidental,
                    name: "Airline Fee Credit",
                    description: "$200/year for incidental airline fees",
                    amount: 200,
                    frequency: .annual,
                    eligibleMerchants: nil,
                    category: "travel",
                    conditions: "Must select one airline. Covers bags, seat selection, in-flight purchases.",
                    period: .cardmemberYear,
                    canAutoDetect: false,  // Applied as statement credit
                    requiresEnrollment: true,
                    enrollmentUrl: "https://global.americanexpress.com/card-benefits/detail/airline-fee-credit"
                ),
                CreditCardBenefit(
                    id: "amex-plat-clear",
                    type: .enrollmentBenefit,
                    name: "CLEAR Credit",
                    description: "$209/year for CLEAR Plus membership",
                    amount: 209,
                    frequency: .annual,
                    eligibleMerchants: ["CLEAR", "Clear"],
                    category: "travel",
                    conditions: "CLEAR Plus annual membership",
                    period: .cardmemberYear,
                    canAutoDetect: true,
                    requiresEnrollment: false,
                    matchCreditTransactions: true
                ),
                CreditCardBenefit(
                    id: "amex-plat-oura",
                    type: .subscriptionCredit,
                    name: "Oura Ring Credit",
                    description: "$200/year for Oura Ring membership",
                    amount: 200,
                    frequency: .annual,
                    eligibleMerchants: [
                        "OURA CREDIT", "AMEX OURA",
                        "Oura", "OURA"
                    ],
                    category: "health",
                    conditions: "Annual Oura Ring membership credit",
                    period: .calendarYear,
                    canAutoDetect: true,
                    requiresEnrollment: false,
                    matchCreditTransactions: true
                ),
                CreditCardBenefit(
                    id: "amex-plat-equinox",
                    type: .subscriptionCredit,
                    name: "Equinox Plus",
                    description: "$300/year for Equinox membership",
                    amount: 300,
                    frequency: .annual,
                    eligibleMerchants: [
                        "EQUINOX CREDIT", "AMEX EQUINOX",
                        "Equinox", "EQUINOX"
                    ],
                    category: "fitness",
                    conditions: "Annual Equinox membership credit",
                    period: .calendarYear,
                    canAutoDetect: true,
                    requiresEnrollment: true,
                    enrollmentUrl: "https://www.equinoxplus.com",
                    matchCreditTransactions: true
                ),
                CreditCardBenefit(
                    id: "amex-plat-uber-one",
                    type: .subscriptionCredit,
                    name: "Uber One",
                    description: "$120/year for Uber One membership",
                    amount: 120,
                    frequency: .annual,
                    eligibleMerchants: [
                        "UBER ONE", "AMEX UBER ONE",
                        "Uber One", "UBERONE"
                    ],
                    category: "rideshare",
                    conditions: "Annual Uber One membership",
                    period: .calendarYear,
                    canAutoDetect: false,  // Credits added to Uber app
                    requiresEnrollment: false
                )
            ],
            annualFee: 695
        ),

        // MARK: - Chase Sapphire Reserve

        CreditCard(
            id: "chase-sapphire-reserve",
            name: "Chase Sapphire Reserve",
            issuer: .chase,
            benefits: [
                // Annual Travel Credit
                CreditCardBenefit(
                    id: "csr-travel",
                    type: .travelCredit,
                    name: "Travel Credit",
                    description: "$300 annual travel credit",
                    amount: 300,
                    frequency: .annual,
                    eligibleMerchants: [
                        "TRAVEL CREDIT $300/YEAR", "TRAVEL CREDIT $300/YR",
                        "TRAVEL CREDIT", "CHASE TRAVEL CREDIT",
                        "CSR TRAVEL CREDIT", "SAPPHIRE TRAVEL CREDIT",
                        "TRAVEL CREDIT $300", "$300 TRAVEL CREDIT"
                    ],
                    category: "travel",
                    conditions: "Automatically applied to travel purchases",
                    period: .cardmemberYear,
                    eligibleCategories: ["Airlines", "Hotels", "Car Rental", "Travel"],
                    canAutoDetect: true,
                    requiresEnrollment: false,
                    matchCreditTransactions: true
                ),
                
                // Semi-Annual Credits
                CreditCardBenefit(
                    id: "csr-the-edit",
                    type: .hotelCredit,
                    name: "The Edit Hotels",
                    description: "$250 per stay, up to 2 prepaid stays per year ($500/year)",
                    amount: 250,
                    frequency: .annual,
                    eligibleMerchants: nil,
                    category: "travel",
                    conditions: "Up to $250 for 2 prepaid stays per year through Chase Travel",
                    period: .calendarYear,
                    canAutoDetect: false,
                    requiresEnrollment: false
                ),
                CreditCardBenefit(
                    id: "csr-chase-travel-hotel",
                    type: .hotelCredit,
                    name: "Chase Travel Hotel Credit",
                    description: "$250/year for select hotels through Chase Travel",
                    amount: 250,
                    frequency: .annual,
                    eligibleMerchants: nil,
                    category: "travel",
                    conditions: "Book select hotels through Chase Travel",
                    period: .calendarYear,
                    canAutoDetect: false,
                    requiresEnrollment: false
                ),
                CreditCardBenefit(
                    id: "csr-opentable",
                    type: .diningCredit,
                    name: "OpenTable Credit",
                    description: "$150 every 6 months ($300/year)",
                    amount: 150,
                    frequency: .annual,
                    eligibleMerchants: [
                        "OPENTABLE", "OpenTable", "OPEN TABLE"
                    ],
                    category: "dining",
                    conditions: "$150 every 6 months through OpenTable",
                    period: .calendarYear,
                    canAutoDetect: false,
                    requiresEnrollment: false
                ),
                CreditCardBenefit(
                    id: "csr-stubhub",
                    type: .subscriptionCredit,
                    name: "StubHub Credit",
                    description: "$150 every 6 months ($300/year)",
                    amount: 150,
                    frequency: .annual,
                    eligibleMerchants: [
                        "STUBHUB", "StubHub", "STUB HUB"
                    ],
                    category: "entertainment",
                    conditions: "$150 every 6 months on StubHub",
                    period: .calendarYear,
                    canAutoDetect: false,
                    requiresEnrollment: false
                ),
                
                // Monthly Credits
                CreditCardBenefit(
                    id: "csr-peloton",
                    type: .subscriptionCredit,
                    name: "Peloton Credit",
                    description: "$10/month Peloton Digital ($120/year)",
                    amount: 10,
                    frequency: .monthly,
                    eligibleMerchants: [
                        "Peloton", "PELOTON",
                        "CHASE PELOTON CREDIT", "PELOTON CREDIT"
                    ],
                    category: "fitness",
                    conditions: "$10/month for Peloton membership",
                    period: .monthly,
                    canAutoDetect: false,
                    requiresEnrollment: true,
                    enrollmentUrl: "https://www.onepeloton.com/chase"
                ),
                CreditCardBenefit(
                    id: "csr-doordash",
                    type: .diningCredit,
                    name: "DoorDash Credit",
                    description: "$5/month DoorDash ($60/year, possibly $240 with grocery)",
                    amount: 5,
                    frequency: .monthly,
                    eligibleMerchants: ["DoorDash", "Doordash", "DOORDASH"],
                    category: "food",
                    conditions: "$5/month (maybe $20 more for grocery)",
                    period: .monthly,
                    canAutoDetect: false,
                    requiresEnrollment: true,
                    enrollmentUrl: "https://www.doordash.com/dashpass"
                ),
                CreditCardBenefit(
                    id: "csr-apple-music",
                    type: .subscriptionCredit,
                    name: "Apple Music",
                    description: "$11/month via Apple ($132/year)",
                    amount: 11,
                    frequency: .monthly,
                    eligibleMerchants: [
                        "Apple Music", "APPLE MUSIC", "APPLE.COM/BILL"
                    ],
                    category: "streaming",
                    conditions: "$11/month through Apple",
                    period: .monthly,
                    canAutoDetect: false,
                    requiresEnrollment: false
                ),
                CreditCardBenefit(
                    id: "csr-apple-tv",
                    type: .subscriptionCredit,
                    name: "Apple TV+",
                    description: "$12.99/month via Apple ($156/year)",
                    amount: 12.99,
                    frequency: .monthly,
                    eligibleMerchants: [
                        "Apple TV", "APPLE TV+", "APPLE.COM/BILL"
                    ],
                    category: "streaming",
                    conditions: "$12.99/month through Apple",
                    period: .monthly,
                    canAutoDetect: false,
                    requiresEnrollment: false
                ),
                CreditCardBenefit(
                    id: "csr-dashpass",
                    type: .subscriptionCredit,
                    name: "DashPass",
                    description: "$10/month activated through DoorDash ($120/year)",
                    amount: 10,
                    frequency: .monthly,
                    eligibleMerchants: [
                        "DashPass", "DASHPASS", "DoorDash"
                    ],
                    category: "food",
                    conditions: "$10/month DashPass membership",
                    period: .monthly,
                    canAutoDetect: false,
                    requiresEnrollment: true
                ),
                CreditCardBenefit(
                    id: "csr-lyft",
                    type: .rideshareCredit,
                    name: "Lyft Credit",
                    description: "$10/month through Lyft app ($120/year)",
                    amount: 10,
                    frequency: .monthly,
                    eligibleMerchants: ["Lyft", "LYFT"],
                    category: "rideshare",
                    conditions: "$10/month through Lyft app",
                    period: .monthly,
                    canAutoDetect: false,
                    requiresEnrollment: true,
                    enrollmentUrl: "https://www.lyft.com/chase"
                ),
                
                // Every 4 Years
                CreditCardBenefit(
                    id: "csr-tsa-ge",
                    type: .enrollmentBenefit,
                    name: "TSA PreCheck or Global Entry",
                    description: "Up to $120 every 4 years",
                    amount: 120,
                    frequency: .annual,
                    eligibleMerchants: [
                        "Global Entry", "TSA PreCheck", "TSA", "GOES"
                    ],
                    category: "travel",
                    conditions: "Up to $120 every 4 years",
                    period: .oneTime,
                    canAutoDetect: false,
                    requiresEnrollment: false
                )
            ],
            annualFee: 550
        ),

        // MARK: - Capital One Venture X

        CreditCard(
            id: "capital-one-venture-x",
            name: "Capital One Venture X",
            issuer: .capitalOne,
            benefits: [
                CreditCardBenefit(
                    id: "venture-x-travel",
                    type: .travelCredit,
                    name: "Annual Travel Credit",
                    description: "$300 annual travel credit through Capital One Travel",
                    amount: 300,
                    frequency: .annual,
                    eligibleMerchants: nil,
                    category: "travel",
                    conditions: "Must book through Capital One Travel portal",
                    period: .cardmemberYear,
                    eligibleCategories: ["Travel"],
                    canAutoDetect: false,  // Must use Capital One portal
                    requiresEnrollment: false
                ),
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
                    category: "lifestyle",
                    conditions: nil,
                    period: .monthly,
                    canAutoDetect: true,
                    requiresEnrollment: false
                ),
                CreditCardBenefit(
                    id: "venture-x-global-entry",
                    type: .enrollmentBenefit,
                    name: "Global Entry/TSA PreCheck Credit",
                    description: "$100 credit every 4 years",
                    amount: 100,
                    frequency: .annual,
                    eligibleMerchants: ["Global Entry", "TSA PreCheck", "TSA"],
                    category: "travel",
                    conditions: nil,
                    period: .oneTime,
                    canAutoDetect: false,
                    requiresEnrollment: false
                )
            ],
            annualFee: 395
        ),

        // MARK: - American Express Gold

        CreditCard(
            id: "amex-gold",
            name: "American Express Gold",
            issuer: .amex,
            benefits: [
                CreditCardBenefit(
                    id: "amex-gold-dining",
                    type: .diningCredit,
                    name: "Dining Credit",
                    description: "$10/month dining credit at select merchants",
                    amount: 10,
                    frequency: .monthly,
                    eligibleMerchants: [
                        // Credit transaction names
                        "AMEX DINING CREDIT", "GOLD DINING CREDIT",
                        // Purchase names
                        "Grubhub", "The Cheesecake Factory", "Goldbelly",
                        "Wine.com", "Milk Bar", "GRUBHUB"
                    ],
                    category: "food",
                    conditions: "Select one merchant to earn credit",
                    period: .monthly,
                    canAutoDetect: true,
                    requiresEnrollment: true,
                    enrollmentUrl: "https://www.americanexpress.com/en-us/benefits/gold-card/",
                    matchCreditTransactions: true
                ),
                CreditCardBenefit(
                    id: "amex-gold-uber",
                    type: .rideshareCredit,
                    name: "Uber Cash",
                    description: "$10/month in Uber Cash ($35 in December)",
                    amount: 10,
                    frequency: .monthly,
                    eligibleMerchants: [
                        // Credit transaction names
                        "AMEX UBER CASH", "UBER CASH CREDIT",
                        // Purchase names
                        "Uber", "Uber Eats", "UBER"
                    ],
                    category: "food",
                    conditions: "Must add Gold Card to Uber account",
                    period: .monthly,
                    monthlyAmounts: [12: 35],  // December gets $35
                    canAutoDetect: true,
                    requiresEnrollment: true,
                    enrollmentUrl: "https://www.uber.com/amex",
                    matchCreditTransactions: true
                ),
                CreditCardBenefit(
                    id: "amex-gold-dunkin",
                    type: .diningCredit,
                    name: "Dunkin' Credit",
                    description: "$7/month at Dunkin'",
                    amount: 7,
                    frequency: .monthly,
                    eligibleMerchants: ["Dunkin", "Dunkin'", "DUNKIN"],
                    category: "food",
                    conditions: nil,
                    period: .monthly,
                    canAutoDetect: true,
                    requiresEnrollment: true,
                    enrollmentUrl: "https://www.americanexpress.com/en-us/benefits/gold-card/"
                )
            ],
            annualFee: 250
        ),

        // MARK: - U.S. Bank Altitude Reserve

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
                        "YouTube Premium", "HBO Max", "Amazon Music", "Max"
                    ],
                    category: "streaming",
                    conditions: nil,
                    period: .monthly,
                    canAutoDetect: true,
                    requiresEnrollment: false
                ),
                CreditCardBenefit(
                    id: "usb-altitude-travel",
                    type: .travelCredit,
                    name: "Annual Travel Credit",
                    description: "$325 annual airline credit",
                    amount: 325,
                    frequency: .annual,
                    eligibleMerchants: nil,
                    category: "travel",
                    conditions: "Automatically applied to airline purchases",
                    period: .cardmemberYear,
                    eligibleCategories: ["Airlines"],
                    canAutoDetect: true,
                    requiresEnrollment: false
                ),
                CreditCardBenefit(
                    id: "usb-altitude-global-entry",
                    type: .enrollmentBenefit,
                    name: "Global Entry/TSA PreCheck Credit",
                    description: "$100 credit every 4 years",
                    amount: 100,
                    frequency: .annual,
                    eligibleMerchants: ["Global Entry", "TSA PreCheck", "TSA"],
                    category: "travel",
                    conditions: nil,
                    period: .oneTime,
                    canAutoDetect: false,
                    requiresEnrollment: false
                )
            ],
            annualFee: 400
        ),

        // MARK: - American Express Blue Cash Preferred

        CreditCard(
            id: "amex-blue-cash-preferred",
            name: "American Express Blue Cash Preferred",
            issuer: .amex,
            benefits: [
                CreditCardBenefit(
                    id: "amex-bcp-disney",
                    type: .subscriptionCredit,
                    name: "Disney Bundle Credit",
                    description: "$10/month for Disney streaming ($120/year)",
                    amount: 10,
                    frequency: .monthly,
                    eligibleMerchants: [
                        // Credit transaction names from Amex
                        "AMEX STREAMING CREDIT", "BCP STREAMING CREDIT", "AMEX DISNEY CREDIT",
                        // Disney services
                        "Disney+", "Disney Plus", "DISNEYPLUS",
                        "Disney Bundle", "DISNEY BUNDLE",
                        "Hulu", "HULU",
                        "ESPN+", "ESPN Plus", "ESPNPLUS", "ESPN"
                    ],
                    category: "streaming",
                    conditions: "Up to $10/month for eligible Disney streaming services",
                    period: .monthly,
                    canAutoDetect: true,
                    requiresEnrollment: true,
                    enrollmentUrl: "https://www.americanexpress.com/en-us/credit-cards/credit-intel/streaming-credit/",
                    matchCreditTransactions: true
                )
            ],
            annualFee: 95
        ),

        // MARK: - Citi Prestige

        CreditCard(
            id: "citi-prestige",
            name: "Citi Prestige",
            issuer: .citi,
            benefits: [
                CreditCardBenefit(
                    id: "citi-prestige-travel",
                    type: .travelCredit,
                    name: "Travel Credit",
                    description: "$250 annual travel credit",
                    amount: 250,
                    frequency: .annual,
                    eligibleMerchants: nil,
                    category: "travel",
                    conditions: "Automatically applied to airline, hotel, and travel agency purchases",
                    period: .cardmemberYear,
                    eligibleCategories: ["Airlines", "Hotels", "Travel"],
                    canAutoDetect: true,
                    requiresEnrollment: false
                ),
                CreditCardBenefit(
                    id: "citi-prestige-global-entry",
                    type: .enrollmentBenefit,
                    name: "Global Entry/TSA PreCheck Credit",
                    description: "$100 credit every 5 years",
                    amount: 100,
                    frequency: .annual,
                    eligibleMerchants: ["Global Entry", "TSA PreCheck", "TSA"],
                    category: "travel",
                    conditions: nil,
                    period: .oneTime,
                    canAutoDetect: false,
                    requiresEnrollment: false
                )
            ],
            annualFee: 495
        )
    ]

    // MARK: - Helper Functions

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

    static func getBenefit(by id: String) -> CreditCardBenefit? {
        for card in allCards {
            if let benefit = card.benefits.first(where: { $0.id == id }) {
                return benefit
            }
        }
        return nil
    }

    static func getCardForBenefit(benefitId: String) -> CreditCard? {
        for card in allCards {
            if card.benefits.contains(where: { $0.id == benefitId }) {
                return card
            }
        }
        return nil
    }

    /// Returns benefits that are expiring within the given number of days
    static func getBenefitsExpiringSoon(within days: Int = 30) -> [(benefit: CreditCardBenefit, card: CreditCard)] {
        var expiring: [(CreditCardBenefit, CreditCard)] = []

        for card in allCards {
            for benefit in card.benefits where benefit.period == .monthly {
                // Monthly benefits always have something expiring soon
                expiring.append((benefit, card))
            }
        }

        return expiring
    }
}
