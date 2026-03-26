//
//  OnboardingView.swift
//  CreditCardBenefits
//
//  Value-first onboarding for premium cardholders
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var dataManager: AppDataManager
    @State private var currentStep = 0
    @State private var isConnecting = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $currentStep) {
                // Step 1: Welcome & Value Prop
                WelcomeStepView(onNext: { currentStep = 1 })
                    .tag(0)
                
                // Step 2: Connect Cards
                ConnectCardsStepView(
                    isConnecting: $isConnecting,
                    onConnected: { currentStep = 2 }
                )
                    .tag(1)
                
                // Step 3: Value Reveal - "You have $X unused"
                if dataManager.userCards.count > 0 {
                    ValueRevealStepView(onComplete: {
                        dataManager.completeOnboarding()
                    })
                        .tag(2)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .indexViewStyle(.page(backgroundDisplayMode: .never))
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Step 1: Welcome

struct WelcomeStepView: View {
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // App icon/logo placeholder
            Image(systemName: "creditcard.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            VStack(spacing: 16) {
                Text("Stop Leaving Money\non the Table")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Premium cards come with hundreds in hidden benefits. Most cardholders use less than 30%.")
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                Button(action: onNext) {
                    Text("See What You're Missing")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                
                Text("Takes 30 seconds • Bank-level security")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }
}

// MARK: - Step 2: Connect Cards

struct ConnectCardsStepView: View {
    @EnvironmentObject var dataManager: AppDataManager
    @Binding var isConnecting: Bool
    let onConnected: () -> Void
    
    @State private var showingPlaidLink = false
    @State private var linkToken: String?
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "link.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            VStack(spacing: 16) {
                Text("Connect Your Cards")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("We'll securely analyze your transactions to show exactly which benefits you're not using.")
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // Trust signals
            VStack(alignment: .leading, spacing: 12) {
                TrustSignalRow(
                    icon: "lock.shield.fill",
                    text: "Bank-level encryption via Plaid"
                )
                TrustSignalRow(
                    icon: "eye.slash.fill",
                    text: "We never see your login credentials"
                )
                TrustSignalRow(
                    icon: "checkmark.seal.fill",
                    text: "Read-only access • No charges possible"
                )
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            VStack(spacing: 12) {
                if isConnecting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                } else {
                    Button(action: {
                        Task {
                            await connectCards()
                        }
                    }) {
                        Text("Connect Securely with Plaid")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.green)
                            .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .sheet(isPresented: $showingPlaidLink) {
            if let token = linkToken {
                PlaidLinkView(
                    linkToken: token,
                    onSuccess: { publicToken in
                        Task {
                            await handlePlaidSuccess(publicToken: publicToken)
                        }
                        showingPlaidLink = false
                    },
                    onExit: {
                        showingPlaidLink = false
                    }
                )
            }
        }
        .onChange(of: dataManager.userCards.count) { newCount in
            if newCount > 0 {
                // Cards connected, move to next step after brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    onConnected()
                }
            }
        }
    }
    
    private func connectCards() async {
        isConnecting = true
        
        do {
            linkToken = try await dataManager.plaidService.createLinkToken()
            showingPlaidLink = true
        } catch {
            print("Error creating link token: \(error)")
        }
        
        isConnecting = false
    }
    
    private func handlePlaidSuccess(publicToken: String) async {
        await dataManager.handlePlaidSuccess(publicToken: publicToken)
    }
}

struct TrustSignalRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.green)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
        }
    }
}

// MARK: - Step 3: Value Reveal

struct ValueRevealStepView: View {
    @EnvironmentObject var dataManager: AppDataManager
    let onComplete: () -> Void
    
    @State private var showValue = false
    @State private var animatedValue: Double = 0
    
    private var unusedBenefitsValue: Double {
        let utilizations = dataManager.utilizationService.utilizations
        let totalAvailable = dataManager.userCards.reduce(0.0) { $0 + $1.totalBenefitsValue }
        let totalUtilized = utilizations.reduce(0.0) { $0 + $1.amountUtilized }
        return max(0, totalAvailable - totalUtilized)
    }
    
    private var totalBenefitsValue: Double {
        dataManager.userCards.reduce(0.0) { $0 + $1.totalBenefitsValue }
    }
    
    private var utilizationPercentage: Double {
        guard totalBenefitsValue > 0 else { return 0 }
        let totalUtilized = dataManager.utilizationService.utilizations.reduce(0.0) { $0 + $1.amountUtilized }
        return (totalUtilized / totalBenefitsValue) * 100
    }
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 24) {
                // Reveal animation
                if showValue {
                    VStack(spacing: 8) {
                        Text("You Have")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text(animatedValue.asCurrency())
                            .font(.system(size: 64, weight: .bold))
                            .foregroundColor(.orange)
                            .contentTransition(.numericText())
                        
                        Text("in Unused Benefits")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .transition(.scale.combined(with: .opacity))
                    
                    // Breakdown
                    VStack(spacing: 16) {
                        Text("Based on your \(dataManager.userCards.count) premium card\(dataManager.userCards.count > 1 ? "s" : "")")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.6))
                        
                        VStack(spacing: 12) {
                            HStack {
                                Text("Total Available")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.6))
                                Spacer()
                                Text(totalBenefitsValue.asCurrency())
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            
                            HStack {
                                Text("You're Using")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.6))
                                Spacer()
                                Text("\(Int(utilizationPercentage))%")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.green)
                            }
                            
                            HStack {
                                Text("Left on Table")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.6))
                                Spacer()
                                Text(unusedBenefitsValue.asCurrency())
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            if showValue {
                VStack(spacing: 12) {
                    Button(action: onComplete) {
                        Text("Start Maximizing")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    
                    if unusedBenefitsValue > 100 {
                        Text("That's \(unusedBenefitsValue.asCurrency()) you can reclaim this year")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            // Delay then animate value reveal
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    showValue = true
                }
                
                // Animate counter
                let duration: Double = 1.5
                let steps: Int = 60
                let stepValue = unusedBenefitsValue / Double(steps)
                
                for i in 0...steps {
                    DispatchQueue.main.asyncAfter(deadline: .now() + (duration / Double(steps)) * Double(i)) {
                        withAnimation {
                            animatedValue = stepValue * Double(i)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppDataManager())
}
