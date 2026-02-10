# MetroParking

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

<img width="1920" height="1080" alt="Cover" src="https://github.com/user-attachments/assets/f2096119-f72c-4883-915f-ee2406b360d9" />

A native iOS app for finding and
monitoring [NSW Transport Park&Ride facilities](https://transportnsw.info/travel-info/ways-to-get-around/drive/parking/transport-parkride-car-parks)
in real-time. Built with SwiftUI and powered by
the [TfNSW Car Park API](https://data.nsw.gov.au/data/dataset/2-car-park-api).

## Features

- **Real-time Availability**: Live parking space data for 37 Park&Ride facilities across NSW
- **Interactive Map**: Facility locations with availability status indicators
- **Smart Sorting**: Sort by distance, availability, name, suburb, or capacity
- **Pinned Facilities**: Save frequently used locations for quick access
- **ETA Calculations**: Traffic-aware driving time estimates using MapKit
- **Street View**: Look Around integration for facility reconnaissance
- **Location Services**: Distance calculations and nearby facility discovery
- **Search**: Find facilities by name or suburb
- **Home/Lock Screen Widgets**: Quick glance at your selected facility with configurable AppIntent
- **Background Refresh**: Automatic data updates using BGTaskScheduler
- **App Groups Integration**: Seamless data sharing between app and widgets
- **Onboarding Experience**: Welcome screen on first launch with feature highlights
- **Settings Menu**: Comprehensive settings including notifications, widgets, and app preferences
- **Navigation**: Open directions in Apple Maps or Google Maps

### Coming Soon
- **Live Activities**: Real-time parking monitoring on Lock Screen and Dynamic Island
- **Push Notifications**: Vacancy alerts and threshold-based notifications

## Requirements

- iOS 26.0+
- Xcode 16.3+
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

   See [Configuration Guide](Docs/CONFIGURATION.md) for details.

3. **Build and run**
   ```bash
   open MetroParking.xcodeproj
   ```
   Hit ⌘+R.

## Architecture

### Core Components

- **Models**: SwiftData entities for persistent storage
    - `ParkingFacility`: Main facility data with occupancy caching
    - `ParkingZone`: Individual parking zones within facilities

- **Services**:
    - `ParkingAPIService`: TfNSW API integration

- **Managers**:
    - `FacilityManager`: Facility data loading with concurrency control
    - `SharedDataManager`: App Groups data sharing (app ↔ widget)
    - `BackgroundTaskManager`: BGTaskScheduler integration for background refresh
    - `AppStateManager`: App lifecycle state management
    - `ETAManager`: MapKit-based route calculations
    - `LocationManager`: Core Location wrapper
    - `MapsManager`: Map interaction and navigation
    - `LookAroundManager`: Street View integration
    - `SearchManager`: Facility search
    - `DeepLinkManager`: URL scheme handling
    - `OnboardingManager`: Onboarding flow state and navigation
    - `UserPreferences`: Centralized user preferences using @AppStorage

- **Utilities**:
    - `RefreshConfiguration`: Unified refresh timing constants and cache validity tiers
    - `WidgetBudgetTracker`: Widget reload budget management (60/day limit)
    - `SortAndFilterHelper`: Sorting and filtering logic
    - `Logger`: Centralized logging system (shared target)

### Data Flow

1. **Initial Load**: Static facility metadata → SwiftData (shared via App Groups)
2. **Priority Tiers**:
   - Critical (widgets + favorites): 1 min cache (foreground) / 10 min (background)
   - Standard (recently visited): 5 min cache (foreground) / 30 min (background)
   - Background tier: 10 min cache (foreground) / 1 hour (background)
3. **Foreground Updates**: 60s refresh cycle with tiered cache validation
4. **Background Tasks**:
   - Quick refresh (15 min intervals): Critical + Standard tiers
   - Full refresh (2 hour intervals): All facilities
5. **Widget Updates**: Budget-controlled reloads (60/day, 15s throttle)

### API Integration

The app consumes the [TfNSW Car Park API](https://opendata.transport.nsw.gov.au/):

- **Facilities Endpoint**: `/v1/carpark` - List all facilities
- **Occupancy Endpoint**: `/v1/carpark?facility={id}` - Real-time data
- **Rate Limiting**: Managed by `RefreshConfiguration` with tiered intervals
- **Error Handling**: Exponential backoff for failed requests
- **Concurrency Control**: Single operation lock prevents overlapping refreshes

## Project Structure

```
MetroParking/
├── MetroParking/
│   ├── Models/             # SwiftData models and API responses
│   ├── Views/              # SwiftUI views and components
│   │   ├── Components/     # Reusable UI components (e.g., ParkingProgressGauge)
│   │   └── ...
│   ├── Services/           # API client (ParkingAPIService)
│   ├── Managers/           # State management and business logic
│   ├── Utils/              # Helpers, extensions, and configuration
│   ├── Tips/               # TipKit definitions
│   └── MetroParkingApp.swift
├── MetroParkingWidget/     # Widget extension with AppIntent support
├── Shared/                 # Shared code between targets (Logger)
├── Docs/                   # Documentation (widgets, concurrency, setup)
│   ├── Widgets/            # Widget implementation guides
│   ├── Concurrency/        # Concurrency fixes and review checklists
│   └── Components/         # Architecture and migration docs
└── Config.xcconfig         # Environment configuration (gitignored)
```

## Key Files

- `ContentView.swift`: Main app interface with map and facility list
- `ParkingFacility.swift`: Core SwiftData model with occupancy logic
- `FacilityManager.swift`: Facility data loading with concurrency control
- `BackgroundTaskManager.swift`: BGTaskScheduler integration for background refresh
- `SharedDataManager.swift`: App Groups container for app ↔ widget data sharing
- `ParkingAPIService.swift`: TfNSW API client implementation
- `RefreshConfiguration.swift`: Unified timing constants and cache validity tiers
- `WidgetBudgetTracker.swift`: Widget reload budget management
- `MetroParkingWidget.swift`: Widget entry point with AppIntent configuration
- `WidgetAPIService.swift`: Dedicated API service for widget data fetching

## Development Notes

### Refresh Strategy

The app uses a tiered cache validity system with concurrency control:

1. **Foreground Refresh**: 60s cycle interval with tiered cache validation
   - Critical tier (widgets + favorites): 1 min cache validity
   - Standard tier (recently visited): 5 min cache validity
   - Background tier (others): 10 min cache validity

2. **Background Tasks**:
   - Quick refresh (15 min intervals): Updates critical + standard tiers
   - Full refresh (2 hour intervals): Updates all facilities

3. **Widget Budget**: 60 reloads per day, 15s minimum throttle between reloads

4. **Concurrency Control**: Operation lock prevents overlapping refreshes

### Performance Optimizations

- **Tiered Cache Validity**: 1-60 min depending on facility priority and app state
- **Widget Budget Management**: Prevents budget exhaustion with smart throttling
- **Background Task Scheduling**: Intelligent scheduling based on time of day
- **Concurrency Control**: Prevents overlapping refreshes with operation locks
- **App Groups**: Zero-copy data sharing between app and widgets
- **Smart Scheduling**: Exponential backoff for failed requests
- **Memory Management**: SwiftData with automatic persistence

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Follow the existing code style and architecture patterns
4. Add tests for new functionality
5. Commit changes (`git commit -m 'Add amazing feature'`)
6. Push to branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Code Style

- Use SwiftUI for all UI components
- Follow MVVM architecture patterns
- Leverage SwiftData for persistence
- Use `@MainActor` for UI-bound classes
- Implement proper error handling and logging

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
