# FriendMap

A Copenhagen-only, invite-only social map app for friends to share and discover plans.

## Quick Start

### Prerequisites

- **Xcode 15.0+** (for iOS 17 SDK)
- **iOS 17.0+** simulator or device
- macOS Sonoma or later recommended

### Run the App

1. **Open the project in Xcode:**
   ```bash
   cd friendmap/ios
   open FriendMap.xcodeproj
   ```

2. **Select a simulator** (iPhone 15 recommended)

3. **Run the app** (⌘R)

The app runs with mock data by default - no backend configuration needed for the MVP.

### Optional: Configure Supabase

If you want to connect to a real backend:

1. Copy the config template:
   ```bash
   cp ios/FriendMap/Config/Config.example.plist ios/FriendMap/Config/Config.plist
   ```

2. Edit `Config.plist` with your Supabase credentials:
   - `SUPABASE_URL`: Your project URL
   - `SUPABASE_ANON_KEY`: Your anon/public key

3. The `Config.plist` file is gitignored to keep secrets out of version control.

## Project Structure

```
friendmap/
├── ios/                          # iOS app
│   ├── FriendMap.xcodeproj       # Xcode project
│   └── FriendMap/
│       ├── App/                  # App entry point
│       ├── Models/               # Data models
│       ├── Stores/               # State management (ObservableObject)
│       ├── Views/                # SwiftUI views
│       │   ├── Components/       # Reusable UI components
│       │   ├── Map/              # Map tab views
│       │   ├── Plans/            # Plans tab views
│       │   └── Profile/          # Profile tab views
│       ├── Config/               # Configuration files
│       ├── Utilities/            # Helpers (Logger, etc.)
│       └── Assets.xcassets       # Images and colors
├── backend/                      # Backend scaffolding
│   └── migrations/               # Database migrations
└── docs/                         # Documentation
```

## Architecture

- **MVVM** pattern with SwiftUI
- **Stores** as ObservableObjects injected via Environment
- **Dependency injection** for testability
- **Codable** models for future API integration

## Features (MVP)

### Map Tab
- Copenhagen-centered map view
- Friend plan pins with avatar annotations
- Tap to view plan details

### Plans Tab
- List of upcoming plans
- Create new plan with:
  - Title and description
  - Date and time picker
  - Location selection (preset Copenhagen spots)

### Profile Tab
- Edit name, age, bio
- Avatar placeholder (photo picker coming later)
- Persists to UserDefaults

### Safety
- Block and Report buttons on plan details
- Placeholder implementation (mock alerts)

## Troubleshooting

### "Signing Team" Error
1. Select the FriendMap target in Xcode
2. Go to Signing & Capabilities
3. Select your development team (or "None" for simulator only)

### Simulator Not Found
1. Xcode > Settings > Platforms
2. Install iOS 17 simulator if missing
3. If CoreSimulator issues: `xcodebuild -runFirstLaunch` (requires admin)

### Build Errors
1. Clean build folder: ⇧⌘K
2. Derived data: delete `~/Library/Developer/Xcode/DerivedData`
3. Restart Xcode

### Map Not Loading
- Simulator needs network access for map tiles
- Check your internet connection

## Tech Stack

- **iOS 17+** / Swift 5.9
- **SwiftUI** for UI
- **MapKit** for maps (iOS 17 API)
- **Supabase** (planned) for backend

## Backend

See [docs/backend.md](docs/backend.md) for:
- Database schema
- Row Level Security policies
- API architecture

## License

Private project - not for redistribution.
