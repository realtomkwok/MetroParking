# Architecture

MetroParking is a SwiftUI app with a WidgetKit extension. Both read one SwiftData store in the App Group `group.com.tomkwok.MetroParking`.

## Layers

| Layer | Folder | Isolation | Used by widget |
|---|---|---|---|
| App shell | `App/` | Main actor | No |
| Features (screens) | `Features/` | Main actor | No |
| Design system | `DesignSystem/` | Main actor | No |
| Model | `Core/Model/` | `nonisolated` | Yes |
| Networking | `Core/Networking/` | `nonisolated` (`APIDispatcher` is an actor) | Yes |
| Persistence | `Core/Persistence/` | Container `nonisolated`, manager main actor | Yes |
| Refresh | `Core/Refresh/` | Main actor (config `nonisolated`) | Config and budget only |
| Location | `Core/Location/` | Main actor | No |
| Support | `Core/Support/` | `nonisolated` | Logger and helpers |

**Build settings**
- Swift 6 language mode and complete strict concurrency.
- Approachable concurrency.
- Default actor isolation is `MainActor` for the app and widget.

**Shared code isolation rule.** The widget compiles the shared files listed in the project's membership exceptions. Anything in that list must be explicitly `nonisolated`. Otherwise the widget's timeline provider and background `ModelContext`s would have to hop to the main actor.

## Main screen

`ContentView` is a full-screen `ParkingMapView` with `SheetStack` layered on top:

- **Compact width:** a persistent bottom sheet with collapsed, medium and large detents.
- **Regular width or compact height:** a floating glass panel beside the map (`FloatingPanel`).

`MapSheetModel` owns the navigation path, detent and camera. The selected facility is derived from the top of the path, so the map and the sheet can't disagree. Because the model lives outside the presentation, state survives switching between sheet and panel, for example when unfolding an iPhone Duo.

**Entry points that select a facility**
- Map pins, list rows, nearby rows and deep links (`metroparking://facility/{id}`) all push the same `MapSheetModel.Route`.

**Camera framing**
- The map adds safe-area padding for the edge the sheet or panel covers, so framing follows it without any screen maths.

## Dependency injection

`AppEnvironment` holds the app-wide services and injects them with `.appEnvironment(.live)`. Previews use `.previewEnvironment()`.

The services themselves remain process-wide instances because background tasks and the widget share them. Views never name them directly.

State that belongs to one screen is owned by that screen, for example `LookAroundLoader` in the detail view.

## Data and refresh

1. **Seeding.** `StaticFacilityInfo` seeds the store on first launch. The seed data is a `Sendable` value array, and each load creates fresh model objects.
2. **Foreground refresh.** `FacilityManager.performLoad` fetches facilities whose cache has expired.
   - Watched facilities (pinned or in a widget) go first.
   - Up to `API.maxConcurrentRequests` fetches run at once through `APIDispatcher`, which reserves request start times 0.4 s apart.
   - Decoding runs off the main actor (`@concurrent`); results are applied on the main actor.
   - A forced refresh that arrives during a cycle is queued.
3. **Background refresh.** `BackgroundTaskManager` runs a quick scope (watched facilities) from `BGAppRefreshTask` and a full scope from `BGProcessingTask`.
4. **Quota.** `APIUsageMonitor` keeps a daily `{day, count}` in the App Group, so widget calls count too.
5. **Widget.**
   - The timeline uses whichever is newer: the SwiftData row or the App Group JSON cache.
   - It refreshes through the same `ParkingAPIService` when the data is older than the watched-tier validity.
   - The cache stores `AvailabilityStatus` raw values, so colours and text don't depend on the device language.
6. **Store recovery.** If the store can't be opened, it's rebuilt; as a last resort the app uses an in-memory store instead of crashing.

## Configuration

`Config.xcconfig` is the project's base configuration, so both targets see its values. The app and widget Info.plists expose `TFNSW_API_KEY` and `CAR_PARK_BASE_URL`.

A missing or malformed key doesn't crash anything:
- `Configuration.tfnswApiKey` returns `nil`.
- Requests throw `APIError.missingAPIKey`.

## Testing

`MetroParkingTests` uses Swift Testing. It covers:
- model parsing and availability thresholds
- API decoding
- sheet navigation and deep links
- panel sizing
- the dispatcher, usage counter and background scheduling

`MetroParkingUITests` holds the fastlane screenshot tests.
