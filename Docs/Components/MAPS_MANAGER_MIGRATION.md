# MapsManager Migration Guide

This guide shows how to update existing code to use the new centralized `MapsManager`.

## Overview

`MapsManager` consolidates all MapKit operations into a single, well-tested manager that:
- ✅ Handles iOS version compatibility automatically
- ✅ Uses modern APIs (PlaceDescriptor, GeoToolbox) when available
- ✅ Provides fallbacks for older iOS versions
- ✅ Centralizes MapItem creation, directions, Look Around, and Apple Maps integration
- ✅ Includes proper error handling and logging

## Migration Examples

### 1. MapItem Creation

#### Before:
```swift
// ParkingFacility.swift
var mapItem: MKMapItem {
    let placeMark = MKPlacemark(coordinate: coordinate)
    let item = MKMapItem(placemark: placeMark)
    item.name = displayName.title
    return item
}
```

#### After:
```swift
// ParkingFacility.swift
var mapItem: MKMapItem {
    return MapsManager.shared.createMapItem(for: self)
}
```

### 2. Look Around Scene Loading

#### Before:
```swift
// LookAroundManager.swift
@Observable
class LookAroundManager {
    var lookAroundScene: MKLookAroundScene?
    var coordinate: CLLocationCoordinate2D?

    func loadPreview() async {
        Task {
            if let coordinate = coordinate {
                let request = MKLookAroundSceneRequest(coordinate: coordinate)
                do {
                    lookAroundScene = try await request.scene
                } catch (let error) {
                    Logger.maps.error("\(error.localizedDescription)")
                }
            }
        }
    }
}
```

#### After:
```swift
// In your view or view model
let mapsManager = MapsManager.shared

// Load Look Around for a facility
await mapsManager.loadLookAroundScene(for: facility)

// Access the scene
if let scene = mapsManager.lookAroundScene {
    // Use the scene
}

// Check loading state
if mapsManager.isLoadingLookAround {
    // Show loading indicator
}
```

### 3. Opening Apple Maps

#### Before:
```swift
func openInMaps(for location: CLLocationCoordinate2D) {
    let placemark = MKPlacemark(coordinate: location)
    let mapItem = MKMapItem(placemark: placemark)
    mapItem.openInMaps(launchOptions: [...])
}
```

#### After:
```swift
// Open facility location in Maps
MapsManager.shared.openInMaps(facility)

// Or open with directions
MapsManager.shared.openInMapsWithDirections(facility, transportType: .automobile)
```

### 4. ETA Calculation

#### Before (ETAManager.swift):
```swift
func calculateETA(from userLocation: CLLocationCoordinate2D, to facility: ParkingFacility) async {
    let sourcePlacemark = MKPlacemark(coordinate: userLocation)
    let source = MKMapItem(placemark: sourcePlacemark)
    let destination = facility.mapItem
    
    let request = MKDirections.Request()
    request.source = source
    request.destination = destination
    request.transportType = .automobile
    
    let directions = MKDirections(request: request)
    let response = try await directions.calculateETA()
    // ...
}
```

#### After:
```swift
// ETAManager can now use MapsManager for consistency
func calculateETA(from userLocation: CLLocationCoordinate2D, to facility: ParkingFacility) async {
    do {
        let mapItem = MapsManager.shared.createMapItem(for: facility)
        let etaResponse = try await MapsManager.shared.calculateETA(
            from: userLocation,
            to: mapItem,
            transportType: .automobile
        )
        
        let travelTime = etaResponse.expectedTravelTime
        let distance = etaResponse.distance
        // Cache the result
        facility.updateRoutingData(distance: distance, travelTime: travelTime)
    } catch {
        Logger.maps.error("ETA calculation failed: \(error)")
    }
}
```

### 5. Full Directions (Not Just ETA)

#### New Capability:
```swift
// Get complete route with polylines
do {
    let mapItem = MapsManager.shared.createMapItem(for: facility)
    let response = try await MapsManager.shared.calculateDirections(
        from: userLocation,
        to: mapItem,
        transportType: .automobile,
        requestAlternates: true
    )
    
    // Access routes
    for route in response.routes {
        print("Route: \(route.distance)m, \(route.expectedTravelTime)s")
        // Draw route.polyline on map
    }
} catch {
    print("Directions unavailable")
}
```

### 6. Reverse Geocoding

#### New Capability:
```swift
// Get formatted address from coordinate
if let address = await MapsManager.shared.getFormattedAddress(for: facility.coordinate) {
    print("Address: \(address)")
}

// Or get full placemark details
do {
    let placemarks = try await MapsManager.shared.reverseGeocode(coordinate: facility.coordinate)
    if let placemark = placemarks.first {
        print("City: \(placemark.locality ?? "Unknown")")
        print("State: \(placemark.administrativeArea ?? "Unknown")")
    }
} catch {
    print("Geocoding failed")
}
```

## Using in SwiftUI Views

### Example: Facility Detail View with Look Around

```swift
struct FacilityDetailView: View {
    let facility: ParkingFacility
    @State private var mapsManager = MapsManager.shared
    
    var body: some View {
        VStack {
            // Look Around Preview
            if let scene = mapsManager.lookAroundScene {
                LookAroundPreview(initialScene: scene)
                    .frame(height: 200)
            } else if mapsManager.isLoadingLookAround {
                ProgressView()
                    .frame(height: 200)
            } else if let error = mapsManager.lookAroundError {
                Text(error)
                    .foregroundStyle(.secondary)
            }
            
            // Actions
            Button("Open in Maps") {
                mapsManager.openInMaps(facility)
            }
            
            Button("Get Directions") {
                mapsManager.openInMapsWithDirections(facility)
            }
        }
        .task {
            await mapsManager.loadLookAroundScene(for: facility)
        }
        .onDisappear {
            mapsManager.cancelLookAround(for: facility.facilityId)
        }
    }
}
```

## Benefits of Using MapsManager

### 1. **Automatic Version Handling**
The manager automatically uses the best available API for the iOS version:
- iOS 18.4+: Uses `PlaceDescriptor` with GeoToolbox (when available)
- Older versions: Falls back to `MKPlacemark`

### 2. **Centralized Logic**
All MapKit operations in one place:
- MapItem creation
- Directions and ETA
- Look Around scenes
- Apple Maps integration
- Reverse geocoding

### 3. **Better Error Handling**
Consistent error types and logging across all map operations.

### 4. **Observable State**
The manager is `@Observable`, making it perfect for SwiftUI:
```swift
@State private var mapsManager = MapsManager.shared

// Automatically updates UI when state changes
if mapsManager.isLoadingLookAround {
    ProgressView()
}
```

### 5. **Task Management**
Proper cancellation and cleanup of async operations:
```swift
.onDisappear {
    mapsManager.cancelLookAround(for: facility.facilityId)
}
```

## Next Steps

### Recommended Refactoring Order:

1. ✅ Update `ParkingFacility.mapItem` (Already done!)
2. ⏭️ Update `ETAManager` to use `MapsManager` for consistency
3. ⏭️ Replace `LookAroundManager` with `MapsManager`
4. ⏭️ Update any views using `openInMaps` helper functions
5. ⏭️ Add route visualization using full directions API
6. ⏭️ Consider adding reverse geocoding for better address display

### Optional Enhancements:

- Add route polyline visualization on map
- Implement alternate routes UI
- Add transit directions support
- Cache Look Around scenes for frequently viewed facilities
- Add batch ETA calculations for list views

## Testing

When testing with the new manager, you can:

1. **Mock for unit tests:**
```swift
// Create a test double for MapsManager
class MockMapsManager: MapsManager {
    override func calculateETA(...) async throws -> MKDirections.ETAResponse {
        // Return mock response
    }
}
```

2. **Test version compatibility:**
```swift
// Ensure fallbacks work on older iOS versions
// Run on iOS 17 simulator to verify MKPlacemark fallback
```

3. **Test error handling:**
```swift
// Verify graceful failure when Look Around unavailable
// Test offline scenarios for directions/ETA
```
