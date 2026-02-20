# MetroParking Swift Testing Plan

## Context

MetroParking currently has **zero meaningful tests** - only Xcode stub templates exist. As the app approaches production (v0.4.0 beta), a comprehensive test suite is needed to prevent regressions. The app has significant business logic in models, services, managers, and utilities that can be tested without a simulator using Swift Testing.

The codebase uses singletons and `@Model` (SwiftData) extensively, so the plan introduces lightweight test helpers and protocol-based abstractions where needed, but **only** where it enables testability - not as a refactor for its own sake.

---

## Test Architecture

### Framework: Swift Testing (`@Test`, `#expect`, `@Suite`)

### Organisation: Tags for filtering, `@Suite` structs per logical area

### Tag Definitions

```swift
extension Tag {
    @Tag static var model: Self        // Data model logic
    @Tag static var api: Self          // API/network layer
    @Tag static var sorting: Self      // Sort & filter
    @Tag static var widget: Self       // Widget-related
    @Tag static var configuration: Self // Config & constants
    @Tag static var formatting: Self   // Time/distance formatting
    @Tag static var insights: Self     // Analytics models
    @Tag static var integration: Self  // Cross-component tests
}
```

### File Structure

```
MetroParkingTests/
├── MetroParkingTests.swift          // (existing - replace stub)
├── Tags.swift                       // Tag definitions
├── Helpers/
│   └── TestHelpers.swift            // Factory methods for test data
│
├── Models/
│   ├── ParkingFacilityTests.swift   // Core model tests
│   ├── ParkingAPIModelsTests.swift  // DTO & Codable tests
│   ├── ParkingInsightModelTests.swift // Insight model tests
│   └── StaticFacilityInfoTests.swift // Static data integrity
│
├── Utils/
│   ├── SortAndFilterTests.swift     // Sort, filter, search
│   ├── DistanceHelperTests.swift    // Distance calculations
│   ├── RefreshConfigTests.swift     // Configuration constants
│   ├── WidgetBudgetTrackerTests.swift // Budget logic
│   └── FormatTimeHelperTests.swift  // Time formatting
│
├── Services/
│   └── ParkingAPIServiceTests.swift // Decoding & URL building
│
└── Integration/
    └── RefreshDecisionTests.swift   // Cross-cutting refresh logic
```

---

## Phase 1: Test Helpers (Foundation)

### File: `MetroParkingTests/Helpers/TestHelpers.swift`

Factory methods for creating test `ParkingFacility` instances without SwiftData context. Since `ParkingFacility` is a `@Model` class, we can construct instances directly - SwiftData models work as plain objects outside a `ModelContext`.

**What to build:**

- `TestFacility.make(...)` - factory with sensible defaults for all parameters
- `TestFacility.makeWithOccupancy(occupied:total:)` - preset occupancy states
- `TestFacility.makeFavourite(...)` - pre-pinned facility
- `TestFacility.makeList(count:)` - bulk creation for sort/filter tests

**Key files:** `MetroParking/Models/ParkingFacility.swift`

---

## Phase 2: Model Tests (Highest Priority)

### 2A: `ParkingFacilityTests.swift`

Tests the core model's business logic. **This is the most critical file** - ParkingFacility has extensive computed properties and state transitions.

**@Suite "Display Name Parsing"** `.tags(.model)`

| Test                                                         | What it verifies                                             |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| `parsesStandardName`                                         | `"Park&Ride - Gordon Henry St (north)"` → title: `"Gordon Henry St"`, subtitle: `"North"` |
| `parsesNameWithoutSubtitle`                                  | `"Park&Ride - Kiama"` → title: `"Kiama"`, subtitle: `""`     |
| `parsesNameWithMultipleParens`                               | Edge case with nested parentheses                            |
| `removesPrefix`                                              | `"Park&Ride - "` prefix is stripped                          |
| Parameterized test with several real facility names from `StaticFacilityInfo.swift` |                                                              |

**@Suite "Availability Status"** `.tags(.model)`

| Test                                                         | What it verifies                               |
| ------------------------------------------------------------ | ---------------------------------------------- |
| `noDataWhenNeverUpdated`                                     | `_cacheTimestamp == .distantPast` → `.noData`  |
| `fullWhenZeroAvailable`                                      | `available == 0` → `.full`                     |
| `almostFullWhenUnder10Percent`                               | `available < totalSpaces / 10` → `.almostFull` |
| `availableWhenAbove10Percent`                                | `available >= totalSpaces / 10` → `.available` |
| Parameterized: boundary values (e.g., 100 total: 0, 9, 10, 50 available) |                                                |

**@Suite "Vacancy Info"** `.tags(.model)`

| Test                                | What it verifies                                |
| ----------------------------------- | ----------------------------------------------- |
| `occupancyRatioClampedBetween0And1` | Never exceeds [0, 1] range                      |
| `occupancyWithZeroTotal`            | Returns 0.0, no division by zero                |
| `availableNeverNegative`            | `max(0, total - occupied)` works                |
| `cacheValidityForeground`           | Fresh within 5min (watched) / 15min (unwatched) |
| `cacheValidityBackground`           | Fresh within 15min (watched) / 2hr (unwatched)  |

**@Suite "Refresh Tier"** `.tags(.model)`

| Test                 | What it verifies                         |
| -------------------- | ---------------------------------------- |
| `favouriteIsWatched` | `isFavourite = true` → `.watched`        |
| `defaultIsUnwatched` | Non-favourite, non-widget → `.unwatched` |

**@Suite "Refresh Decisions"** `.tags(.model)`

| Test                                | What it verifies                          |
| ----------------------------------- | ----------------------------------------- |
| `shouldRefreshWhenCacheExpired`     | Expired cache → `shouldRefresh() == true` |
| `shouldNotRefreshWhenCacheFresh`    | Fresh cache → `shouldRefresh() == false`  |
| `forcedRefreshOnlyAppliesToWatched` | Forced flag ignored for unwatched tier    |

**@Suite "Failure Tracking"** `.tags(.model)`

| Test                                 | What it verifies                                  |
| ------------------------------------ | ------------------------------------------------- |
| `markRefreshFailedIncrementsCounter` | Failure count goes up                             |
| `cacheInvalidatedAfter3Failures`     | `_cacheTimestamp` reset to `.distantPast` after 3 |
| `updateOccupancyResetsFailures`      | Successful update clears failure count            |

**@Suite "Route Info"** `.tags(.model)`

| Test                                  | What it verifies                     |
| ------------------------------------- | ------------------------------------ |
| `routeValidWithin1Hour`               | `RouteInfo.isValid` true when recent |
| `routeInvalidAfter1Hour`              | `RouteInfo.isValid` false when old   |
| `clearStaleRoutingData`               | Stale routes get cleared             |
| `sortableDistanceInfinityWhenNoRoute` | `Double.infinity` when no route      |

**@Suite "Data Staleness"** `.tags(.model)`

| Test                         | What it verifies                                    |
| ---------------------------- | --------------------------------------------------- |
| `freshDataHasFullOpacity`    | `DataStaleness.fresh.displayOpacity == 1.0`         |
| `staleDataHasReducedOpacity` | `DataStaleness.stale.displayOpacity == 0.6`         |
| `staleShowsRefreshIndicator` | `DataStaleness.stale.showsRefreshIndicator == true` |

**Key file:** `MetroParking/Models/ParkingFacility.swift`

---

### 2B: `ParkingAPIModelsTests.swift`

Tests JSON decoding and domain model conversion.

**@Suite "API Model Decoding"** `.tags(.api)`

| Test                                 | What it verifies                      |
| ------------------------------------ | ------------------------------------- |
| `decodesValidJSON`                   | Full API response decodes correctly   |
| `decodesWithOptionalOccupancyFields` | Nil `loop`, `monthlies`, etc. handled |
| `decodesZonesCorrectly`              | Nested zone array decodes             |
| `codingKeysMapCorrectly`             | `facility_id` → `facilityId`, etc.    |

**@Suite "Domain Model Conversion"** `.tags(.api, .model)`

| Test                                      | What it verifies                  |
| ----------------------------------------- | --------------------------------- |
| `toDomainCreatesValidFacility`            | Valid API model → ParkingFacility |
| `toDomainReturnsNilForInvalidLat`         | Non-numeric latitude → nil        |
| `toDomainReturnsNilForInvalidLng`         | Non-numeric longitude → nil       |
| `toDomainReturnsNilForInvalidSpaces`      | Non-numeric spots → nil           |
| Parameterized: invalid field combinations |                                   |

**@Suite "API Decode Fallback"** `.tags(.api)`

| Test                        | What it verifies                         |
| --------------------------- | ---------------------------------------- |
| `decodesDirectObjectFormat` | `ParkingApiModel` decoded directly       |
| `decodesDictionaryFormat`   | `{facilityId: ParkingApiModel}` decoded  |
| `throwsForEmptyDictionary`  | No data → `APIError.noDataForFacility`   |
| `throwsForInvalidJSON`      | Garbage data → `APIError.decodingFailed` |

**Key files:** `MetroParking/Models/ParkingAPIModels.swift`, `MetroParking/Services/ParkingAPIService.swift`

---

### 2C: `ParkingInsightModelTests.swift`

**@Suite "Hourly Pattern"** `.tags(.insights)`

| Test                            | What it verifies                                         |
| ------------------------------- | -------------------------------------------------------- |
| Parameterized `occupancyStatus` | 0.0→"Low", 0.3→"Moderate", 0.7→"Almost Full", 0.9→"Full" |
| Parameterized `dayName`         | 1→"Sun", 2→"Mon", ..., 7→"Sat"                           |
| `dayNameEmptyForZero`           | dayOfWeek=0 → ""                                         |

**@Suite "Facility Insights"** `.tags(.insights)`

| Test                            | What it verifies             |
| ------------------------------- | ---------------------------- |
| `peakHoursTextFormatting`       | `[8, 17]` → `"08:00, 17:00"` |
| `bestTimeTextFormatting`        | `[6, 10]` → `"06:00, 10:00"` |
| `emptyArraysProduceEmptyString` | `[]` → `""`                  |

**Key file:** `MetroParking/Models/ParkingInsightModel.swift`

---

### 2D: `StaticFacilityInfoTests.swift`

**@Suite "Static Data Integrity"** `.tags(.model)`

| Test                                   | What it verifies          |
| -------------------------------------- | ------------------------- |
| `hasExpected37Facilities`              | Count check               |
| `allFacilitiesHaveUniqueIds`           | No duplicate `facilityId` |
| `allFacilitiesHaveValidCoordinates`    | Lat/lng in NSW bounds     |
| `allFacilitiesHavePositiveTotalSpaces` | `totalSpaces > 0`         |
| `allFacilitiesHaveNonEmptyNames`       | No blank names            |

**Key file:** `MetroParking/Models/StaticFacilityInfo.swift`

---

## Phase 3: Utility Tests

### 3A: `SortAndFilterTests.swift`

**@Suite "Name Sorting"** `.tags(.sorting)`

| Test                      | What it verifies            |
| ------------------------- | --------------------------- |
| `sortsByTitleAscending`   | A before Z                  |
| `sortsByTitleDescending`  | Z before A                  |
| `stableSortOnEqualTitles` | Subtitle used as tiebreaker |

**@Suite "Distance Sorting"** `.tags(.sorting)`

| Test                                    | What it verifies                      |
| --------------------------------------- | ------------------------------------- |
| `nilDistanceSortedToEnd`                | Facilities without route data go last |
| `nilDistanceStaysLastRegardlessOfOrder` | Even descending, nil stays at end     |
| `sortsByDistanceAscending`              | Nearest first                         |

**@Suite "Filtering"** `.tags(.sorting)`

| Test                                   | What it verifies           |
| -------------------------------------- | -------------------------- |
| `pinnedFilterMatchesFavourites`        | Only isFavourite=true      |
| `availableFilterExcludesFullAndNoData` | >0 spaces AND not noData   |
| `nilFilterReturnsAll`                  | No filter = all facilities |

**@Suite "Search"** `.tags(.sorting)`

| Test                    | What it verifies           |
| ----------------------- | -------------------------- |
| `searchByTitle`         | Matches facility title     |
| `searchBySubtitle`      | Matches facility subtitle  |
| `searchBySuburb`        | Matches suburb             |
| `caseInsensitiveSearch` | "gordon" matches "Gordon"  |
| `emptySearchReturnsAll` | No search = all facilities |

**@Suite "Combined Pipeline"** `.tags(.sorting)`

| Test                       | What it verifies              |
| -------------------------- | ----------------------------- |
| `filterThenSortThenSearch` | Full pipeline works correctly |
| `emptyResultsHandled`      | No crash on empty arrays      |

**Key file:** `MetroParking/Utils/SortAndFilterHelper.swift`

---

### 3B: `DistanceHelperTests.swift`

**@Suite "Distance Calculation"** `.tags(.model)`

| Test                        | What it verifies      |
| --------------------------- | --------------------- |
| `distanceBetweenSamePoint`  | 0.0 km                |
| `distanceSydneyCBDToGordon` | ~15 km (sanity check) |
| `distanceIsSymmetric`       | A→B == B→A            |

**@Suite "Cache Behaviour"** `.tags(.model)`

| Test                                | What it verifies                |
| ----------------------------------- | ------------------------------- |
| `cacheHitWithinThreshold`           | Same result for <100m movement  |
| `cacheInvalidatedOnSignificantMove` | Cache cleared on >100m movement |
| `clearDistanceCacheWorks`           | Manual clear empties cache      |

**Key file:** `MetroParking/Utils/DistanceHelper.swift`

---

### 3C: `RefreshConfigTests.swift`

**@Suite "Configuration Constants"** `.tags(.configuration)`

| Test                                         | What it verifies                  |
| -------------------------------------------- | --------------------------------- |
| `foregroundWatchedCacheShorterThanUnwatched` | 300 < 900                         |
| `backgroundCacheLongerThanForeground`        | Background intervals ≥ foreground |
| `widgetBudgetIs60`                           | Constant check                    |
| `apiMinCallIntervalIs400ms`                  | Rate limit constant               |
| `quickRefreshTimeoutIs25s`                   | Timeout constant                  |

**@Suite "Background Task Interval"** `.tags(.configuration)`

| Test                                 | What it verifies            |
| ------------------------------------ | --------------------------- |
| `peakHoursReturnsShorterInterval`    | 15 min during commute hours |
| `officeHoursReturnsModerateInterval` | 20 min during work hours    |
| `offPeakReturnsLongerInterval`       | 30 min evenings/weekends    |

Note: `BackgroundTaskInterval.current()` uses `Date()` internally. For deterministic testing, we'll test the constant values directly and verify the ranges are reasonable. Full time-of-day testing would require a `Clock` abstraction (future enhancement).

**@Suite "Refresh Tier"** `.tags(.configuration)`

| Test                          | What it verifies |
| ----------------------------- | ---------------- |
| `watchedForegroundValidity`   | 300s             |
| `unwatchedForegroundValidity` | 900s             |
| `watchedBackgroundValidity`   | 900s             |
| `unwatchedBackgroundValidity` | 7200s            |

**@Suite "App State"** `.tags(.configuration)`

| Test                        | What it verifies |
| --------------------------- | ---------------- |
| `activeRefreshInterval`     | 300s             |
| `backgroundRefreshInterval` | 1800s (offPeak)  |

**Key file:** `MetroParking/Utils/RefreshConfiguration.swift`

---

### 3D: `FormatTimeHelperTests.swift`

**@Suite "Travel Time Formatting"** `.tags(.formatting)`

| Test                        | What it verifies                  |
| --------------------------- | --------------------------------- |
| `formatsSecondsUnder60`     | < 1 min handled                   |
| `formatsMinutes`            | e.g., 300s → "5 min"              |
| `formatsHoursAndMinutes`    | e.g., 5400s → "1h 30m"            |
| `compactFormat`             | Positional format                 |
| `adaptiveFormattingByWidth` | <60 → compact, <100 → abbreviated |

**@Suite "Hour Formatting"** `.tags(.formatting)`

| Test                     | What it verifies            |
| ------------------------ | --------------------------- |
| Parameterized hours 0-23 | All produce valid strings   |
| `formatHour9`            | "9 AM" or locale equivalent |

**Key file:** `MetroParking/Utils/FormatTimeHelper.swift`

---

### 3E: `WidgetBudgetTrackerTests.swift`

Since `WidgetBudgetTracker` uses `UserDefaults(suiteName:)` and `WidgetCenter.shared`, direct testing of the internal logic (canReload, budget math) requires either:

1. Extracting pure logic into testable functions, OR
2. Testing the budget calculation logic indirectly

**@Suite "Budget Calculation Logic"** `.tags(.widget)`

| Test                            | What it verifies                |
| ------------------------------- | ------------------------------- |
| `budgetStartsAt60`              | Fresh state = 60 remaining      |
| `budgetDecreasesAfterReload`    | Reload recording reduces budget |
| `24HourWindowFiltersOldReloads` | Reloads >24h ago don't count    |
| `throttleRejects15SecondWindow` | Back-to-back reloads rejected   |

Note: These tests will need access to the shared UserDefaults. If the App Group isn't available in test environment, we'll test the pure calculation logic separately.

**Key file:** `MetroParking/Utils/WidgetBudgetTracker.swift`

---

## Phase 4: Service Tests

### 4A: `ParkingAPIServiceTests.swift`

Tests decoding logic and URL construction. Network calls are **not** tested (no mocked URLSession needed for phase 1).

**@Suite "URL Construction"** `.tags(.api)`

| Test                         | What it verifies           |
| ---------------------------- | -------------------------- |
| `buildURLWithValidId`        | Produces valid URL         |
| `buildURLIncludesFacilityId` | URL contains `?facility=6` |

**@Suite "Response Decoding"** `.tags(.api)`

| Test                      | What it verifies             |
| ------------------------- | ---------------------------- |
| `decodesDirectFormat`     | Single object JSON           |
| `decodesDictionaryFormat` | Keyed dictionary JSON        |
| `throwsOnEmptyDictionary` | `APIError.noDataForFacility` |
| `throwsOnInvalidData`     | `APIError.decodingFailed`    |

Uses `ParkingAPIService.shared.decode(_:facilityId:)` directly (it's internal scope).

**@Suite "API Error Types"** `.tags(.api)`

| Test                        | What it verifies                   |
| --------------------------- | ---------------------------------- |
| `errorDescriptionsNonEmpty` | All cases have descriptions        |
| Parameterized error cases   | Each case returns expected message |

**Key file:** `MetroParking/Services/ParkingAPIService.swift`

---

## Phase 5: Integration Tests

### 5A: `RefreshDecisionTests.swift`

Cross-cutting tests that verify the interaction between `ParkingFacility.shouldRefresh()`, `RefreshTier`, and `AppState`.

**@Suite "Refresh Decision Matrix"** `.tags(.integration)`

| Test                                                        | What it verifies                      |
| ----------------------------------------------------------- | ------------------------------------- |
| Parameterized: (tier × appState × cacheAge) → shouldRefresh | Full matrix of refresh decisions      |
| `watchedFacilityRefreshedMoreOften`                         | Watched facilities have shorter cache |
| `backgroundModeLenientOnCache`                              | Background tolerates older cache      |
| `forcedRefreshOnlyAffectsWatched`                           | Unwatched ignores forced flag         |

**Key files:** `ParkingFacility.swift`, `RefreshConfiguration.swift`

---

## Implementation Order

| Step      | File(s)                            | Priority   | Est. Tests     |
| --------- | ---------------------------------- | ---------- | -------------- |
| 1         | `Tags.swift` + `TestHelpers.swift` | Foundation | 0 (helpers)    |
| 2         | `ParkingFacilityTests.swift`       | Critical   | ~25            |
| 3         | `ParkingAPIModelsTests.swift`      | Critical   | ~12            |
| 4         | `SortAndFilterTests.swift`         | High       | ~15            |
| 5         | `RefreshConfigTests.swift`         | High       | ~12            |
| 6         | `StaticFacilityInfoTests.swift`    | High       | ~5             |
| 7         | `ParkingInsightModelTests.swift`   | Medium     | ~8             |
| 8         | `DistanceHelperTests.swift`        | Medium     | ~6             |
| 9         | `FormatTimeHelperTests.swift`      | Medium     | ~8             |
| 10        | `ParkingAPIServiceTests.swift`     | Medium     | ~8             |
| 11        | `WidgetBudgetTrackerTests.swift`   | Medium     | ~4             |
| 12        | `RefreshDecisionTests.swift`       | Medium     | ~6             |
| **Total** |                                    |            | **~109 tests** |

---

## Verification

After implementation:

1. Run `Cmd+U` in Xcode to execute all tests
2. All tests should pass with 0 failures
3. Verify no tests require simulator launch (pure logic tests)
4. Verify tests run in < 5 seconds total
5. Check Test Navigator shows proper tag-based grouping

---

## Future Enhancements (Not in Scope)

- **Protocol-based mocking** for `URLSession` to test live API calls
- **Clock abstraction** for deterministic time-of-day tests
- **SwiftData in-memory container** tests for `FacilityManager` operations
- **UI tests** for critical user flows (onboarding, facility detail, widget config)
- **Snapshot tests** for widget views