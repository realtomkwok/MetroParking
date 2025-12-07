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
- **ETA Calculations**: Driving time estimates using MapKit
- **Street View**: Look Around integration for facility reconnaissance
- **Location Services**: Distance calculations and nearby facility discovery

## Requirements

- iOS 18.4+
- Xcode 16.3+
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
    - `ETAService`: MapKit-based route calculations
    - `LocationManager`: Core Location wrapper

- **State Management**:
    - `FacilityDataManager`: Static facility data loading
    - `FacilityRefreshManager`: Live occupancy updates with priority queuing
    - `MapStateManager`: Map camera and selection state
    - `SheetStateManager`: Sheet presentation logic

### Data Flow

1. **Initial Load**: Static facility metadata → SwiftData
2. **Priority Refresh**: Pinned facilities → Nearest 5 → Remaining facilities
3. **Ongoing Updates**: Smart refresh scheduling based on facility priority and app state
4. **Caching**: 15-minute occupancy cache with validation

### API Integration

The app consumes the [TfNSW Car Park API](https://opendata.transport.nsw.gov.au/):

- **Facilities Endpoint**: `/v1/carpark` - List all facilities
- **Occupancy Endpoint**: `/v1/carpark?facility={id}` - Real-time data
- **Rate Limiting**: 500ms minimum interval between requests
- **Error Handling**: Exponential backoff for failed requests

## Project Structure

```
MetroParking/
├── Models/                 # SwiftData models and API responses
├── Views/                  # SwiftUI views and components
├── Services/               # API and external service integrations  
├── ObservablesManagers/    # State management and business logic
├── Utils/                  # Helpers and extensions
└── Configuration.swift     # App configuration management
```

## Key Files

- `ContentView.swift`: Main app interface with map and sheet
- `ParkingFacility.swift`: Core facility model with occupancy logic
- `FacilityRefreshManager.swift`: Handles all API updates and scheduling
- `ParkingAPIService.swift`: TfNSW API client implementation
- `LocationManager.swift`: Location services and distance calculations

## Development Notes

### Refresh Strategy

The app uses a priority-based refresh system:

1. **High Priority** (15s updates): Kiama, Mona Vale, Warriewood, Dee Why, Gordon
2. **Standard Priority** (60s updates): All other facilities
3. **Favourite Multiplier**: 50% faster refresh for pinned facilities
4. **Background Mode**: Reduced refresh frequency when app in the background

### Performance Optimizations

- **Distance Caching**: Cached calculations valid within 100m movement [WIP]
- **Occupancy Caching**: 15-minute validity to reduce API calls
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

Copyright (C) 2025 Tom Kwok

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public
License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later
version.

## Changelog

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

### Data Model & MapKit Improvements
- [ ] Review and remove obsolete/redundant properties in `ParkingFacility` model
- [ ] Rewrite MapKit implementation using `MKMapItem` and `MKAddress` from coordinates
- [ ] Improve Apple Maps integration for better directions and place information
- [ ] Add proper `CLPlacemark` reverse geocoding for facility addresses

### API & Scaling Optimisation
- [ ] Fix refresh logic to reduce API call frequency (currently too aggressive)
- [ ] Implement server-side caching strategy for scaling to thousands of users
- [ ] Review Supabase edge functions for batch processing efficiency
- [ ] Add request coalescing and smarter refresh scheduling based on user activity

### Real-Time Transit Integration
- [ ] Integrate [TfNSW GTFS Realtime Trip Updates API](https://opendata.transport.nsw.gov.au/data/dataset/public-transport-realtime-trip-update-v2)
- [ ] Show real-time train/metro arrivals for each Park&Ride facility
- [ ] Display service alerts and delays affecting nearby stations
- [ ] Add trip planning suggestions combining parking and transit

### Traffic & Navigation
- [ ] Add live traffic information from user location to selected facility
- [ ] Display traffic status indicators (light, moderate, heavy)
- [ ] Show traffic-aware ETA estimates
- [ ] Implement route alternatives based on current conditions

### Smart Parking Suggestions
- [ ] Build alternative parking recommendation engine
- [ ] Factor in vacancy rates, traffic conditions, and distance
- [ ] Consider historical patterns from Supabase insights
- [ ] Add "best time to arrive" suggestions based on trend data

### Live Activities & Widgets
- [ ] Implement Live Activities for tracking selected facility availability
- [ ] Add home screen widgets (small, medium, large)
- [ ] Create lock screen widgets for quick vacancy checks
- [ ] Support Dynamic Island for active navigation sessions

### Notifications
- [ ] Add push notification support for vacancy alerts
- [ ] Implement threshold-based notifications ("Alert when under X spaces")
- [ ] Add departure reminders based on traffic conditions
- [ ] Support notification scheduling for regular commute times

### Location Services
- [ ] Review and improve `LocationManager` implementation
- [ ] Add background location updates for proximity alerts
- [ ] Implement geofencing for automatic facility detection
- [ ] Add "Always Allow" location permission flow for background features

---

## Acknowledgments

- Transport for NSW for providing the Car Park API
- Data includes information from TfNSW Park&Ride facilities
- Built with Apple's SwiftUI, MapKit, and CoreLocation frameworks
