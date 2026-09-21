# MetroParking

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

<img width="1920" height="1080" alt="Cover" src="https://github.com/user-attachments/assets/f2096119-f72c-4883-915f-ee2406b360d9" />

A native iOS app for finding and
monitoring [NSW Transport Park&Ride facilities](https://transportnsw.info/travel-info/ways-to-get-around/drive/parking/transport-parkride-car-parks)
in real-time. Built with SwiftUI and powered by
the [TfNSW Car Park API](https://data.nsw.gov.au/data/dataset/2-car-park-api).

## Features

- **Map-first design**: Every car park on a full-screen map, colour-coded by availability, with a Maps-style sheet on top
- **Real-time availability**: Live space counts for Park&Ride car parks across NSW
- **iPhone Duo ready**: A floating panel beside the map on the open inner display, filling the pane up to the fold; a bottom sheet on the outer display
- **Sort, filter and search**: By distance, availability, name or last update; pinned car parks first
- **Travel times**: Driving ETA and distance using MapKit, plus nearby car parks
- **Look Around**: Street-level imagery of each car park
- **Widgets**: A configurable home screen widget for any car park
- **Background refresh**: Pinned and widget car parks stay fresh with BGTaskScheduler
- **Navigation**: Open directions in Apple Maps or Google Maps

### Coming Soon
- **Live Activities**: Real-time parking monitoring on Lock Screen and Dynamic Island
- **Push Notifications**: Vacancy alerts and threshold-based notifications

## Requirements

- iOS 26.0+
- Xcode 27.0+ (Swift 6.4). Xcode 27.1 adds iPhone Duo fold handling and the iPhone Duo simulator.
- TfNSW API Key ([Get one here](https://opendata.transport.nsw.gov.au/))

## Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/realtomkwok/MetroParking.git
   cd MetroParking
   ```

2. **Configure environment**
   ```bash
   cp Config.xcconfig.template Config.xcconfig
   ```

   Open `Config.xcconfig` and fill in your values:
   ```bash
   // TfNSW API Configuration (REQUIRED)
   TFNSW_API_KEY=your_actual_tfnsw_api_key_here
   CAR_PARK_BASE_URL=https://api.transport.nsw.gov.au/v1

   // Development Configuration (REQUIRED)
   DEVELOPMENT_TEAM=your_apple_developer_team_id
   ```

   Both the app and the widget read these values. Without a valid key the app runs, but live data is unavailable.
   See [Configuration Guide](Docs/CONFIGURATION.md) for details.

3. **Build and run**
   ```bash
   open MetroParking.xcodeproj
   ```
   Select the `MetroParking` scheme and hit ⌘+R. Run the unit tests with ⌘+U.

## Architecture

See [Docs/ARCHITECTURE.md](Docs/ARCHITECTURE.md) for the full picture and
[Docs/IPHONE_DUO.md](Docs/IPHONE_DUO.md) for foldable layout rules.

- **Swift 6** language mode with complete data-race checking. App and widget code is main-actor isolated by default; the data layer (models, networking, configuration) is `nonisolated` so the widget and background tasks can use it.
- **SwiftUI + SwiftData + `@Observable`**, with services injected through `AppEnvironment`.
- **Shared code**: the widget compiles the model, networking and persistence files from the app target.

## Project Structure

```
MetroParking/
├── MetroParking/
│   ├── App/             # Entry point, root map view, AppEnvironment, deep links, preferences
│   ├── Core/
│   │   ├── Model/       # SwiftData models and seed data
│   │   ├── Networking/  # TfNSW API client, DTOs, rate limiting, usage quota
│   │   ├── Persistence/ # Shared SwiftData container, widget cache, configuration
│   │   ├── Refresh/     # Foreground and background refresh, widget reload budget
│   │   ├── Location/    # Location, ETAs, Look Around
│   │   └── Support/     # Logging and helpers
│   ├── Features/        # Map, Browse, FacilityDetail, Settings, Onboarding, Debug
│   ├── DesignSystem/    # Reusable views
│   └── Resources/       # Info.plist, entitlements, strings, assets
├── MetroParkingWidget/  # Widget extension (AppIntent configuration)
├── MetroParkingTests/   # Swift Testing unit tests
├── MetroParkingUITests/ # Screenshot automation (fastlane snapshot)
└── Docs/
```

## Development Notes

### Refresh Strategy

Timing lives in `RefreshConfiguration`.

1. **Foreground**: A refresh cycle every 5 minutes. Up to 4 requests run at once, with request starts spaced 0.4 s apart to respect the TfNSW rate limit.
   - Watched car parks (pinned or in a widget): 5 min cache validity
   - Everything else: 15 min cache validity
2. **Background tasks**:
   - Quick refresh (15–30 min depending on time of day): watched car parks that need it
   - Full refresh (every 2 hours): all car parks
3. **Widget**: Uses the newer of the shared store and its own cache; fetches when older than 5 minutes. App reloads are budgeted at 60 per day with a 15 s throttle.
4. **Quota**: A daily API counter in the App Group covers the app and the widget.

### Testing

Unit tests use Swift Testing and cover API decoding, availability thresholds, sheet navigation, deep links, the rate limiter, the usage counter and refresh scheduling:

```bash
xcodebuild test -project MetroParking.xcodeproj -scheme MetroParking \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:MetroParkingTests
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Follow the existing code style and architecture patterns
4. Add tests for new functionality
5. Commit changes (`git commit -m 'Add amazing feature'`)
6. Push to branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Code Style

- SwiftUI for all UI; lay out by size class, never by device or orientation
- Keep code building in Swift 6 mode with no concurrency warnings
- New data-layer types shared with the widget must be `nonisolated`
- Use `Logger` categories, not `print`
- Write new tests with Swift Testing

## API Documentation

For detailed API specifications, refer to
the [TfNSW Car Park API Documentation](https://opendata.transport.nsw.gov.au/dataset/car-park-api) included in this
repository.

## License

This project is licensed under the GNU General Public License v3.0 - see the LICENSE file for details.

## Commercial Use

This open source version is available under GPL v3. The app is also available for purchase on the App Store. If you
create derivative works, they must also be distributed under GPL v3.

## Copyright

Copyright (C) 2025-2026 Tom Kwok

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public
License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later
version.

## Changelog

### Unreleased

- Map-first main screen with a Maps-style sheet, and a floating panel on wide screens and the iPhone Duo inner display
- Swift 6 language mode; project reorganised into feature folders
- Faster refresh (concurrent, rate-limited requests) and fewer redundant widget API calls
- Fixed: daily API counter never reset; widget crash without an API key; widget colours in Chinese; forced refresh ignored during a running cycle

### v1.0 (February 2026)

**App Store Release**
- First public release on the App Store
- Preserved user filter and sorting preferences across sessions
- Refined refresh mechanism to respect user preferences
- Fixed UI hangs and performance issues
- Resolved Swift concurrency issues
- Added global search with `SearchManager`
- Privacy report and compliance updates

### v0.4.0 (January 2026)

**User Experience Enhancements**
- Added onboarding screen for first-time users with feature highlights
- Implemented `OnboardingManager` for managing onboarding flow state
- Created settings menu with comprehensive app preferences
- Added `UserPreferences` for centralized settings persistence using @AppStorage
- Removed Supabase dependency for simplified architecture
- Enhanced widget display with improved visual feedback
- Added Google Maps navigation support
- Added stale data UX with breathing animation while refreshing

**UI/UX Improvements**
- New app icon with dark mode variant
- Improved `FacilityDetailView` with better navigation and layout
- Enhanced `FacilityListView` with refined animations and transitions
- Updated `BackgroundGradient` with smoother color transitions
- Better permission request flow in `PermissionView`

**Documentation**
- Added `ONBOARDING_SETTINGS_PLAN.md` for feature planning
- Added `NEARBY_FACILITIES_IMPLEMENTATION.md` for future features
- Updated project structure and architecture documentation

### v0.3.0 (December 2025)

**Widget Support & Background Refresh**
- Added home/lock screen widgets with AppIntent configuration
- Implemented App Groups for seamless app ↔ widget data sharing
- Added `BackgroundTaskManager` for BGTaskScheduler integration
- Created `WidgetBudgetTracker` for managing daily reload budget (60/day)
- Implemented `RefreshConfiguration` for unified timing constants

**Concurrency & Performance Fixes**
- Fixed critical concurrency issue causing overlapping refresh operations
- Added operation lock to prevent duplicate refreshes
- Fixed background task scheduling to prevent exponential task growth
- Implemented tiered cache validity (1 min - 1 hour) based on facility priority
- Optimized foreground refresh cycle from aggressive polling to 60s intervals

**Architecture Improvements**
- Refactored `FacilityManager` with proper concurrency control
- Improved `SharedDataManager` with background context management
- Enhanced `AppStateManager` with lifecycle-aware scheduling
- Added comprehensive debugging with `APIUsageDebugView`

**Documentation**
- Added `Docs/Widgets/` with setup guides and budget analysis
- Added `Docs/Concurrency/` with fixes summary and review checklist
- Updated project structure documentation

### v0.2.0 (December 2025)

**New Features**
- Redesigned `ContentView` with iOS 26 glass effects and improved navigation
- New `FacilityDetailView` with sticky map header, parallax scrolling, and detailed vacancy information
- Added `FacilityListView` as a dedicated list component with swipe actions (pin, live activity, directions)
- Introduced `BackgroundGradient` with animated mesh gradient for visual polish
- New filter and sorting UI with `GlassEffectContainer` bottom bar controls

**Improvements**
- Refactored sorting and filtering logic into `SortAndFilterHelper` with protocol-based design
- Added `SortingOrder` enum for ascending/descending control
- Improved `ParkingFacility.displayName` parsing with regex for cleaner title/subtitle extraction
- Added `VacancyInfo` struct for grouped vacancy data
- Enhanced preview helpers with `previewFacilityManager` for better SwiftUI previews

**Architecture**
- Separated list rendering from `ContentView` into dedicated `FacilityList` component
- Added `TrailingIconLabelStyle` for consistent label styling
- Improved navigation with `matchedTransitionSource` and zoom transitions

### v0.1.0 (Initial Release)

- Real-time parking availability for 37 NSW Park&Ride facilities
- Interactive map with facility markers
- Smart sorting by distance, availability, name, and capacity
- Pinned facilities for quick access
- ETA calculations using MapKit
- SwiftData persistence

---

## Roadmap

### Widgets
- [x] Add home screen widgets with AppIntent configuration
- [x] Implement widget budget tracking (60 reloads/day limit)
- [x] Add App Groups for app ↔ widget data sharing
- [ ] Create additional widget sizes (medium, large)
- [ ] Add lock screen widgets for quick vacancy checks

### Live Activities & Notifications
- [ ] Implement Live Activities for tracking selected facility availability
  - See `Docs/IMPLEMENTATION_DECISION_LIVE_ACTIVITIES.md` for implementation guide
- [ ] Add push notification support for vacancy alerts
- [ ] Implement threshold-based notifications ("Alert when under X spaces")
  - See `Docs/NOTIFICATION_FEATURES_PLAN.md` for implementation guide

### Real-Time Transit Integration
- [ ] Integrate [TfNSW GTFS Realtime Trip Updates API](https://opendata.transport.nsw.gov.au/data/dataset/public-transport-realtime-trip-update-v2)
- [ ] Show real-time train/metro arrivals for each Park&Ride facility
- [ ] Display service alerts and delays affecting nearby stations
- [ ] Add trip planning suggestions combining parking and transit

### Smart Parking Suggestions
- [ ] Build alternative parking recommendation engine
- [ ] Factor in vacancy rates, traffic conditions, and distance
- [ ] Add "best time to arrive" suggestions based on trend data

### Location Services
- [ ] Add background location updates for proximity alerts
- [ ] Implement geofencing for automatic facility detection

## Acknowledgments

- Transport for NSW for providing the Car Park API
- Data includes information from TfNSW Park&Ride facilities
- Built with Apple's SwiftUI, MapKit, and CoreLocation frameworks
