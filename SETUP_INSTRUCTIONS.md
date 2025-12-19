# Quick Setup - How to Open the SwiftUI App

## Option 1: Automatic Setup (Easiest)

Run this command in your terminal:

```bash
cd /Users/jonathanstickney/Desktop/code/benefits/CreditCardBenefits-iOS
open -a Xcode .
```

Then in Xcode:
1. **File → New → Project**
2. Choose **iOS → App**
3. Settings:
   - Product Name: `CreditCardBenefits`
   - Team: Your Apple ID
   - Organization Identifier: `com.yourname` (or whatever you want)
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: **None** (we'll add SwiftData later)
   - Include Tests: ✓ (optional)
4. Click **Next**
5. Save in: `CreditCardBenefits-iOS` folder
6. Click **Create**

Xcode will create the project. Now:
1. **Delete** the default `ContentView.swift` file Xcode created
2. In the left sidebar, you'll see the `CreditCardBenefits` folder
3. **Drag and drop** all folders from Finder into Xcode:
   - Models folder
   - Services folder
   - Data folder
   - Views folder
4. When prompted, choose **"Create groups"** and check "Copy items if needed"
5. Press **⌘+R** to build and run!

---

## Option 2: Manual File Addition

If you prefer to add files one by one:

1. Create the Xcode project (steps 1-6 above)
2. In Xcode, right-click on `CreditCardBenefits` folder
3. **New Group** → name it "Models"
4. Right-click Models → **Add Files to "CreditCardBenefits"**
5. Navigate to the Models folder and add all `.swift` files
6. Repeat for Services, Data, and Views folders

---

## Troubleshooting

### "Cannot find type 'Subscription' in scope"
- Make sure all files are added to the project target
- Check that files aren't in red (missing)
- Try **Product → Clean Build Folder** (⌘+Shift+K)

### "No such module 'SwiftUI'"
- Make sure your deployment target is iOS 16.0+
- Check **Build Settings → iOS Deployment Target**

### Files show in red in Xcode
- Right-click the file → **Show in Finder**
- Delete the reference in Xcode
- Drag the file back from Finder into Xcode

---

## Running the App

1. **Select target**: Choose "iPhone 15 Pro" (or any simulator) from the top bar
2. **Press ⌘+R** or click the Play button
3. Wait for simulator to boot and app to launch (~30 seconds first time)

The app will show:
- 7 subscriptions totaling $148.94/month
- $240-360/year in potential savings
- Matched benefits from Amex Platinum and Chase Sapphire Reserve

---

## Quick Demo

To show friends/investors:
1. Run on simulator (steps above)
2. Or use your iPhone:
   - Connect iPhone to Mac
   - Select your iPhone from device list
   - Trust computer if prompted
   - Press ⌘+R
   - May need to trust developer certificate in Settings

---

## Next Steps After Running

1. **Explore the code**:
   - [HomeView.swift](./CreditCardBenefits/Views/HomeView.swift) - Main UI
   - [SubscriptionDetector.swift](./CreditCardBenefits/Services/SubscriptionDetector.swift) - Detection logic
   - [CreditCardsData.swift](./CreditCardBenefits/Data/CreditCardsData.swift) - Benefits database

2. **Customize**:
   - Change colors in StatCard.swift
   - Add more cards to CreditCardsData.swift
   - Update mock data in MockData.swift

3. **Share**:
   - Show to potential users
   - Get feedback on UI/UX
   - Validate the value proposition

---

## File Structure Reference

```
CreditCardBenefits-iOS/
├── CreditCardBenefits/
│   ├── Models/
│   │   ├── Transaction.swift
│   │   ├── Subscription.swift
│   │   ├── CreditCard.swift
│   │   └── BenefitMatch.swift
│   ├── Services/
│   │   ├── SubscriptionDetector.swift
│   │   └── BenefitMatcher.swift
│   ├── Data/
│   │   ├── CreditCardsData.swift
│   │   └── MockData.swift
│   ├── Views/
│   │   ├── HomeView.swift
│   │   └── Components/
│   │       ├── StatCard.swift
│   │       ├── BenefitMatchCard.swift
│   │       └── SubscriptionRow.swift
│   └── CreditCardBenefitsApp.swift
├── README.md
└── SETUP_INSTRUCTIONS.md (this file)
```

All Swift files are ready - just need to create the Xcode project wrapper!
