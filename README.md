# MetroParking

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

2. **Configure API credentials**
   ```bash
   cp Config.xcconfig.template Config.xcconfig
   ```

   Edit `Config.xcconfig` and add your credentials:
   ```
   TFNSW_API_KEY = your_api_key_here
   DEVELOPMENT_TEAM = your_team_id_here
   ```

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

TBD.

## Acknowledgments

- Transport for NSW for providing the Car Park API
- Data includes information from TfNSW Park&Ride facilities
- Built with Apple's SwiftUI, MapKit, and CoreLocation frameworks