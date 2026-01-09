# CLAUDE.MD - MetroParking Project Guide

This document provides context for AI assistants working on the MetroParking iOS application.

## Project Overview

MetroParking is a native iOS app for monitoring real-time parking availability at NSW Transport Park&Ride facilities. Built with SwiftUI and SwiftData, it integrates with the TfNSW Car Park API to provide live occupancy data for 37 facilities across NSW.

**Current Version**: 0.4.0 (December 2025)
**Platform**: iOS 18.4+ (iOS 26.0+ for onboarding)
**Language**: Swift (SwiftUI)
**Architecture**: MVVM with SwiftData persistence and App Groups for widget support

## Core Technologies

- **UI Framework**: SwiftUI with iOS 26 glass effects
- **Data Persistence**: SwiftData
- **Location Services**: CoreLocation + MapKit
- **Networking**: URLSession with custom API service layer
- **State Management**: @Observable macro, @MainActor classes

## Project Structure

```
MetroParking/
├── MetroParking/
│   ├── Models/                     # Data models and API responses
│   │   ├── ParkingFacility.swift   # Main facility model with SwiftData
│   │   ├── ParkingZone.swift       # Zone model for facility sections
│   │   ├── ParkingAPIModels.swift  # API response DTOs
│   │   ├── StaticFacilityInfo.swift # Static metadata
│   │   └── ParkingInsightModel.swift # Analytics model
│   │
│   ├── Views/                      # SwiftUI views
│   │   ├── ContentView.swift       # Main app interface
│   │   ├── FacilityDetailView.swift # Facility details with map
│   │   ├── FacilityList.swift      # List component
│   │   ├── OnboardingView.swift    # First-launch onboarding screen
│   │   ├── SettingsView.swift      # Settings menu
│   │   ├── APIUsageDebugView.swift # API usage and widget budget debugging
│   │   └── ... (other view components)
│   │
│   ├── Managers/                   # State management and business logic
│   │   ├── FacilityManager.swift   # Facility data loading with concurrency control
│   │   ├── SharedDataManager.swift # App Groups data sharing (app ↔ widget)
│   │   ├── BackgroundTaskManager.swift # BGTaskScheduler integration
│   │   ├── AppStateManager.swift   # App lifecycle state management
│   │   ├── OnboardingManager.swift # Onboarding flow state and navigation
│   │   ├── MapStateManager.swift   # Map camera state (ARCHIVED)
│   │   └── SheetStateManager.swift # Sheet presentation
│   │
│   ├── Services/                   # External integrations
│   │   ├── ParkingAPIService.swift # TfNSW API client
│   │   ├── ETAManager.swift        # MapKit route calculations
│   │   └── LocationManager.swift   # Location services wrapper
│   │
│   ├── Utils/                      # Helpers and extensions
│   │   ├── SortAndFilterHelper.swift # Sorting/filtering logic
│   │   ├── DistanceHelper.swift    # Distance calculations
│   │   ├── Logger.swift            # Logging utilities
│   │   ├── RefreshConfiguration.swift # Unified refresh timing constants
│   │   ├── WidgetBudgetTracker.swift # Widget reload budget management
│   │   ├── UserPreferences.swift   # Centralized user preferences using @AppStorage
│   │   └── ... (other utilities)
│   │
│   ├── ContentView.swift           # Main view
│   ├── BackgroundGradient.swift    # Animated mesh gradient
│   ├── MetroParkingApp.swift       # App entry point
│   └── Info.plist                  # Background modes and capabilities
│
├── MetroParkingWidget/             # Widget extension
│   ├── MetroParkingWidget.swift    # Widget entry point with AppIntent configuration
│   ├── FocusedFacilityWidgetView.swift # Widget UI for selected facility
│   ├── FacilityEntity.swift        # AppEntity for widget configuration
│   ├── MetroParkingWidgetBundle.swift # Widget bundle
│   └── Info.plist                  # Widget extension configuration
│
├── LiveActivityExtension/          # (Coming soon) Live Activity extension
│   ├── LiveActivityExtension.swift # Activity widget entry point
│   ├── ParkingLiveActivityView.swift # Lock Screen UI
│   ├── ParkingDynamicIslandView.swift # Dynamic Island UI
│   └── Info.plist                  # Extension configuration
│
├── Shared/                         # (Coming soon) Shared code between targets
│   └── ParkingActivityAttributes.swift # ActivityKit attributes model
│
├── Docs/                           # Documentation
│   ├── Widgets/                    # Widget implementation guides
│   │   ├── WIDGET_README.md
│   │   ├── WIDGET_SETUP_CHECKLIST.md
│   │   ├── WIDGET_BUDGET_UPDATE.md
│   │   └── ... (other widget docs)
│   ├── Concurrency/                # Concurrency and thread safety docs
│   │   ├── CONCURRENCY_FIXES_SUMMARY.md
│   │   └── CODE_REVIEW_CHECKLIST.md
│   ├── LIVE_ACTIVITY_IMPLEMENTATION_PLAN.md  # Live Activity implementation guide
│   ├── NOTIFICATION_FEATURES_PLAN.md         # Push notification implementation guide
│   └── CONFIGURATION.md            # Config.xcconfig setup guide
│
├── Config.xcconfig                 # Environment configuration
└── MetroParking.xcodeproj/         # Xcode project
```

## Key Architectural Patterns

### Data Flow
1. **Static Data**: `FacilityManager` loads facility metadata from JSON → SwiftData (shared via App Groups)
2. **Live Updates**: `FacilityManager` fetches occupancy via `ParkingAPIService` → updates SwiftData models
3. **Widget Updates**: `WidgetBudgetTracker` manages reload budget → `WidgetCenter.reloadAllTimelines()`
4. **Background Refresh**: `BackgroundTaskManager` schedules BGAppRefreshTask and BGProcessingTask
5. **Priority Tiers**: Critical (widgets + favorites) → Standard (recently visited) → Background (others)
6. **Caching**: Tiered cache validity (1-10 min foreground, 10-60 min background)

### State Management
- **@Observable Macro**: Used for all manager classes
- **@MainActor**: UI-bound classes annotated for thread safety
- **SwiftData @Query**: Reactive data binding in views
- **@Environment**: Dependency injection for ModelContext and managers

### Refresh Strategy
- **Foreground Cycle**: 60s interval for full refresh cycle
- **Cache Validity Tiers**:
  - Critical (widgets + favorites): 1 min foreground / 10 min background
  - Standard (recently visited): 5 min foreground / 30 min background
  - Background tier: 10 min foreground / 1 hour background
- **Widget Budget**: 60 reloads/day, 15s minimum throttle
- **Background Tasks**:
  - Quick refresh: 15 min interval
  - Full refresh: 2 hours interval
- **Concurrency Control**: Single operation lock prevents overlapping refreshes

## Configuration

The app uses `Config.xcconfig` for environment variables:

```bash
# Required
TFNSW_API_KEY=<your_api_key>
CAR_PARK_BASE_URL=https://api.transport.nsw.gov.au/v1
DEVELOPMENT_TEAM=<your_team_id>

# Optional (for carpark's vacancy trend)
SUPABASE_URL=<your_supabase_url>
SUPABASE_PUBLISHABLE_KEY=<your_supabase_key>
```

These are accessed via `Configuration.swift` enum.

**App Groups**: The app uses `group.com.tomkwok.MetroParking` for sharing SwiftData between the main app and widget extension. This is configured in:
- App target capabilities
- Widget extension capabilities
- `SharedDataManager.swift` (App Groups container)

## Widget Implementation

### Overview
The app includes a WidgetKit extension that displays real-time parking data on the home screen and lock screen. Widgets are fully configurable using AppIntents, allowing users to select which facility to monitor.

### Key Components

**Widget Files**:
- `MetroParkingWidget.swift`: Widget entry point with AppIntent configuration
- `FocusedFacilityWidgetView.swift`: SwiftUI view for widget display
- `FacilityEntity.swift`: AppEntity conformance for facility selection
- `MetroParkingWidgetBundle.swift`: Widget bundle registration

**Data Sharing**:
- Uses App Groups (`group.com.tomkwok.MetroParking`) for SwiftData sharing
- `SharedDataManager` provides shared ModelContainer for both targets
- Zero-copy data access - widgets read directly from app's database

**Budget Management**:
- `WidgetBudgetTracker`: Enforces 60 reloads/day limit
- 15-second minimum throttle between reloads
- Tracks reload history in UserDefaults
- Prevents budget exhaustion with smart throttling

**Widget Configuration**:
- Users select facility via AppIntent configuration UI
- Selected facility ID stored in widget configuration
- Widget displays: facility name, total/available/occupied spaces, last update time
- Visual indicators for vacancy levels (colors change based on availability)

### Widget Refresh Flow
1. App updates facility data in SwiftData (via `FacilityManager`)
2. `WidgetBudgetTracker.reloadIfAllowed()` checks budget/throttle
3. If allowed, calls `WidgetCenter.shared.reloadAllTimelines()`
4. Widget timeline provider fetches data from shared SwiftData
5. Widget UI updates with new data

### Background Refresh Integration
- `BackgroundTaskManager` schedules quick refreshes (15 min) for widget facilities
- Widget facilities treated as "critical" tier (highest priority)
- Background tasks call `performLoad()` → widget reload on completion
- Lifecycle-aware: schedules on `appWillResignActive`, cancels on foreground return

## Concurrency & Thread Safety

### Critical Fixes (December 2025)
The app underwent major concurrency improvements to fix overlapping refresh operations and duplicate task scheduling.

**Issue #1: Concurrent Refresh Operations**
- **Problem**: Multiple `performLoad()` calls could run simultaneously, causing data conflicts
- **Solution**: Added `currentOperationId: UUID?` to track active operations
- **Implementation**: Check operation ID before starting, use `defer` to safely clear on completion

**Issue #2: Redundant Auto-Refresh Scheduling**
- **Problem**: Every `performLoad()` completion called `scheduleNextRefresh()`, creating overlapping timers
- **Solution**: Added `shouldScheduleNext: Bool` parameter and debouncing with `lastScheduleTime`
- **Implementation**: Background tasks pass `shouldScheduleNext: false`, 5s minimum between schedules

**Issue #3: Duplicate Background Task Scheduling**
- **Problem**: Background task handlers re-scheduled themselves, causing exponential task growth
- **Solution**: Removed self-scheduling from `handleAppRefresh()`, moved to lifecycle events
- **Implementation**: `AppStateManager.appWillResignActive()` handles all scheduling

### Thread Safety Patterns
- **@MainActor**: All UI-bound managers are main-actor isolated
- **Background Contexts**: `SharedDataManager` uses background ModelContext for async work
- **Operation Locks**: Single UUID-based lock prevents concurrent refresh operations
- **Task Cancellation**: Proper cleanup with `defer` blocks and operation ID validation

### Testing & Debugging
- `APIUsageDebugView`: Real-time monitoring of API calls and widget reloads
- Console logging with OSLog categories (`.facilityRefresh`, `.widget`, `.backgroundTask`)
- See `Docs/Concurrency/CONCURRENCY_FIXES_SUMMARY.md` for detailed analysis
- Use `Docs/Concurrency/CODE_REVIEW_CHECKLIST.md` for reviewing async code

## User Experience Features

### Onboarding Flow
The app includes a first-launch onboarding experience to introduce new users to key features.

**Components**:
- `OnboardingView.swift`: Single-page welcome screen with feature highlights
- `OnboardingManager.swift`: State management for onboarding flow
- `UserPreferences.swift`: Persistent storage for user settings

**How It Works**:
1. On first launch, `OnboardingManager` checks `UserPreferences.hasCompletedOnboarding`
2. If false, displays onboarding sheet with `.interactiveDismissDisabled()`
3. User taps "Get Started" → marks onboarding complete → dismisses sheet
4. Can be re-triggered from Settings → About for reference

**Key Features Highlighted**:
- Pin favorite facilities for quick access
- Configure home screen widgets
- Smart alerts for vacancy notifications (coming soon)

**Implementation Notes**:
- Uses iOS 26 features (glass effects, symbol effects)
- Managed via `@Environment(OnboardingManager.self)` injection
- Non-dismissible until user explicitly completes
- Future enhancement: TipKit for contextual in-app tips

### User Preferences
Centralized settings management using `@AppStorage` for persistence.

**Stored Preferences**:
- `hasCompletedOnboarding`: Whether user has seen onboarding
- `notificationsEnabled`: Push notification opt-in status
- `vacancyThreshold`: Minimum spaces for alerts (default: 10)
- `widgetsConfigured`: Whether user has configured widgets
- `preferredSortOption`: Default sorting preference
- `enableHaptics`: Haptic feedback toggle

**Usage Pattern**:
```swift
UserPreferences.shared.hasCompletedOnboarding = true
```

All preferences automatically persist to UserDefaults and survive app restarts.

## Important Models

### ParkingFacility
The core SwiftData model representing a Park&Ride facility.

**Key Properties**:
- `facilityID`: Unique identifier
- `name`: Full facility name (e.g., "Sutherland Station Park&Ride")
- `displayName`: Parsed tuple (title: "Sutherland", subtitle: "Station")
- `location`: CLLocationCoordinate2D for map display
- `totalSpaces`, `occupiedSpaces`, `availableSpaces`: Capacity data
- `lastOccupancyUpdate`: Timestamp for cache validation
- `isPinned`: User favorite status
- `zones`: Related ParkingZone entities

**Methods**:
- `needsOccupancyRefresh() -> Bool`: 15-minute cache check
- `updateOccupancy(from:)`: Updates from API response
- `distanceFrom(location:) -> CLLocationDistance?`: Distance calculation

### ParkingZone
SwiftData model for individual parking zones within a facility.

**Properties**:
- `id`, `name`, `messageText`: Zone metadata
- `spots`, `occupiedSpaces`, `availableSpaces`: Zone capacity
- `facility`: Parent relationship

## API Integration

### TfNSW Car Park API
**Base URL**: `https://api.transport.nsw.gov.au/v1/carpark`

**Headers**:
- `Authorization: apikey {TFNSW_API_KEY}`
- `Accept: application/json`

**Endpoints**:
1. List all facilities: `GET /carpark`
2. Facility occupancy: `GET /carpark?facility={facilityID}`

**Rate Limiting**:
- Hard limit: 1 second between requests (enforced by `RateLimiter`)
- Exponential backoff on failures
- API rate limit debugger

**Error Handling**:
- Network errors: Retry with backoff
- API errors: Log and skip facility
- Invalid responses: Validate before model update

## Code Style Guidelines

### Swift Conventions
- Use SwiftUI for all UI components. Can integrate with UIKit if SwiftUI fails to provide the best and most performant solution
- Prefer `@Observable` over `ObservableObject` (modern Swift)
- Use `@MainActor` for all UI-bound classes
- Leverage SwiftData `@Query` for reactive data
- Use `async/await` for asynchronous operations

### Naming Conventions
- **Views**: `{Feature}View.swift` (e.g., `FacilityDetailView`)
- **Managers**: `{Feature}Manager.swift` (e.g., `FacilityRefreshManager`)
- **Services**: `{Feature}Service.swift` (e.g., `ParkingAPIService`)
- **Models**: `{Entity}.swift` (e.g., `ParkingFacility`)
- **Helpers**: `{Purpose}Helper.swift` (e.g., `SortAndFilterHelper`)

### File Organisation
- Group related files in directories (`Models/`, `Views/`, etc.)
- Keep views focused and composable
- Extract reusable components into separate files
- Place business logic in managers, not views

### Performance Considerations
- **Caching**: Always check cache before API calls
- **Distance Calculations**: Cache results within 100m movement (WIP)
- **SwiftData**: Use `@Query` with predicates for filtered data
- **MapKit**: Reuse MKMapItem instances where possible

## Common Tasks

### Adding a New View
1. Create file in `Views/` directory
2. Import SwiftUI and required dependencies
3. Use `@Environment(\.modelContext)` for SwiftData access
4. Preview with `PreviewHelper.previewFacilityManager`

### Adding a New API Endpoint
1. Add response DTO to `ParkingAPIModels.swift`
2. Add method to `ParkingAPIService.swift`
3. Handle errors and rate limiting
4. Update relevant manager to consume new data

### Modifying Refresh Logic
1. Check `FacilityManager.swift` for foreground refresh
2. Check `BackgroundTaskManager.swift` for background task scheduling
3. Review `RefreshConfiguration.swift` for all timing constants
4. Understand priority tiers in `performLoad()`
5. Test with `APIUsageDebugView` to verify budget compliance
6. Verify concurrency control (single operation lock)

### Adding a New Utility
1. Create file in `Utils/` directory
2. Use static methods or protocol extensions
3. Document public API with comments
4. Add unit tests if logic is complex

### Working with Widgets
1. **Widget Configuration**:
   - Widgets use AppIntent for user configuration
   - `FacilityEntity` conforms to `AppEntity` for facility selection
   - Configuration stored per-widget instance

2. **Data Access**:
   - Widgets access shared SwiftData via `SharedDataManager.sharedContainer`
   - Use background ModelContext for async queries
   - Never perform long-running operations in timeline provider

3. **Budget Management**:
   - Always use `WidgetBudgetTracker.reloadIfAllowed()` before reloading
   - Check remaining budget with `WidgetBudgetTracker.shared.remainingBudget`
   - Monitor reloads in `APIUsageDebugView`

4. **Testing**:
   - Use Xcode's widget preview in Widget extension target
   - Test different configurations and data states
   - Verify budget tracking doesn't exhaust daily limit
   - Test with app in background/foreground/terminated states

### Working with Live Activities (Planned - v0.5.0)

**Overview**: Live Activities provide real-time parking monitoring on Lock Screen and Dynamic Island (iPhone 14 Pro+).

**Key Differences from Widgets**:
- **No Budget Limit**: Live Activities can update frequently without the 60/day widget limit
- **Lifecycle**: Started/stopped by user action, lasts up to 8 hours (12 hours with push)
- **Update Frequency**: Can update every 1-2 minutes via background refresh
- **UI Locations**: Lock Screen + Dynamic Island (vs. Home Screen for widgets)

**Implementation Guide**:
- See `Docs/LIVE_ACTIVITY_IMPLEMENTATION_PLAN.md` for complete step-by-step implementation
- Requires iOS 16.1+ (ActivityKit framework)
- Uses same App Groups infrastructure as widgets
- Integrates with existing `BackgroundTaskManager` for automatic updates
- No notification services required (independent feature)

**Architecture**:
- `ParkingActivityAttributes`: Defines static (facility info) and dynamic (vacancy) state
- `LiveActivityManager`: Manages activity lifecycle (start/stop/update)
- `ParkingLiveActivityView`: Lock Screen UI with capacity indicators
- `ParkingDynamicIslandView`: Compact/expanded/minimal Dynamic Island views
- Background updates via existing `performQuickRefresh()` in `BackgroundTaskManager`

**When to Use**:
- User wants to monitor a specific facility while getting ready to leave
- Better than widgets: Real-time updates without budget constraints
- Better than notifications: Always-visible glanceable information
- Complements widgets: Widgets for quick glance, Live Activities for active monitoring

## Known Issues & TODOs

### Critical
- [x] Refresh logic too aggressive (needs optimization)
- [x] Remove obsolete properties from `ParkingFacility` model
- [x] Distance caching incomplete (marked WIP in README)
- [x] Review and fix `LocationManager` implementation
- [x] Widget data stops refreshing - fixed with proper App Groups setup
- [x] Concurrency issues causing overlapping refreshes - fixed with operation locks
- [ ] Better UX for displaying stale data

### High Priority
- [x] Rewrite MapKit using `MKMapItem` and `MKAddress`
- [ ] Implement server-side caching for scaling
- **[ ] Live Activities for vacancy tracking** ← **NEXT PRIORITY (v0.5.0)**
- [x] Home/Lock screen widgets
- [ ] Backup supports for iOS 18

### Feature Roadmap (v0.5.0 - v0.6.0)

**v0.5.0 (January 2025) - Live Activities & Notifications**
- [ ] Live Activities for real-time parking monitoring on Lock Screen/Dynamic Island
  - See `Docs/LIVE_ACTIVITY_IMPLEMENTATION_PLAN.md` for detailed implementation guide
  - Estimated: 3-4 sessions
  - Dependencies: Existing `BackgroundTaskManager` and App Groups infrastructure
- [ ] Push notifications for vacancy alerts (after Live Activities)
  - See `Docs/NOTIFICATION_FEATURES_PLAN.md` for detailed implementation guide
  - Estimated: 4-5 sessions
  - Can integrate with Live Activities for remote push updates

**v0.6.0+ (Future)**
- GTFS Realtime integration for transit arrivals
- Live traffic data integration
- Smart parking recommendations
- Swift 6 concurrency migration

## Development Workflow

### Building
```bash
open MetroParking.xcodeproj
# Press ⌘+R to build and run
```
Use Simulator `iPhone 17 Pro, iOS 26.2` to build and test for now.

### Testing
- Unit tests: `MetroParkingTests/`
- UI tests: `MetroParkingUITests/`
- Run with ⌘+U

### Git Workflow
- Main branch: `main`
- Feature branches: `feature/description`
- Current working branch: `1.0/reboot`

### Recent Commits
- Added onboarding screen with feature highlights and OnboardingManager
- Implemented UserPreferences for centralized settings using @AppStorage
- Created comprehensive settings menu with navigation
- Removed Supabase dependency for simplified architecture
- Enhanced widget display and UI refinements
- Added widget support with AppIntent configuration and App Groups
- Fixed critical concurrency issues (overlapping refreshes, duplicate task scheduling)
- Implemented unified refresh configuration with tiered cache validity
- Added background task management with BGTaskScheduler
- Created widget budget tracker for daily reload management

## Dependencies

The app has minimal external dependencies:

- **Apple Frameworks**: SwiftUI, SwiftData, MapKit, CoreLocation, WidgetKit, BackgroundTasks, UserNotifications, ActivityKit (planned)
- **Third-party**: None (Supabase dependency removed in v0.4.0)
- **App Extensions**:
  - WidgetKit extension for home/lock screen widgets
  - Live Activity extension (planned for v0.5.0)

## Security & Privacy

- **API Keys**: Stored in `Config.xcconfig` (gitignored)
- **Location**: User permission required, used only for distance calculations
- **Data Storage**: All data stored locally with SwiftData
- **Network**: HTTPS only, API key in headers

## License

GPL v3.0 - Commercial version available on App Store.

## Helpful Commands

```bash
# Find all SwiftUI views
find . -type f -name "*View.swift"

# Search for API calls
grep -r "ParkingAPIService" --include="*.swift"

# Find all @Observable classes
grep -r "@Observable" --include="*.swift"

# Check SwiftData models
grep -r "@Model" --include="*.swift"
```

## AI Assistant Guidelines

When working on this project:

1. **Read Before Modifying**: Always read existing files before proposing changes
2. **Follow Patterns**: Match existing architectural patterns and code style
3. **Test Assumptions**: Check actual implementation, don't assume structure
4. **Minimal Changes**: Only modify what's necessary for the task
5. **SwiftUI Best Practices**: Use modern SwiftUI patterns (@Observable, @Query)
6. **Performance**: Consider API rate limits and caching implications
7. **Documentation**: Update this file if you make architectural changes

## Contact

**Author**: Tom Kwok
**Copyright**: (C) 2025 Tom Kwok
**Repository**: (https://github.com/realtomkwok/MetroParking)[]

---

## Next Steps: Live Activities Implementation

**Implementation Decision (December 28, 2025)**:
- **Priority**: Live Activities first, push notifications second
- **Rationale**: Live Activities are independent of UserNotifications framework and provide better UX for parking monitoring (always-visible vs. alert-based)
- **Dependencies**: Existing background refresh infrastructure is ready - no notification services needed
- **Implementation Guide**: See `Docs/LIVE_ACTIVITY_IMPLEMENTATION_PLAN.md` for complete step-by-step guide
- **Estimated Effort**: 3-4 implementation sessions
- **Enhancement Path**: After Live Activities work locally, can add ActivityKit push notifications for remote updates (extends to 12 hours)

---

Last updated: December 28, 2025
