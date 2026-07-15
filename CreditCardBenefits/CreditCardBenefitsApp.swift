//
//  CreditCardBenefitsApp.swift
//  CreditCardBenefits
//
//  Created for Credit Card Benefits Tracker POC
//

import SwiftUI
import FirebaseCore
import GoogleSignIn
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        BackgroundRefreshManager.shared.registerBackgroundTask()
        // Present benefit-match / reminder notifications while in the foreground.
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        return true
    }
}

@main
struct CreditCardBenefitsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var dataManager = AppDataManager()

    init() {
        // App Check must be configured BEFORE Firebase is initialized so the
        // attestation provider is in place for the first token request.
        configureAppCheck()

        // Initialize Firebase when app launches
        FirebaseApp.configure()
        benLog("✅ Firebase initialized successfully")
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !dataManager.hasCompletedOnboarding {
                    BenOnboardingView()
                } else {
                    BenTabView()
                }
            }
            .environmentObject(dataManager)
            // Subscription lapse gate: once onboarded, an active subscription is
            // required. Waits for the first entitlement load to avoid flashing
            // the paywall during launch; dismisses itself when a purchase or
            // restore flips isSubscribed.
            .fullScreenCover(isPresented: Binding(
                get: {
                    dataManager.hasCompletedOnboarding
                        && dataManager.subscriptionService.hasLoadedEntitlements
                        && !dataManager.subscriptionService.isSubscribed
                },
                set: { _ in }
            )) {
                ZStack {
                    Ben.Color.cream.ignoresSafeArea()
                    PaywallScreen(onComplete: {})
                        .environmentObject(dataManager)
                }
            }
            .onOpenURL { url in
                // Completes the Google Sign-In OAuth callback.
                _ = GIDSignIn.sharedInstance.handle(url)
            }
            .task {
                // Restore state on app launch
                await dataManager.restoreState()
            }
            .onChange(of: dataManager.authService.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated {
                    // Load this user's data when they sign in.
                    Task {
                        await dataManager.restoreState()
                    }
                } else {
                    // Wipe local data on sign-out — data is tied to the user,
                    // not the device.
                    Task {
                        await dataManager.clearAllData()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                BackgroundRefreshManager.shared.scheduleAppRefresh()
            }
        }
    }
}
