# Plaid Integration Guide

## Overview
Plaid allows you to securely connect to users' bank accounts and retrieve transaction data.

## Step 1: Sign Up for Plaid

1. **Create Account**: Go to https://dashboard.plaid.com/signup
2. **Get Credentials**:
   - Client ID: `your_client_id`
   - Sandbox Secret: `your_sandbox_secret`
   - Development Secret: `your_development_secret` (when ready for real data)

## Step 2: Add Plaid SDK to Xcode Project

### Option A: Swift Package Manager (Recommended)

1. **In Xcode**: File → Add Packages
2. **URL**: `https://github.com/plaid/plaid-link-ios`
3. **Version**: Select latest (currently 5.x)
4. **Add to target**: CreditCardBenefits
5. **Click Add Package**

### Option B: CocoaPods

Add to Podfile:
```ruby
pod 'Plaid'
```

Then run:
```bash
pod install
```

## Step 3: Configure Info.plist

Add these to your `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to scan documents for verification</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need photo library access to upload documents</string>
```

## Step 4: Backend Setup (Required)

⚠️ **IMPORTANT**: You CANNOT use Plaid secrets directly in the app - they must stay on your backend.

### Backend Endpoints You Need:

1. **Create Link Token** (`POST /api/plaid/create-link-token`)
   - Called before showing Plaid Link
   - Returns a `link_token`

2. **Exchange Public Token** (`POST /api/plaid/exchange-token`)
   - Called after user connects account
   - Exchanges `public_token` for `access_token`
   - Store `access_token` securely

3. **Get Transactions** (`POST /api/plaid/transactions`)
   - Called to fetch transactions
   - Uses stored `access_token`
   - Returns transaction data

### Simple Backend Example (Node.js/Express):

```javascript
const express = require('express');
const plaid = require('plaid');

const app = express();
app.use(express.json());

const client = new plaid.PlaidApi(
  new plaid.Configuration({
    basePath: plaid.PlaidEnvironments.sandbox, // or 'development'
    baseOptions: {
      headers: {
        'PLAID-CLIENT-ID': process.env.PLAID_CLIENT_ID,
        'PLAID-SECRET': process.env.PLAID_SECRET,
      },
    },
  })
);

// 1. Create Link Token
app.post('/api/plaid/create-link-token', async (req, res) => {
  try {
    const response = await client.linkTokenCreate({
      user: { client_user_id: req.body.userId },
      client_name: 'Credit Card Benefits',
      products: ['transactions'],
      country_codes: ['US'],
      language: 'en',
    });
    res.json({ link_token: response.data.link_token });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 2. Exchange Public Token
app.post('/api/plaid/exchange-token', async (req, res) => {
  try {
    const response = await client.itemPublicTokenExchange({
      public_token: req.body.public_token,
    });

    // Store access_token securely in database
    const accessToken = response.data.access_token;

    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 3. Get Transactions
app.post('/api/plaid/transactions', async (req, res) => {
  try {
    const response = await client.transactionsGet({
      access_token: req.body.access_token,
      start_date: '2024-01-01',
      end_date: '2024-12-31',
    });

    res.json({ transactions: response.data.transactions });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(3000);
```

## Step 5: iOS Implementation

### Create PlaidService.swift:

```swift
import LinkKit
import Foundation

class PlaidService: ObservableObject {
    @Published var isLinked = false
    @Published var transactions: [Transaction] = []

    private var linkToken: String?

    // 1. Get Link Token from your backend
    func createLinkToken(userId: String) async throws -> String {
        let url = URL(string: "https://your-backend.com/api/plaid/create-link-token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["userId": userId]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(LinkTokenResponse.self, from: data)

        self.linkToken = response.link_token
        return response.link_token
    }

    // 2. Present Plaid Link
    func presentPlaidLink(linkToken: String, from viewController: UIViewController) {
        var linkConfiguration = LinkTokenConfiguration(token: linkToken) { success in
            // User successfully linked account
            Task {
                await self.exchangePublicToken(success.publicToken)
            }
        }

        linkConfiguration.onExit = { exit in
            // User exited Link flow
            print("User exited: \\(exit)")
        }

        let result = Plaid.create(linkConfiguration)
        switch result {
        case .success(let handler):
            handler.open(presentUsing: .viewController(viewController))
        case .failure(let error):
            print("Error: \\(error)")
        }
    }

    // 3. Exchange public token on your backend
    private func exchangePublicToken(_ publicToken: String) async {
        do {
            let url = URL(string: "https://your-backend.com/api/plaid/exchange-token")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body = ["public_token": publicToken]
            request.httpBody = try JSONEncoder().encode(body)

            let (_, _) = try await URLSession.shared.data(for: request)

            await MainActor.run {
                self.isLinked = true
            }

            // Now fetch transactions
            await fetchTransactions()
        } catch {
            print("Error exchanging token: \\(error)")
        }
    }

    // 4. Fetch transactions from your backend
    func fetchTransactions() async {
        do {
            let url = URL(string: "https://your-backend.com/api/plaid/transactions")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"

            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(TransactionsResponse.self, from: data)

            await MainActor.run {
                self.transactions = response.transactions
            }
        } catch {
            print("Error fetching transactions: \\(error)")
        }
    }
}

struct LinkTokenResponse: Codable {
    let link_token: String
}

struct TransactionsResponse: Codable {
    let transactions: [Transaction]
}
```

### Update HomeView to Use Plaid:

```swift
@StateObject private var plaidService = PlaidService()

Button("Connect Your Bank Account") {
    Task {
        do {
            let linkToken = try await plaidService.createLinkToken(userId: "user123")
            // Present Plaid Link
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                plaidService.presentPlaidLink(linkToken: linkToken, from: rootVC)
            }
        } catch {
            print("Error: \\(error)")
        }
    }
}
```

## Step 6: Testing (Sandbox Mode)

In Sandbox mode, use these test credentials:

- **Username**: `user_good`
- **Password**: `pass_good`
- **MFA**: `1234`

This gives you fake transaction data to test with.

## Step 7: Move to Development

When ready for real data:

1. **Request Development Access** in Plaid Dashboard
2. **Switch environment** from `sandbox` to `development`
3. **Test with real bank accounts** (100 free in Development)
4. **Go through Plaid's compliance review** before production

## Cost Breakdown

- **Sandbox**: Free forever
- **Development**: 100 free users
- **Production**:
  - Transactions: $0.15-0.30/user/month
  - Auth (account verification): $0.05/verification
  - First 100 users: FREE

## Security Best Practices

1. ✅ **NEVER** store `client_secret` in the app
2. ✅ **ALWAYS** use your backend for Plaid API calls
3. ✅ Encrypt `access_token` in database
4. ✅ Use HTTPS for all API calls
5. ✅ Implement user authentication
6. ✅ Set up proper error handling

## Common Issues

### "Invalid link_token"
- Link tokens expire after 4 hours
- Create a fresh one each time

### "Invalid access_token"
- Item may have been disconnected
- User needs to re-link account

### "ITEM_LOGIN_REQUIRED"
- Bank credentials changed
- Prompt user to re-authenticate

## Next Steps After Integration

1. **Store transactions** in local database (CoreData/SwiftData)
2. **Sync periodically** (daily or when app opens)
3. **Handle errors gracefully** (connection issues, expired tokens)
4. **Add loading states** while fetching data
5. **Implement pull-to-refresh**

## Resources

- **Plaid Docs**: https://plaid.com/docs/
- **iOS Quickstart**: https://plaid.com/docs/link/ios/
- **Plaid Dashboard**: https://dashboard.plaid.com/
- **Sandbox Testing**: https://plaid.com/docs/sandbox/test-credentials/

---

**Estimated Time to Implement**: 4-8 hours
**Cost for MVP**: $0 (Sandbox + Development free tiers)
