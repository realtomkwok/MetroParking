# Widget Configuration with AppIntents - Implementation Guide

## Overview
This implementation adds two key features to the MetroParking widget:
1. **Empty State** - Shows a helpful message when no facility is selected
2. **Widget Configuration** - Allows users to select a facility directly from the widget's long-press menu

## Files Created/Modified

### New Files

#### 1. `FacilityEntity.swift`
- **Purpose**: Represents a parking facility as an `AppEntity` for use in widget configuration
- **Key Components**:
  - `FacilityEntity`: Conforms to `AppEntity` protocol
  - `FacilityEntityQuery`: Implements `EntityQuery` to provide facility lists
  
**Methods in FacilityEntityQuery**:
- `entities(for:)` - Fetches specific facilities by ID
- `suggestedEntities()` - Returns all facilities for the picker (favorites first)
- `defaultResult()` - Returns the most recently visited favorite as default

#### 2. `SelectFacilityIntent.swift`
- **Purpose**: Defines the AppIntent for widget configuration
- **Key Components**:
  - Conforms to `WidgetConfigurationIntent`
  - Has a `facility` parameter of type `FacilityEntity?`

### Modified Files

#### 1. `MetroParkingWidget.swift`
**Changes**:
- Changed `FacilityProvider` from `TimelineProvider` to `AppIntentTimelineProvider`
- Updated methods to be `async` and accept `SelectFacilityIntent` configuration
- Added `loadFacilityData(facilityId:)` helper to fetch from SwiftData
- Added empty state view showing "No Facility" with instructions
- Changed widget configuration from `StaticConfiguration` to `AppIntentConfiguration`
- Added previews for all widget states (empty, available, almost full, full)

**Key Changes in Provider**:
```swift
// Old
func getTimeline(in context: Context, completion: @escaping (Timeline<FacilityEntry>) -> Void)

// New
func timeline(for configuration: SelectFacilityIntent, in context: Context) async -> Timeline<FacilityEntry>
```

#### 2. `SharedDataManager.swift`
**Added**:
- `loadWidgetData(forFacilityId:)` - Checks if cached data matches a specific facility ID

## How It Works

### User Flow

1. **Adding Widget Without Configuration**:
   - User adds widget to home screen
   - Widget shows empty state: "No Facility - Long press to select"
   
2. **Configuring Widget**:
   - User long-presses the widget
   - Taps "Edit Widget"
   - Sees a list of all parking facilities (favorites first)
   - Selects a facility
   - Widget updates to show that facility's data

3. **Widget Updates**:
   - Widget refreshes every 10 minutes
   - Provider fetches latest data from SwiftData based on selected facility
   - If facility is not found, shows empty state

### Data Flow

```
User Selection (Widget Config)
    ↓
SelectFacilityIntent.facility (FacilityEntity)
    ↓
FacilityProvider.timeline(for configuration:)
    ↓
loadFacilityData(facilityId: configuration.facility.id)
    ↓
Fetch from SwiftData ModelContainer
    ↓
Convert to WidgetFacilityData
    ↓
Create Timeline Entry
    ↓
Widget View Renders
```

## Integration Points

### App Group
- Both main app and widget access the same SwiftData container via App Group
- App Group ID: `group.com.tomkwok.metroparking`
- Defined in `SharedDataManager.appGroupIdentifier`

### SwiftData Access
The widget now directly accesses SwiftData instead of relying solely on UserDefaults cache:
- More reliable and up-to-date data
- Can query any facility, not just the "currently selected" one
- Supports multiple widgets with different facility selections

### Backward Compatibility
The existing UserDefaults-based caching is still in place for:
- Quick access in some scenarios
- Potential future use with app-driven updates
- Gradual migration path

## Testing

### Preview Support
Four preview configurations are provided:
1. **Empty State** - No facility selected
2. **Available** - Facility with plenty of spaces
3. **Almost Full** - Facility nearly at capacity
4. **Full** - Facility with no available spaces

### Testing Checklist
- [ ] Add widget to home screen → Shows empty state
- [ ] Long press → Edit Widget → See facility list
- [ ] Select a facility → Widget shows facility data
- [ ] Wait 10 minutes → Widget auto-refreshes
- [ ] Add multiple widgets → Each can show different facility
- [ ] Delete facility in app → Widget shows empty state gracefully

## Customization Options

### Extending to Medium/Large Widgets
To support additional widget sizes:

1. Add size to `supportedFamilies`:
```swift
.supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
```

2. Create size-specific views:
```swift
struct FocusedFacilityWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: FacilityEntry
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}
```

### Adding Facility Filtering
To show only favorites in the widget configuration:

Modify `FacilityEntityQuery.suggestedEntities()`:
```swift
func suggestedEntities() async throws -> [FacilityEntity] {
    let descriptor = FetchDescriptor<ParkingFacility>(
        predicate: #Predicate { $0.isFavourite == true },
        sortBy: [SortDescriptor(\.name)]
    )
    // ... rest of implementation
}
```

## Troubleshooting

### Widget Shows Empty State Despite Selection
- Check App Group entitlements are enabled for both targets
- Verify SwiftData container is shared via App Group
- Check console logs for fetch errors

### Facility List Not Appearing
- Ensure `FacilityEntity` and `FacilityEntityQuery` are in widget target
- Verify facilities exist in SwiftData
- Check that models are properly configured with `@Model` macro

### Widget Not Updating
- Check timeline policy is `.after(nextUpdate)`
- Verify SwiftData is saving changes
- Use `WidgetCenter.shared.reloadAllTimelines()` to force refresh

## Performance Considerations

- SwiftData queries are fast but run on every timeline update
- Consider caching strategy for better performance
- Widget uses `.contentMarginsDisabled()` for edge-to-edge design
- Timeline updates every 10 minutes to respect API rate limits

## Next Steps

Potential enhancements:
1. Add deep link to open facility detail in main app
2. Support interactive widgets (iOS 17+) for quick actions
3. Add Lock Screen widget variant
4. Implement widget relevance for smart stack
5. Add StandBy mode optimizations
