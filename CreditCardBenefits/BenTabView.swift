import SwiftUI

// MARK: - BenTabView
// Root tab container. Replace whatever currently wraps your views at the
// app entry point (CreditCardBenefitsApp.swift) with this.
// Requires BenTheme.swift in the project.

struct BenTabView: View {

    @State private var selectedTab: BenTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            // ── Home ──────────────────────────────────────────────
            NavigationStack {
                HomeView()
                    .toolbar { homeToolbar }
                    .toolbarBackground(Ben.Color.cream, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
            }
            .tabItem {
                Label("Home", systemImage: selectedTab == .home
                      ? "house.fill" : "house")
            }
            .tag(BenTab.home)

            // ── Cards ─────────────────────────────────────────────
            NavigationStack {
                CardsListView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { cardsToolbar }
                    .toolbarBackground(Ben.Color.cream, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
            }
            .tabItem {
                Label("Cards", systemImage: selectedTab == .cards
                      ? "rectangle.stack.fill" : "rectangle.stack")
            }
            .tag(BenTab.cards)

            // ── Settings ──────────────────────────────────────────
            NavigationStack {
                SettingsView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { settingsToolbar }
                    .toolbarBackground(Ben.Color.cream, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
            }
            .tabItem {
                Label("Settings", systemImage: selectedTab == .settings
                      ? "gearshape.fill" : "gearshape")
            }
            .tag(BenTab.settings)
        }
        .tint(Ben.Color.forest)                        // active tab + icon color
        .onAppear { styleTabBar() }
    }

    // MARK: - Tab enum
    enum BenTab {
        case home, cards, settings
    }

    // MARK: - Toolbars

    @ToolbarContentBuilder
    private var homeToolbar: some ToolbarContent {
        // Leading: card-stack icon (matches Amex app placement)
        ToolbarItem(placement: .navigationBarLeading) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Ben.Color.forest)
        }
        // Center: ben. wordmark
        ToolbarItem(placement: .principal) {
            Text("ben.")
                .font(Ben.Font.serif(20))
                .foregroundColor(Ben.Color.forest)
        }
        // Trailing: notifications bell
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                // TODO: open notifications
            } label: {
                Image(systemName: "bell")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(Ben.Color.forest)
            }
        }
    }

    @ToolbarContentBuilder
    private var cardsToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Ben.Color.forest)
        }
        ToolbarItem(placement: .principal) {
            Text("ben.")
                .font(Ben.Font.serif(20))
                .foregroundColor(Ben.Color.forest)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                // TODO: add card
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(Ben.Color.forest)
            }
        }
    }

    @ToolbarContentBuilder
    private var settingsToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text("ben.")
                .font(Ben.Font.serif(20))
                .foregroundColor(Ben.Color.forest)
        }
    }

    // MARK: - Tab bar appearance
    // Applies Ben cream background and forest tint to the native UITabBar.
    private func styleTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Ben.Color.cream)

        // Remove the default top separator line, replace with a subtle one
        appearance.shadowColor = UIColor(Ben.Color.sandBorder)

        // Unselected item color
        let unselected = UITabBarItemAppearance()
        unselected.normal.iconColor    = UIColor(Ben.Color.textMuted)
        unselected.normal.titleTextAttributes = [
            .foregroundColor: UIColor(Ben.Color.textMuted),
            .font: UIFont.systemFont(ofSize: 10, weight: .regular)
        ]
        appearance.stackedLayoutAppearance   = unselected
        appearance.inlineLayoutAppearance    = unselected
        appearance.compactInlineLayoutAppearance = unselected

        UITabBar.appearance().standardAppearance   = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Card Detail Nav Bar
// Use this toolbar in your CardDetailView so the nav bar icon
// matches the Amex pattern (card-stack icon leading, card name centered).

struct CardDetailToolbar: ToolbarContent {
    let cardName: String

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            // Back button handled automatically by NavigationStack
        }
        ToolbarItem(placement: .principal) {
            Text(cardName)
                .font(Ben.Font.sans(15, weight: .medium))
                .foregroundColor(Ben.Color.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}

// MARK: - Preview
#Preview {
    BenTabView()
}
