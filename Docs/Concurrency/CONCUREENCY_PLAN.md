# Swift 6 Migration Plan for MetroParking

## Context

The MetroParking codebase is currently on **Swift 5.0** with `SWIFT_APPROACHABLE_CONCURRENCY = YES` enabled on the widget target only. The project already uses modern concurrency patterns extensively — all 11 manager classes are `@MainActor @Observable`, the single `actor APIDispatcher` is well-designed, delegate callbacks use proper `nonisolated` + `Task { @MainActor in }` bridges, and there are no legacy `ObservableObject`/`@Published` patterns in active code.

Migrating to Swift 6 strict concurrency will give compile-time data-race safety guarantees. The codebase is ~90% ready; the remaining work is addressing a handful of isolation gaps.

**Strategy:** Conservative — keep everything `@MainActor`, only offload to background if Instruments profiling shows bottlenecks post-migration. This follows Apple's WWDC 2025 guidance: "Start single-threaded, add concurrency only when profiling proves it's needed."

## Approach: Incremental (per-target)

Widget extension first (smallest, already has approachable concurrency) → Main app → Test targets.

---

## Phase 1 — Preparation (build settings only)

### 1.1 Enable strict concurrency checking in Swift 5 mode

Turn on `SWIFT_STRICT_CONCURRENCY = complete` while keeping `SWIFT_VERSION = 5.0`. This surfaces all violations as warnings without breaking the build.

**File:** `MetroParking.xcodeproj/project.pbxproj`
- All 4 targets: add `SWIFT_STRICT_CONCURRENCY = complete` (Debug + Release)
- All 4 targets: add `SWIFT_APPROACHABLE_CONCURRENCY = YES` (currently only on widget)

### 1.2 Build and catalogue warnings

Build all targets. Note every concurrency warning — these become errors in Swift 6.

---

## Phase 2 — Fix isolation issues

### 2.1 `BackgroundTaskManager` — add `@MainActor`

**File:** `MetroParking/Managers/BackgroundTaskManager.swift`

**Problem:** Plain `final class` with no isolation. Mutable properties (`lastAppRefreshScheduleTime`, `lastProcessingTaskScheduleTime`) are unprotected. Already accessed from `@MainActor` contexts and its `performBackgroundRefresh` is already `@MainActor`.

**Fix:**
- Add `@MainActor` to the class declaration
- The BGTaskScheduler `register` closures (lines 42-57) are called from system context — they already use `Task { await self.handle... }` which correctly hops to MainActor
- `scheduleProcessingTaskIfNeeded()` (line 140): wrap callback body in `Task { @MainActor in ... }` instead of directly accessing `self`
- `printScheduledTasks()` (line 381): same treatment for its callback

### 2.2 `ParkingAPIService` — add `@MainActor`

**File:** `MetroParking/Services/ParkingAPIService.swift`

**Problem:** Plain `class` with `static let shared`. Holds `session` and `decoder` as instance properties. Always accessed from MainActor contexts via `FacilityManager`.

**Fix:** Add `@MainActor` to the class. The `async throws` methods will suspend on `await session.data(for:)` which runs on URLSession's background threads — this is fine, the await point releases MainActor.

### 2.3 `WidgetBudgetTracker` — add `@MainActor`

**File:** `MetroParking/Utils/WidgetBudgetTracker.swift`

**Problem:** Plain `final class`, no isolation. All callers are MainActor.

**Fix:** Add `@MainActor` to the class.

### 2.4 `APIUsageMonitor` — add `@MainActor`

**File:** `MetroParking/Utils/APIUsageMonitor.swift`

**Problem:** `struct` with static mutable methods (`recordCall`, `resetIfNeeded`) accessing UserDefaults. Global state in Swift 6 needs isolation.

**Fix:** Add `@MainActor` to the struct. All callers (`ParkingAPIService`, `FacilityManager`, `BackgroundTaskManager.performBackgroundRefresh`) are MainActor.

### 2.5 `DistanceHelper` — add `@MainActor`

**File:** `MetroParking/Utils/DistanceHelper.swift`

**Problem:** `static var cachedDistances` and `static var cacheValidLocation` are unprotected mutable global state.

**Fix:** Add `@MainActor` to the struct. All callers are UI sorting code on MainActor.

### 2.6 `RouteInfo` — keep `@preconcurrency import`

**File:** `MetroParking/Managers/ETAManager.swift:14`

**Problem:** `struct RouteInfo: Sendable` contains `let route: MKRoute` which isn't formally Sendable.

**Fix:** Keep `@preconcurrency import MapKit` (line 9). This suppresses the Sendable check for MapKit types. MKRoute is immutable in practice. When Apple adds Sendable conformance, remove `@preconcurrency`. No code change needed.

### 2.7 `APIError` — add `Sendable`

**File:** `MetroParking/Services/ParkingAPIService.swift:117`

**Fix:** Change to `enum APIError: LocalizedError, Sendable`. The `decodingFailed(Error)` case uses `any Error` which conforms to `Sendable`.

### 2.8 `BackgroundRefreshScope` — add `Sendable`

**File:** `MetroParking/Managers/BackgroundTaskManager.swift:242`

**Fix:** Change to `enum BackgroundRefreshScope: Sendable`. No associated values, trivial.

### 2.9 `LoadProgress` — add `Sendable`

**File:** `MetroParking/Managers/FacilityManager.swift:460`

**Fix:** Change to `enum LoadProgress: Sendable`. Associated values are `Int` (already Sendable).

### 2.10 Legacy `DispatchQueue` in debug view

**File:** `MetroParking/Views/BackgroundRefreshDebugView.swift:264-266`

**Fix:** Replace `DispatchQueue.main.async { self.scheduledTasks = requests }` with `Task { @MainActor in self.scheduledTasks = requests }`.

---

## Phase 3 — Flip to Swift 6 (per-target)

### 3.1 Widget extension

- Change `SWIFT_VERSION = 6.0` for `MetroParkingWidgetExtension`
- Build, fix any remaining errors
- Test widget in simulator

### 3.2 Main app

- Change `SWIFT_VERSION = 6.0` for `MetroParking`
- Build, fix remaining errors (expect some from the compiler that strict-checking-as-warnings missed)
- Run app, verify all features

### 3.3 Test targets

- Change `SWIFT_VERSION = 6.0` for `MetroParkingTests` and `MetroParkingUITests`
- Fix test-specific issues (likely `@MainActor` test methods)

---

## Phase 4 — Default Main Actor Isolation (optional, Xcode 26+)

After Swift 6 is stable, enable `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. This makes all code `@MainActor` by default, requiring explicit `nonisolated` for non-UI work. Matches this project's architecture perfectly.

---

## Performance: Future offloading candidates

**No offloading in this migration.** If Instruments profiling later shows main thread contention, these are the candidates to move to background:

| Candidate | Current state | Potential change |
|-----------|--------------|-----------------|
| `ParkingAPIService` (JSON decoding) | `@MainActor` | Convert to `actor` or mark `decode()` as `@concurrent` |
| `DistanceHelper` (math) | `@MainActor` | Mark calculation methods `@concurrent` |
| `BackgroundTaskManager.performBackgroundRefresh` | `@MainActor` | Move SwiftData fetch + API loop to background `ModelContext` |
| `FacilityManager.performLoad` (sort/filter loop) | `@MainActor` | Extract sorting to `@concurrent` helper |

These are only worth doing if profiling shows >16ms frames during these operations.

---

## Files to modify (summary)

| File | Change |
|------|--------|
| `project.pbxproj` | Add `SWIFT_STRICT_CONCURRENCY = complete` + `SWIFT_APPROACHABLE_CONCURRENCY = YES` all targets, then `SWIFT_VERSION = 6.0` |
| `BackgroundTaskManager.swift` | Add `@MainActor`, wrap callback bodies in `Task { @MainActor in }` |
| `ParkingAPIService.swift` | Add `@MainActor`, add `: Sendable` to `APIError` |
| `WidgetBudgetTracker.swift` | Add `@MainActor` |
| `APIUsageMonitor.swift` | Add `@MainActor` |
| `DistanceHelper.swift` | Add `@MainActor` |
| `BackgroundTaskManager.swift` | Add `: Sendable` to `BackgroundRefreshScope` |
| `FacilityManager.swift` | Add `: Sendable` to `LoadProgress` |
| `BackgroundRefreshDebugView.swift` | Replace `DispatchQueue.main.async` → `Task { @MainActor in }` |

---

## Verification

1. **Build:** Zero errors and zero concurrency warnings across all 4 targets
2. **Runtime — core features:**
    - Facility list loads and auto-refreshes every 60s
    - Location services work (distance sorting)
    - ETA calculations complete
    - Pin/unpin facilities
    - Search works
    - Widget shows correct data after add/remove
3. **Runtime — background:**
    - Background refresh triggers (use `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.tomkwok.MetroParking.refresh"]` in debugger)
    - Widget data updates after background refresh
4. **Thread Sanitizer:** Run with TSan enabled to catch any runtime data races the compiler might miss
5. **Widget:** Remove and re-add widget, verify it loads fresh data
