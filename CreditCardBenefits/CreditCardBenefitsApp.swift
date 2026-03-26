//
//  CreditCardBenefitsApp.swift
//  CreditCardBenefits
//
//  Created for Credit Card Benefits Tracker POC
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        BackgroundRefreshManager.shared.registerBackgroundTask()
        return true
    }
}

@main
struct CreditCardBenefitsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var dataManager = AppDataManager()

    init() {
        // Initialize Firebase when app launches
        FirebaseApp.configure()
        print("✅ Firebase initialized successfully")
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !dataManager.hasCompletedOnboarding {
                    BenOnboardingView()
                } else {
                    TabView {
                        HomeView()
                            .tabItem {
                                Label("Home", systemImage: "house.fill")
                            }

                        SettingsView()
                            .tabItem {
                                Label("Settings", systemImage: "gear")
                            }
                    }
                }
            }
            .environmentObject(dataManager)
            .task {
                // Restore state on app launch
                await dataManager.restoreState()
            }
            .onChange(of: dataManager.authService.isAuthenticated) { _, isAuthenticated in
                // Restore state when user logs in
                if isAuthenticated {
                    Task {
                        await dataManager.restoreState()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                BackgroundRefreshManager.shared.scheduleAppRefresh()
            }
        }
    }
}
