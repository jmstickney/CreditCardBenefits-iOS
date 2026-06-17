//
//  NotificationsView.swift
//  CreditCardBenefits
//
//  Shows upcoming benefit reminders and notification settings
//

import SwiftUI
import UserNotifications

struct NotificationsView: View {
    @EnvironmentObject var dataManager: AppDataManager
    @Environment(\.dismiss) private var dismiss
    @State private var isAuthorized = false
    @State private var pendingCount = 0

    private var expiringBenefits: [BenefitUtilization] {
        dataManager.utilizationService.benefitsExpiringSoon
    }

    private var unusedBenefits: [BenefitUtilization] {
        dataManager.utilizationService.utilizations.filter { $0.amountUtilized == 0 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Ben.Color.cream.ignoresSafeArea()

                List {
                    // Status section
                    Section {
                        HStack {
                            Image(systemName: isAuthorized ? "bell.badge.fill" : "bell.slash")
                                .foregroundColor(isAuthorized ? Ben.Color.mintDark : Ben.Color.warn)
                            Text(isAuthorized ? "Notifications enabled" : "Notifications disabled")
                                .font(Ben.Font.body)
                                .foregroundColor(Ben.Color.textPrimary)
                            Spacer()
                            if !isAuthorized {
                                Button("Enable") {
                                    Task {
                                        isAuthorized = await NotificationManager.shared.requestPermission()
                                    }
                                }
                                .font(Ben.Font.body)
                                .foregroundColor(Ben.Color.forest)
                            }
                        }
                        .listRowBackground(Ben.Color.sand)

                        if pendingCount > 0 {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(Ben.Color.textMuted)
                                Text("\(pendingCount) upcoming reminder\(pendingCount == 1 ? "" : "s")")
                                    .font(Ben.Font.bodySmall)
                                    .foregroundColor(Ben.Color.textMuted)
                            }
                            .listRowBackground(Ben.Color.sand)
                        }
                    }

                    // Expiring benefits
                    if !expiringBenefits.isEmpty {
                        Section(header: Text("Expiring Soon")) {
                            ForEach(expiringBenefits) { utilization in
                                if let card = dataManager.userCards.first(where: { $0.id == utilization.cardId }),
                                   let benefit = card.benefits.first(where: { $0.id == utilization.benefitId }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(benefit.name)
                                                .font(Ben.Font.body)
                                                .foregroundColor(Ben.Color.textPrimary)
                                            Text("\(card.name) — \(utilization.daysUntilExpiry) day\(utilization.daysUntilExpiry == 1 ? "" : "s") left")
                                                .font(Ben.Font.bodySmall)
                                                .foregroundColor(Ben.Color.warn)
                                        }
                                        Spacer()
                                        Text(utilization.amountRemaining.asCurrency())
                                            .font(Ben.Font.body)
                                            .foregroundColor(Ben.Color.warn)
                                    }
                                    .listRowBackground(Ben.Color.sand)
                                }
                            }
                        }
                    }

                    // Unused benefits
                    if !unusedBenefits.isEmpty {
                        Section(header: Text("Unused Benefits (\(unusedBenefits.count))")) {
                            ForEach(unusedBenefits.prefix(10)) { utilization in
                                if let card = dataManager.userCards.first(where: { $0.id == utilization.cardId }),
                                   let benefit = card.benefits.first(where: { $0.id == utilization.benefitId }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(benefit.name)
                                                .font(Ben.Font.body)
                                                .foregroundColor(Ben.Color.textPrimary)
                                            Text(card.name)
                                                .font(Ben.Font.bodySmall)
                                                .foregroundColor(Ben.Color.textMuted)
                                        }
                                        Spacer()
                                        Text(utilization.totalValue.asCurrency())
                                            .font(Ben.Font.body)
                                            .foregroundColor(Ben.Color.textBody)
                                    }
                                    .listRowBackground(Ben.Color.sand)
                                }
                            }
                        }
                    }

                    // Empty state
                    if expiringBenefits.isEmpty && unusedBenefits.isEmpty {
                        Section {
                            VStack(spacing: 12) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 40))
                                    .foregroundColor(Ben.Color.mintDark)
                                Text("You're on top of things!")
                                    .font(Ben.Font.body)
                                    .foregroundColor(Ben.Color.textPrimary)
                                Text("No expiring or unused benefits right now.")
                                    .font(Ben.Font.bodySmall)
                                    .foregroundColor(Ben.Color.textMuted)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .listRowBackground(Ben.Color.sand)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Ben.Color.forest)
                }
            }
            .task {
                isAuthorized = await NotificationManager.shared.isAuthorized()
                let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
                pendingCount = requests.count
            }
        }
    }
}
