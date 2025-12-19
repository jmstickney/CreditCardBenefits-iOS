# Firebase + Plaid Integration Guide

Complete guide to integrate Firebase backend with Plaid for transaction data.

## 🎯 Architecture Overview

```
iOS App (SwiftUI)
    ↓
Firebase Authentication (User login)
    ↓
Cloud Functions (Plaid API calls)
    ↓
Firestore (Store access tokens & transactions)
    ↓
Cloud Messaging (Push notifications)
```

## Step 1: Firebase Setup (15 min)

### 1.1 Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click **"Add project"**
3. Name: `CreditCardBenefits`
4. Disable Google Analytics (optional for now)
5. Click **"Create project"**

### 1.2 Add iOS App

1. In Firebase console → Click **iOS icon**
2. **Bundle ID**: `com.yourname.CreditCardBenefits` (must match Xcode)
3. **App nickname**: Credit Card Benefits
4. Download **`GoogleService-Info.plist`**
5. **Drag it into Xcode** (add to CreditCardBenefits target)

### 1.3 Enable Services

In Firebase Console:

**Authentication:**
- Go to **Authentication** → Get Started
- Enable **Email/Password**
- Enable **Sign in with Apple** (optional but recommended)

**Firestore Database:**
- Go to **Firestore Database** → Create database
- Start in **test mode** (we'll secure it later)
- Choose location: `us-central1`

**Cloud Functions:**
- Go to **Functions** → Get Started
- Upgrade to **Blaze plan** (pay-as-you-go, required for external API calls)
- Don't worry - costs ~$0 for development

**Cloud Messaging:**
- Go to **Cloud Messaging** → Already enabled
- Upload APNs certificate later for push notifications

## Step 2: Install Firebase SDK (10 min)

### 2.1 Add Firebase to Xcode

**Using Swift Package Manager:**

1. In Xcode: **File → Add Packages**
2. URL: `https://github.com/firebase/firebase-ios-sdk`
3. Select these packages:
   - ✅ FirebaseAuth
   - ✅ FirebaseFirestore
   - ✅ FirebaseFunctions
   - ✅ FirebaseMessaging
4. Click **Add Package**

### 2.2 Initialize Firebase

Update `CreditCardBenefitsApp.swift`:

```swift
import SwiftUI
import Firebase

@main
struct CreditCardBenefitsApp: App {

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
```

## Step 3: Plaid Setup (5 min)

1. Sign up at [Plaid Dashboard](https://dashboard.plaid.com/signup)
2. Get your credentials:
   - Client ID: `your_client_id`
   - Sandbox Secret: `your_sandbox_secret`
3. **Add to Firebase:**
   - Go to **Functions** → Environment Variables
   - Add: `PLAID_CLIENT_ID` = `your_client_id`
   - Add: `PLAID_SECRET` = `your_sandbox_secret`
   - Add: `PLAID_ENV` = `sandbox`

## Step 4: Firebase Cloud Functions (Backend)

### 4.1 Install Firebase CLI

```bash
npm install -g firebase-tools
firebase login
```

### 4.2 Initialize Functions

```bash
cd /Users/jonathanstickney/Desktop/code/benefits
firebase init functions
```

Select:
- Use existing project: **CreditCardBenefits**
- Language: **TypeScript**
- ESLint: **Yes**
- Install dependencies: **Yes**

### 4.3 Install Plaid SDK

```bash
cd functions
npm install plaid
```

### 4.4 Create Cloud Functions

Edit `functions/src/index.ts`:

```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { Configuration, PlaidApi, PlaidEnvironments } from 'plaid';

admin.initializeApp();

// Initialize Plaid
const plaidConfig = new Configuration({
  basePath: PlaidEnvironments[functions.config().plaid.env || 'sandbox'],
  baseOptions: {
    headers: {
      'PLAID-CLIENT-ID': functions.config().plaid.client_id,
      'PLAID-SECRET': functions.config().plaid.secret,
    },
  },
});

const plaidClient = new PlaidApi(plaidConfig);

// 1. Create Link Token
export const createLinkToken = functions.https.onCall(async (data, context) => {
  // Ensure user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
  }

  const userId = context.auth.uid;

  try {
    const response = await plaidClient.linkTokenCreate({
      user: { client_user_id: userId },
      client_name: 'Credit Card Benefits',
      products: ['transactions'],
      country_codes: ['US'],
      language: 'en',
    });

    return { link_token: response.data.link_token };
  } catch (error) {
    console.error('Error creating link token:', error);
    throw new functions.https.HttpsError('internal', 'Failed to create link token');
  }
});

// 2. Exchange Public Token
export const exchangePublicToken = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
  }

  const { publicToken } = data;
  const userId = context.auth.uid;

  try {
    const response = await plaidClient.itemPublicTokenExchange({
      public_token: publicToken,
    });

    const accessToken = response.data.access_token;
    const itemId = response.data.item_id;

    // Store access token in Firestore
    await admin.firestore().collection('users').doc(userId).collection('plaidItems').doc(itemId).set({
      accessToken: accessToken,
      itemId: itemId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, itemId: itemId };
  } catch (error) {
    console.error('Error exchanging token:', error);
    throw new functions.https.HttpsError('internal', 'Failed to exchange token');
  }
});

// 3. Get Transactions
export const getTransactions = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
  }

  const userId = context.auth.uid;
  const { startDate, endDate } = data;

  try {
    // Get all Plaid items for this user
    const itemsSnapshot = await admin
      .firestore()
      .collection('users')
      .doc(userId)
      .collection('plaidItems')
      .get();

    const allTransactions: any[] = [];

    // Fetch transactions for each linked account
    for (const doc of itemsSnapshot.docs) {
      const { accessToken } = doc.data();

      const response = await plaidClient.transactionsGet({
        access_token: accessToken,
        start_date: startDate || '2024-01-01',
        end_date: endDate || new Date().toISOString().split('T')[0],
      });

      allTransactions.push(...response.data.transactions);
    }

    // Store transactions in Firestore (for caching)
    const batch = admin.firestore().batch();
    const transactionsRef = admin.firestore().collection('users').doc(userId).collection('transactions');

    allTransactions.forEach((transaction) => {
      const docRef = transactionsRef.doc(transaction.transaction_id);
      batch.set(docRef, {
        ...transaction,
        fetchedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    await batch.commit();

    return { transactions: allTransactions };
  } catch (error) {
    console.error('Error fetching transactions:', error);
    throw new functions.https.HttpsError('internal', 'Failed to fetch transactions');
  }
});

// 4. Sync Transactions (Background Function - runs daily)
export const syncTransactions = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    const usersSnapshot = await admin.firestore().collection('users').get();

    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const itemsSnapshot = await userDoc.ref.collection('plaidItems').get();

      for (const itemDoc of itemsSnapshot.docs) {
        const { accessToken } = itemDoc.data();

        try {
          const endDate = new Date().toISOString().split('T')[0];
          const startDate = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)
            .toISOString()
            .split('T')[0];

          const response = await plaidClient.transactionsGet({
            access_token: accessToken,
            start_date: startDate,
            end_date: endDate,
          });

          // Store new transactions
          const batch = admin.firestore().batch();
          const transactionsRef = admin.firestore().collection('users').doc(userId).collection('transactions');

          response.data.transactions.forEach((transaction) => {
            const docRef = transactionsRef.doc(transaction.transaction_id);
            batch.set(docRef, {
              ...transaction,
              fetchedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          });

          await batch.commit();

          // Send push notification about new subscriptions detected
          // (Implement this later)
        } catch (error) {
          console.error(`Error syncing for user ${userId}:`, error);
        }
      }
    }
  });
```

### 4.5 Deploy Functions

```bash
firebase deploy --only functions
```

## Step 5: iOS Implementation

### 5.1 Create AuthService

Create `Services/AuthService.swift`:

```swift
import Foundation
import FirebaseAuth

class AuthService: ObservableObject {
    @Published var user: User?
    @Published var isAuthenticated = false

    init() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
            self?.isAuthenticated = user != nil
        }
    }

    func signUp(email: String, password: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        self.user = result.user
    }

    func signIn(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        self.user = result.user
    }

    func signOut() throws {
        try Auth.auth().signOut()
        self.user = nil
    }
}
```

### 5.2 Create PlaidService

Create `Services/PlaidService.swift`:

```swift
import Foundation
import FirebaseFunctions
import LinkKit

class PlaidService: ObservableObject {
    @Published var isLinked = false
    @Published var isLoading = false
    @Published var error: String?

    private let functions = Functions.functions()

    // 1. Create Link Token
    func createLinkToken() async throws -> String {
        let result = try await functions.httpsCallable("createLinkToken").call()

        guard let data = result.data as? [String: Any],
              let linkToken = data["link_token"] as? String else {
            throw PlaidError.invalidResponse
        }

        return linkToken
    }

    // 2. Present Plaid Link
    func presentPlaidLink(from viewController: UIViewController) async {
        do {
            isLoading = true
            let linkToken = try await createLinkToken()

            await MainActor.run {
                var linkConfiguration = LinkTokenConfiguration(
                    token: linkToken
                ) { [weak self] success in
                    Task {
                        await self?.exchangePublicToken(success.publicToken)
                    }
                }

                linkConfiguration.onExit = { [weak self] exit in
                    print("User exited Plaid Link")
                    self?.isLoading = false
                }

                let result = Plaid.create(linkConfiguration)
                switch result {
                case .success(let handler):
                    handler.open(presentUsing: .viewController(viewController))
                case .failure(let error):
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    // 3. Exchange Public Token
    private func exchangePublicToken(_ publicToken: String) async {
        do {
            let result = try await functions.httpsCallable("exchangePublicToken").call([
                "publicToken": publicToken
            ])

            await MainActor.run {
                self.isLinked = true
                self.isLoading = false
            }

            // Fetch transactions
            await fetchTransactions()
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    // 4. Fetch Transactions
    func fetchTransactions() async {
        do {
            let endDate = ISO8601DateFormatter().string(from: Date())
            let startDate = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-90 * 24 * 60 * 60))

            let result = try await functions.httpsCallable("getTransactions").call([
                "startDate": startDate.split(separator: "T")[0],
                "endDate": endDate.split(separator: "T")[0]
            ])

            guard let data = result.data as? [String: Any],
                  let transactionsData = data["transactions"] as? [[String: Any]] else {
                throw PlaidError.invalidResponse
            }

            // Process transactions
            print("Fetched \(transactionsData.count) transactions")

        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }
}

enum PlaidError: Error {
    case invalidResponse
}
```

### 5.3 Add Plaid Link SDK

1. In Xcode: **File → Add Packages**
2. URL: `https://github.com/plaid/plaid-link-ios`
3. Version: Latest
4. Add to target

### 5.4 Update HomeView

```swift
@StateObject private var authService = AuthService()
@StateObject private var plaidService = PlaidService()

// Replace "Connect Your Bank Account" button:
Button(action: {
    Task {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            await plaidService.presentPlaidLink(from: rootVC)
        }
    }
}) {
    Text(plaidService.isLoading ? "Connecting..." : "Connect Your Bank Account")
        .font(.system(size: 16, weight: .bold))
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding()
        .background(plaidService.isLoading ? Color.gray : Color.blue)
        .cornerRadius(12)
}
.disabled(plaidService.isLoading)
.padding(.horizontal)
```

## Step 6: Firestore Security Rules

In Firebase Console → Firestore → Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;

      match /plaidItems/{itemId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }

      match /transactions/{transactionId} {
        allow read: if request.auth != null && request.auth.uid == userId;
        allow write: if false; // Only cloud functions can write
      }
    }
  }
}
```

## Step 7: Push Notifications Setup

### 7.1 Enable Push in Xcode

1. Select **CreditCardBenefits** target
2. **Signing & Capabilities** → **+ Capability**
3. Add **Push Notifications**
4. Add **Background Modes** → Check **Remote notifications**

### 7.2 Request Permission

Add to `CreditCardBenefitsApp.swift`:

```swift
import FirebaseMessaging
import UserNotifications

@main
struct CreditCardBenefitsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()

        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            print("Push notification permission: \(granted)")
        }

        application.registerForRemoteNotifications()

        return true
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("FCM Token: \(fcmToken ?? "")")
        // Store token in Firestore
    }
}
```

## Step 8: Testing

### 8.1 Test Authentication

```swift
// Sign up
try await authService.signUp(email: "test@example.com", password: "password123")

// Sign in
try await authService.signIn(email: "test@example.com", password: "password123")
```

### 8.2 Test Plaid (Sandbox)

Use test credentials:
- Username: `user_good`
- Password: `pass_good`
- MFA: `1234`

## Costs

**Firebase (Blaze Plan):**
- Firestore: Free up to 1GB, 50K reads/day
- Functions: 2M invocations/month free
- Auth: Free
- **Estimated**: $0-5/month for MVP

**Plaid:**
- Sandbox: Free forever
- Development: 100 users free
- **Estimated**: $0 for MVP

**Total**: ~$0-5/month

## Next Steps

1. ✅ Add authentication UI
2. ✅ Implement transaction caching
3. ✅ Add pull-to-refresh
4. ✅ Send push notifications for new subscriptions
5. ✅ Add error handling and retry logic

---

**Ready to start!** Let me know which part you want to implement first.
