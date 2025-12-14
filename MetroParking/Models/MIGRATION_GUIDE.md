# ParkingFacility Refactoring Migration Guide

## Overview
The `ParkingFacility` model has been refactored to eliminate redundancies and group related properties into logical structures. This provides a cleaner API with single sources of truth.

## Key Changes

### 1. ✅ Vacancy/Occupancy (SINGLE SOURCE OF TRUTH)

**Before:**
```swift
facility.currentAvailable        // Int
facility.currentOccupied         // Int
facility.displayAvailable        // String
facility.occupancy               // Double
facility.vacancy?.available      // Int?
facility.vacancy?.occupied       // Int?
facility.vacancy?.occupancy      // Double?
facility.isOccupancyCacheValid   // Bool
facility.shouldShowCachedData    // Bool
```

**After:**
```swift
facility.vacancy.available       // Int - always available, never optional
facility.vacancy.occupied        // Int
facility.vacancy.occupancy       // Double
facility.vacancy.displayText     // String (replaces displayAvailable)
facility.vacancy.isCacheValid    // Bool
facility.vacancy.shouldShowData  // Bool
```

**Migration:**
- Replace `currentAvailable` → `vacancy.available`
- Replace `currentOccupied` → `vacancy.occupied`
- Replace `displayAvailable` → `vacancy.displayText`
- Replace `occupancy` → `vacancy.occupancy`
- Replace `isOccupancyCacheValid` → `vacancy.isCacheValid`
- Replace `shouldShowCachedData` → `vacancy.shouldShowData`
- Remove optional unwrapping - `vacancy` is now always available, never nil

### 2. 📍 Location Properties (GROUPED)

**Before:**
```swift
facility.latitude     // Double
facility.longitude    // Double
facility.coordinate   // CLLocationCoordinate2D
facility.suburb       // String
facility.address      // String
```

**After:**
```swift
facility.location.latitude    // Double
facility.location.longitude   // Double
facility.location.coordinate  // CLLocationCoordinate2D
facility.location.suburb      // String
facility.location.address     // String

// Convenience accessors still available:
facility.latitude    // Double
facility.longitude   // Double
facility.coordinate  // CLLocationCoordinate2D
facility.suburb      // String
facility.address     // String
```

**Migration:**
- Prefer `facility.location.property` for grouped access
- Old accessors still work for backward compatibility
- Use `facility.location` when passing all location data

### 3. 🗺️ Route Information (GROUPED)

**Before:**
```swift
facility.lastCalculatedDistance    // CLLocationDistance?
facility.lastCalculatedTravelTime  // TimeInterval?
facility.routingDataAge            // Date?
facility.hasValidRoutingData       // Bool
```

**After:**
```swift
facility.route?.distance          // CLLocationDistance
facility.route?.travelTime        // TimeInterval
facility.route?.calculatedAt      // Date
facility.route?.isValid           // Bool
facility.route?.formattedDistance // String (NEW!)
facility.route?.formattedTravelTime // String (NEW!)
```

**Migration:**
- Replace `lastCalculatedDistance` → `route?.distance`
- Replace `lastCalculatedTravelTime` → `route?.travelTime`
- Replace `routingDataAge` → `route?.calculatedAt`
- Replace `hasValidRoutingData` → `route?.isValid ?? false`
- Use new formatted properties for display

### 4. 🔄 Refresh Status (GROUPED)

**Before:**
```swift
facility.lastRefreshed           // Date
facility.lastUpdated             // Date
facility.retrievalFailures       // Int
facility.lastFailureDate         // Date?
facility.timeSinceLastRefresh    // TimeInterval
```

**After:**
```swift
facility.refreshStatus.lastRefreshed       // Date
facility.refreshStatus.lastUpdated         // Date
facility.refreshStatus.failures            // Int
facility.refreshStatus.lastFailureDate     // Date?
facility.refreshStatus.timeSinceRefresh    // TimeInterval
facility.refreshStatus.hasRecentFailures   // Bool (NEW!)
```

**Migration:**
- Replace `lastRefreshed` → `refreshStatus.lastRefreshed`
- Replace `lastUpdated` → `refreshStatus.lastUpdated`
- Replace `retrievalFailures` → `refreshStatus.failures`
- Replace `lastFailureDate` → `refreshStatus.lastFailureDate`
- Replace `timeSinceLastRefresh` → `refreshStatus.timeSinceRefresh`

### 5. 💾 Internal Storage (RENAMED)

Properties prefixed with `_` are now internal storage. Don't access these directly:

- `_latitude`, `_longitude`, `_suburb`, `_address` → use `location.*`
- `_cachedOccupied`, `_cacheTimestamp` → use `vacancy.*`
- `_lastRefreshed`, `_lastUpdated`, etc. → use `refreshStatus.*`
- `_routeDistance`, `_routeTravelTime`, `_routeTimestamp` → use `route?.*`

## Common Migration Patterns

### Displaying Vacancy
```swift
// Before:
Text(facility.displayAvailable)
if facility.currentAvailable > 0 {
    Text("\(facility.currentAvailable) spots")
}

// After:
Text(facility.vacancy.displayText)
if facility.vacancy.available > 0 {
    Text("\(facility.vacancy.available) spots")
}
```

### Checking Route Data
```swift
// Before:
if facility.hasValidRoutingData,
   let distance = facility.lastCalculatedDistance {
    Text("Distance: \(distance)")
}

// After:
if let route = facility.route, route.isValid {
    Text("Distance: \(route.formattedDistance)")
}
```

### Location Display
```swift
// Before:
VStack {
    Text(facility.address)
    Text(facility.suburb)
}

// After:
VStack {
    Text(facility.location.address)
    Text(facility.location.suburb)
}
// Or using convenience accessors:
VStack {
    Text(facility.address)
    Text(facility.suburb)
}
```

### Checking Cache Validity
```swift
// Before:
if facility.isOccupancyCacheValid {
    showData()
}

// After:
if facility.vacancy.isCacheValid {
    showData()
}
```

## SwiftData Compatibility and Fallback

All changes maintain SwiftData compatibility:
- Internal `_` properties are persisted
- Public computed properties provide clean access
- Nested structs are value types (not persisted)
- Relationships unchanged

## Search and Replace

1. `\.currentAvailable` → `.vacancy.available`
2. `\.currentOccupied` → `.vacancy.occupied`
3. `\.displayAvailable` → `.vacancy.displayText`
4. `\.isOccupancyCacheValid` → `.vacancy.isCacheValid`
5. `\.shouldShowCachedData` → `.vacancy.shouldShowData`
6. `\.lastCalculatedDistance` → `.route?.distance`
7. `\.lastCalculatedTravelTime` → `.route?.travelTime`
8. `\.hasValidRoutingData` → `(.route?.isValid ?? false)`
