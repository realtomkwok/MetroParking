# Nearby Facilities Implementation Guide

## Overview

This document explains the hybrid approach for efficiently displaying nearby parking facilities using **precomputed distances stored in SwiftData** with automatic fallback to on-demand calculation.

## Design Decision: Hybrid Approach ✅

### Why Precompute?
1. **Distances Never Change**: Geographic distance between two fixed locations is constant
2. **Performance**: O(1) lookup vs O(n) calculation every view render
3. **Battery Efficiency**: Reduces repeated distance calculations
4. **Predictable Performance**: No lag when scrolling through facilities

### Why Keep Dynamic ETA Separate?
- Traffic conditions change constantly
- Live ETA requires real-time calculation
- Only calculate when user explicitly needs directions
- Separation of concerns: static geography vs dynamic traffic

## Architecture

### Data Model (ParkingFacility.swift)

```swift
// Stored in SwiftData
private var _nearbyFacilityIds: [String] = []
private var _nearbyFacilityDistances: [Double] = []
private var _nearbyComputedAt: Date?
```

**Storage Overhead**: ~10 facilities × (String + Double) ≈ 200-300 bytes per facility

For 100 parking facilities: ~20-30 KB total (negligible)

### Key Methods

#### 1. `computeNearbyFacilities(_:limit:)`
```swift
func computeNearbyFacilities(_ allFacilities: [ParkingFacility], limit: Int = 10)
```
- **When**: Called once during initial facility load
- **What**: Calculates distances to all other facilities and stores the nearest 10
- **Why**: One-time computation provides data for entire app lifecycle

#### 2. `getNearbyFacilityInfo(limit:)`
```swift
func getNearbyFacilityInfo(limit: Int = 5) -> [NearbyFacilityInfo]
```
- **When**: Called when displaying nearby facilities
- **What**: Returns precomputed data (O(1) array slice)
- **Why**: Fast lookup with no computation

#### 3. `invalidateNearbyCache()`
```swift
func invalidateNearbyCache()
```
- **When**: Called when facilities are added/removed (rare)
- **What**: Clears cached data to force recomputation
- **Why**: Maintains data consistency

### Manager Layer (FacilityManager.swift)

#### Batch Precomputation
```swift
func precomputeNearbyFacilities() async
```
- Automatically called after initial facility load
- Computes nearby facilities for ALL facilities at once
- Runs once per app install (or after data reset)

#### Cache Invalidation
```swift
func invalidateNearbyCache() async
```
- Call when facilities are added/removed
- Triggers recomputation on next access

### View Layer (FacilityDetailView.swift)

#### Smart Fallback Logic
```swift
private func getNearbyFacilities(to facility: ParkingFacility, limit: Int, context: ModelContext) -> [ParkingFacility]
```

**Flow**:
1. Check if precomputed data exists (`needsNearbyComputation`)
2. **If YES**: Compute on-demand and store for future use
3. **If NO**: Use precomputed data (fast path)
4. Fetch actual facility objects from SwiftData using stored IDs

This ensures:
- ✅ New facilities automatically get computed on first view
- ✅ Existing facilities use cached data
- ✅ No crashes if data isn't precomputed yet
- ✅ Gradual migration for existing installations

## Performance Characteristics

### Initial Load (One-time)
- **Time**: O(n²) where n = number of facilities
- **For 100 facilities**: ~1-2 seconds (acceptable one-time cost)
- **Runs**: Once per app install, in background

### View Rendering (Every time)
- **Time**: O(k) where k = limit (5 facilities)
- **Operations**: Array slice + 5 SwiftData fetches
- **Result**: < 1ms, imperceptible to users

### Storage
- **Per Facility**: 200-300 bytes
- **Total (100 facilities)**: 20-30 KB
- **Negligible** compared to typical app data

## When to Use Each Approach

### Use Precomputed (✅ Current Implementation)
- Static geographic distances
- Frequently accessed data
- Known set of facilities

### Calculate On-Demand
- Live traffic ETA (changes constantly)
- User-to-facility distance (user moves)
- One-time calculations

## Maintenance Scenarios

### Adding New Facilities
1. Insert new facility into SwiftData
2. Call `facilityManager.precomputeNearbyFacilities()`
   - This recomputes for ALL facilities including the new one

### Removing Facilities
1. Delete facility from SwiftData
2. Call `facilityManager.invalidateNearbyCache()`
3. Next access triggers recomputation

### Facility Location Changed (Rare)
1. Update latitude/longitude
2. Call `facility.invalidateNearbyCache()`
3. Call `facilityManager.precomputeNearbyFacilities()`

## Future Enhancements

### Option 1: Incremental Updates
Instead of recomputing all facilities when one is added:
```swift
func addFacility(_ newFacility: ParkingFacility, to context: ModelContext) {
    // Compute neighbors for the new facility only
    let allFacilities = try? context.fetch(FetchDescriptor<ParkingFacility>())
    newFacility.computeNearbyFacilities(allFacilities)
    
    // Update existing facilities that might now have this as a neighbor
    // (Only if new facility is closer than their current 10th neighbor)
    updateExistingNeighbors(newFacility, allFacilities)
}
```

### Option 2: Background Computation
Use Swift Concurrency to compute in background:
```swift
Task.detached(priority: .background) {
    await facilityManager.precomputeNearbyFacilities()
}
```

### Option 3: Partial Cache Warming
Only compute for favorite facilities:
```swift
func precomputeForFavorites() async {
    let favorites = try? context.fetch(
        FetchDescriptor<ParkingFacility>(
            predicate: #Predicate { $0.isFavourite == true }
        )
    )
    // Compute only for favorites
}
```

## Testing Checklist

- [ ] Fresh install: Verify precomputation runs automatically
- [ ] Existing install: Verify fallback computation works
- [ ] Add facility: Verify cache invalidation and recomputation
- [ ] Remove facility: Verify cache invalidation
- [ ] View performance: Verify < 100ms load time for nearby section
- [ ] Memory usage: Verify < 50 KB overhead
- [ ] Data persistence: Verify precomputed data survives app restart

## Summary

**Decision**: ✅ **Store precomputed distances in SwiftData**

**Rationale**:
1. Geographic distances are static
2. Massive performance improvement (O(1) vs O(n))
3. Negligible storage overhead (~20-30 KB)
4. Automatic fallback for migration
5. Separation from dynamic traffic data

**Trade-off**: Minor complexity in cache invalidation (easily managed)

This hybrid approach gives you the best of both worlds:
- ⚡ Lightning-fast views
- 💾 Minimal storage
- 🔄 Automatic fallback
- 🎯 Live traffic when needed
