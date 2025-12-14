# CLAUDE.MD - MetroParking Project Guide

This document provides context for AI assistants working on the MetroParking iOS application.

## Project Overview

MetroParking is a native iOS app for monitoring real-time parking availability at NSW Transport Park&Ride facilities. Built with SwiftUI and SwiftData, it integrates with the TfNSW Car Park API to provide live occupancy data for 37 facilities across NSW.

**Current Version**: 0.2.0 (December 2025)
**Platform**: iOS 18.4+
**Language**: Swift (SwiftUI)
**Architecture**: MVVM with SwiftData persistence

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
│   │   └── ... (other view components)
│   │
│   ├── ObservablesManagers/        # State management
│   │   ├── FacilityManager.swift   # Static data loading
│   │   ├── FacilityRefreshManager.swift # Live updates & scheduling
│   │   ├── MapStateManager.swift   # Map camera state
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
│   │   └── ... (other utilities)
│   │
│   ├── ContentView.swift           # Main view
│   ├── BackgroundGradient.swift    # Animated mesh gradient
│   └── MetroParkingApp.swift       # App entry point
│
├── Shared/                         # Shared resources (if applicable)
├── Widget-Availability-Small/      # Widget extension (WIP)
├── Config.xcconfig                 # Environment configuration
└── MetroParking.xcodeproj/         # Xcode project
```

## Key Architectural Patterns

### Data Flow
1. **Static Data**: `FacilityManager` loads facility metadata from JSON → SwiftData
2. **Live Updates**: `FacilityRefreshManager` fetches occupancy via `ParkingAPIService` → updates SwiftData models
3. **Priority Queue**: Pinned facilities + nearest 5 → remaining facilities
4. **Caching**: 15-minute occupancy cache per facility

### State Management
- **@Observable Macro**: Used for all manager classes
- **@MainActor**: UI-bound classes annotated for thread safety
- **SwiftData @Query**: Reactive data binding in views
- **@Environment**: Dependency injection for ModelContext and managers

### Refresh Strategy
- **High Priority Facilities** (15s): Kiama, Mona Vale, Warriewood, Dee Why, Gordon
- **Standard Priority** (60s): All other facilities
- **Favourite Multiplier**: 50% faster refresh for pinned facilities
- **Rate Limiting**: 500ms minimum interval between API requests

## Configuration

The app uses `Config.xcconfig` for environment variables:

```bash
# Required
TFNSW_API_KEY=<your_api_key>
CAR_PARK_BASE_URL=https://api.transport.nsw.gov.au/v1
DEVELOPMENT_TEAM=<your_team_id>

# Optional (for analytics)
SUPABASE_URL=<your_supabase_url>
SUPABASE_PUBLISHABLE_KEY=<your_supabase_key>
```

These are accessed via `Configuration.swift` enum.

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
1. Check `FacilityRefreshManager.swift`
2. Understand priority queue in `scheduleFacilityRefreshes()`
3. Test with different facility priorities
4. Verify rate limiting compliance

### Adding a New Utility
1. Create file in `Utils/` directory
2. Use static methods or protocol extensions
3. Document public API with comments
4. Add unit tests if logic is complex

## Known Issues & TODOs

### Critical
- [x] Refresh logic too aggressive (needs optimization)
- [ ] Remove obsolete properties from `ParkingFacility` model
- [ ] Distance caching incomplete (marked WIP in README)
- [ ] Review and fix `LocationManager` implementation

### High Priority
- [ ] Rewrite MapKit using `MKMapItem` and `MKAddress`
- [ ] Implement server-side caching for scaling
- [ ] Live Activities for vacancy tracking
- [ ] Home/Lock screen widgets

### Feature Roadmap

- Push notifications for vacancy alerts
- GTFS Realtime integration for transit arrivals
- Live traffic data integration
- Smart parking recommendations
- Swift 6 concurrency

## Development Workflow

### Building
```bash
open MetroParking.xcodeproj
# Press ⌘+R to build and run
```

### Testing
- Unit tests: `MetroParkingTests/`
- UI tests: `MetroParkingUITests/`
- Run with ⌘+U

### Git Workflow
- Main branch: `main`
- Feature branches: `feature/description`
- Current working branch: `1.0/reboot`

### Recent Commits
- UI redesign with glass effects and parallax scrolling
- Refactored sorting/filtering into protocol-based helper
- Added `FacilityDetailView` with sticky map header
- Separated list rendering from `ContentView`

## Dependencies

The app has minimal external dependencies:

- **Apple Frameworks**: SwiftUI, SwiftData, MapKit, CoreLocation
- **Third-party**: Supabase (an external database for historic data and trend insights)

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

Last updated: December 7, 2025
