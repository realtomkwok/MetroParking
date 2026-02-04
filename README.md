# MetroParking

<img width="1920" height="1080" alt="Cover" src="https://github.com/user-attachments/assets/f2096119-f72c-4883-915f-ee2406b360d9" />

A native iOS app for finding and
monitoring [NSW Transport Park&Ride facilities](https://transportnsw.info/travel-info/ways-to-get-around/drive/parking/transport-parkride-car-parks)
in real-time. Built with SwiftUI and powered by
the [TfNSW Car Park API](https://data.nsw.gov.au/data/dataset/2-car-park-api).

## Features

- **Real-time Availability**: Live parking space data for 37 Park&Ride facilities across NSW
- **Interactive Map**: Facility locations with availability status indicators
- **Global Search**: Find facilities quickly by name or suburb
- **Smart Sorting**: Sort by distance, availability, name, suburb, or capacity with persistent preferences
- **Pinned Facilities**: Save frequently used locations for quick access
- **ETA Calculations**: Driving time estimates using MapKit
- **Navigation Options**: Open directions in Apple Maps or Google Maps
- **Street View**: Look Around integration for facility reconnaissance
- **Location Services**: Distance calculations and nearby facility discovery
- **Home/Lock Screen Widgets**: Quick glance at your selected facility with deep linking to detail view
- **Background Refresh**: Automatic data updates using BGTaskScheduler
- **App Groups Integration**: Seamless data sharing between app and widgets
- **Onboarding Experience**: Welcome screen on first launch with feature highlights
- **Settings Menu**: Comprehensive settings including notifications, widgets, and app preferences


## Requirements

- iOS 26.0+
- Xcode 26.0+
- TfNSW API Key ([Get one here](https://opendata.transport.nsw.gov.au/))

## Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd MetroParking
   ```

2. **Configure environment**

   ### 1. Clone and Configure

```bash
git clone <repository-url>
cd MetroParking

# Copy the configuration template
cp Config.xcconfig.template Config.xcconfig
```

### 2. Edit Your Configuration

Open `Config.xcconfig` in any text editor and fill in your values:

```bash
// TfNSW API Configuration (REQUIRED)
TFNSW_API_KEY=your_actual_tfnsw_api_key_here
CAR_PARK_BASE_URL=https://api.transport.nsw.gov.au/v1

// Supabase Configuration (OPTIONAL - for analytics features)
SUPABASE_URL=your_supabase_project_url
SUPABASE_PUBLISHABLE_KEY=your_supabase_anon_key

// Development Configuration (REQUIRED)
DEVELOPMENT_TEAM=your_apple_developer_team_id
```

### 3. Build and Run

```bash
open MetroParking.xcodeproj
```

Hit ⌘+R. Done.

Read more about configuration: [Configuration](Docs/CONFIGURATION.md)

3. **Open in Xcode**
   ```bash
   open MetroParking.xcodeproj
   ```

4. **Build and run** (⌘+R)

## Architecture

### Core Components

- **Models**: SwiftData entities for persistent storage
    - `ParkingFacility`: Main facility data with occupancy caching
    - `ParkingZone`: Individual parking zones within facilities

- **Services**:
    - `ParkingAPIService`: TfNSW API integration
    - `ETAManager`: MapKit-based route calculations
    - `LocationManager`: Core Location wrapper

- **State Management**:
    - `FacilityManager`: Facility data loading with concurrency control
    - `SharedDataManager`: App Groups data sharing (app ↔ widget)
    - `BackgroundTaskManager`: BGTaskScheduler integration for background refresh
    - `AppStateManager`: App lifecycle state management
    - `WidgetBudgetTracker`: Widget reload budget management (60/day limit)
    - `OnboardingManager`: Onboarding flow state and navigation
    - `SearchManager`: Global facility search by name and suburb
    - `MapStateManager`: Map camera and selection state
    - `SheetStateManager`: Sheet presentation logic

- **Utilities**:
    - `RefreshConfiguration`: Unified refresh timing constants and cache validity tiers
    - `UserPreferences`: Centralised user preferences using @AppStorage
    - `Logger`: Centralised logging system

### Data Flow

1. **Initial Load**: Static facility metadata → SwiftData (shared via App Groups)
2. **Priority Tiers**:
   - Critical (widgets + favourites): 1 min cache (foreground) / 10 min (background)
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

## Project Structure

```
MetroParking/
├── MetroParking/
│   ├── Models/             # SwiftData models and API responses
│   ├── Views/              # SwiftUI views and components
│   │   ├── OnboardingView.swift    # First-launch onboarding
│   │   ├── SettingsView.swift      # Settings menu
│   │   └── ... (other views)
│   ├── Services/           # API and external service integrations
│   ├── Managers/           # State management and business logic
│   │   ├── OnboardingManager.swift # Onboarding state management
│   │   └── ... (other managers)
│   ├── Utils/              # Helpers, extensions, and configuration
│   │   ├── UserPreferences.swift   # User settings persistence
│   │   └── ... (other utilities)
│   └── MetroParkingApp.swift
├── MetroParkingWidget/     # Widget extension with AppIntent support
├── LiveActivityExtension/  # (Coming soon) Live Activity extension
├── Docs/                   # Documentation (widgets, concurrency, setup)
└── Config.xcconfig         # Environment configuration (gitignored)
```

## Key Files

- `ContentView.swift`: Main app interface with map and sheet
- `ParkingFacility.swift`: Core facility model with occupancy logic
- `FacilityManager.swift`: Handles facility data loading with concurrency control
- `BackgroundTaskManager.swift`: Manages background refresh tasks (BGTaskScheduler)
- `SharedDataManager.swift`: App Groups container for app ↔ widget data sharing
- `SearchManager.swift`: Global facility search with name/suburb matching
- `WidgetBudgetTracker.swift`: Widget reload budget management
- `RefreshConfiguration.swift`: Unified timing constants and cache validity tiers
- `ParkingAPIService.swift`: TfNSW API client implementation
- `MetroParkingWidget.swift`: Widget entry point with AppIntent configuration

## Development Notes

### Refresh Strategy

The app uses a tiered cache validity system with concurrency control:

1. **Foreground Refresh**: 60s cycle interval with tiered cache validation
   - Critical tier (widgets + favourites): 1 min cache validity
   - Standard tier (recently visited): 5 min cache validity
   - Background tier (others): 10 min cache validity

2. **Background Tasks**:
   - Quick refresh (15 min intervals): Updates critical + standard tiers
   - Full refresh (2 hour intervals): Updates all facilities

3. **Widget Budget**: 60 reloads per day, 15s minimum throttle between reloads

### Performance Optimisations

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


## Commercial Use

This open source version is available under GPL v3. The app is also available for purchase on the App Store. If you
create derivative works, they must also be distributed under GPL v3.

## Copyright

Copyright (C) 2025-2026 Tom Kwok

## Changelog

### v1.0.0 (January 2026) - First Public Release 🎉

**New Features**
- **Global Search**: Search facilities by name or suburb with `SearchManager`
- **Google Maps Navigation**: Open directions in Google Maps as an alternative to Apple Maps
- **Widget Deep Linking**: Tap widget to open specific facility detail view
- **Preserved Preferences**: Filter and sorting preferences persist across app launches
- **Progressive Refresh**: Data updates incrementally rather than in batches for smoother UX
- **Two-Tier Refresh System**: Simplified to "watched" (pinned/widget/visited) and "unwatched" tiers

**Performance & Stability**
- Fixed UI hangs and main thread blocking issues
- Resolved Swift concurrency issues for thread safety
- Improved widget-app communication reliability
- Optimized refresh intervals for reduced computation load
- Fixed breathing animation timing and state transitions

**UI/UX Improvements**
- Breathing animation while data is refreshing
- Better error messages displayed in UI
- Fixed bottom bar button transition bugs
- Enhanced visual feedback throughout the app

**TestFlight & Distribution**
- Added fastlane snapshot automation for App Store screenshots
- Added privacy report for App Store compliance
- Updated Info.plist to comply with Apple's agreements

### v0.4.0 (December 2025)

**User Experience Enhancements**
- Added onboarding screen for first-time users with feature highlights
- Implemented `OnboardingManager` for managing onboarding flow state
- Created settings menu with comprehensive app preferences
- Added `UserPreferences` for centralized settings persistence using @AppStorage
- Removed Supabase dependency for simplified architecture
- Enhanced widget display with improved visual feedback

**UI/UX Improvements**
- New app icon with dark mode variant
- Improved `FacilityDetailView` with better navigation and layout
- Enhanced `FacilityListView` with refined animations and transitions
- Updated `BackgroundGradient` with smoother colour transitions
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
- Optimised foreground refresh cycle from aggressive polling to 60s intervals

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

---

## Roadmap

**Current: v1.0.0 - First Public Release**
- [x] Available on TestFlight for beta testing
- [x] Core parking monitoring features complete
- [x] Widgets, background refresh, and search ready
- [x] Performance optimisations and stability fixes
- [x] Review and remove obsolete/redundant properties in `ParkingFacility` model
- [x] Rewrite MapKit implementation using `MKMapItem` and `MKAddress` from coordinates
- [x] Improve Apple Maps integration for better directions and place information
- [x] Add proper `CLPlacemark` reverse geocoding for facility addresses
- [x] Fix refresh logic to reduce API call frequency (fixed with tiered caching)
- [x] Add request coalescing and smarter refresh scheduling (operation locks)
- [x] Implement concurrency control to prevent overlapping refreshes
- [x] Add home screen widgets with AppIntent configuration
- [x] Implement widget budget tracking (60 reloads/day limit)
- [x] Add App Groups for app ↔ widget data sharing
- [x] Review and improve `LocationManager` implementation
- [x] Add "Always Allow" location permission flow for background features
- [x] Show traffic-aware ETA estimates

**WIP: v1.1.0**
- [x] Refine refresh mechanism
- [x] Add nearby parking recommendation to the detail page
- [ ] Add Chinese language support
- [ ] Audit accessibility issues

**Next: v1.2.0**
- [ ] Refine the search functionality so user can search a Sydney suburb for the nearest car park.
- [ ] Add lock screen widgets for quick vacancy checks
- [ ] Migrate to Swift 6 for strict concurrency

**On the roadmap**
- [ ] Add Chinese (zh-cn, zh-hk, zh-tw) and French language support
- [ ] Implement server-side caching strategy for scaling to thousands of users
- [ ] Review Supabase edge functions for batch processing efficiency
- [ ] Add historical patterns from Supabase insights
- [ ] Integrate [TfNSW GTFS Realtime Trip Updates API](https://opendata.transport.nsw.gov.au/data/dataset/public-transport-realtime-trip-update-v2)
- [ ] Show real-time train/metro arrivals for each Park&Ride facility
- [ ] Display service alerts and delays affecting nearby stations
- [ ] Add trip planning suggestions combining parking and transit
- [ ] Implement route alternatives based on current conditions
- [ ] Implement Live Activities for tracking selected facility availability
  - See `Docs/LIVE_ACTIVITY_IMPLEMENTATION_PLAN.md` for detailed implementation guide
- [ ] Add push notification support for vacancy alerts
- [ ] Implement threshold-based notifications ("Alert when under X spaces")

---

## Versions log


## Acknowledgments

- Transport for NSW for providing the Car Park API
- Data includes information from TfNSW Park&Ride facilities
- Built with Apple's SwiftUI, MapKit, and CoreLocation frameworks
