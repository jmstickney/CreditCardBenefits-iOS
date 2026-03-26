//
//  SwipeableCardDetailView.swift
//  CreditCardBenefits
//
//  Enables Amex-style swipeable navigation between cards
//

import SwiftUI

struct SwipeableCardDetailView: View {
    @EnvironmentObject var dataManager: AppDataManager
    @Environment(\.presentationMode) var presentationMode
    let initialCard: CreditCard
    let allCards: [CreditCard]
    
    @State private var selectedCardIndex: Int = 0
    @State private var showingCompactList = false
    @GestureState private var dragOffset: CGFloat = 0
    
    init(initialCard: CreditCard, allCards: [CreditCard]) {
        self.initialCard = initialCard
        self.allCards = allCards
        
        // Find initial card index
        if let index = allCards.firstIndex(where: { $0.id == initialCard.id }) {
            _selectedCardIndex = State(initialValue: index)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Main swipeable content with card peek effect
                TabView(selection: $selectedCardIndex) {
                    ForEach(Array(allCards.enumerated()), id: \.element.id) { index, card in
                        CardDetailView(card: card, allCards: allCards, showBackButton: false)
                            .tag(index)
                            .padding(.horizontal, 10) // Creates the peek effect
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()
                
                // Compact list button (top left, tucked in corner)
                VStack {
                    HStack {
                        Button(action: {
                            showingCompactList = true
                        }) {
                            Image(systemName: "square.grid.2x2")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.black.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .padding(.leading, 16)
                        .padding(.top, 54) // Just below status bar
                        
                        Spacer()
                    }
                    
                    Spacer()
                }
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .gesture(
            // Swipe from left edge to go back
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    if value.startLocation.x < 20 && value.translation.width > 0 {
                        state = value.translation.width
                    }
                }
                .onEnded { value in
                    if value.startLocation.x < 20 && value.translation.width > 100 {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
        )
        .sheet(isPresented: $showingCompactList) {
            CompactCardListView(
                allCards: allCards,
                selectedCardIndex: $selectedCardIndex,
                isPresented: $showingCompactList
            )
        }
    }
}

// MARK: - Compact Card List Overlay

struct CompactCardListView: View {
    let allCards: [CreditCard]
    @Binding var selectedCardIndex: Int
    @Binding var isPresented: Bool
    @EnvironmentObject var dataManager: AppDataManager
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Wednesday, March 18")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        
                        Text("Overview")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                            .padding(.vertical, 16)
                        
                        Text("Cards")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                        
                        // Card list
                        ForEach(Array(allCards.enumerated()), id: \.element.id) { index, card in
                            Button(action: {
                                selectedCardIndex = index
                                isPresented = false
                            }) {
                                CompactCardRow(card: card)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        Spacer(minLength: 60)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Log out") {
                        // Handle logout
                    }
                    .foregroundColor(.blue)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Compact Card Row

struct CompactCardRow: View {
    let card: CreditCard
    @EnvironmentObject var dataManager: AppDataManager
    
    private var totalUtilized: Double {
        let utilizations = dataManager.utilizationService.utilizationsForCard(card.id)
        return utilizations.reduce(0.0) { $0 + $1.amountUtilized }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Card thumbnail
            cardThumbnail
            
            VStack(alignment: .leading, spacing: 6) {
                Text(totalUtilized.asCurrency())
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(card.name)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(16)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }
    
    private var cardThumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(
                    colors: Color.cardGradient(for: card.issuer),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            
            Text(card.issuer.rawValue.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(width: 80, height: 50)
    }
}

#Preview {
    let cards = CreditCardsData.allCards.prefix(3)
    return SwipeableCardDetailView(
        initialCard: cards.first!,
        allCards: Array(cards)
    )
    .environmentObject(AppDataManager())
}
