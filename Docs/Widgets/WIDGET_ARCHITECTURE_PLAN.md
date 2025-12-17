# Widget & Live Activity Architecture Plan

## 🎯 Overall Vision

Create a comprehensive widget and Live Activity system for MetroParking that provides:
1. Quick glanceable parking information
2. Real-time updates via notifications
3. Multiple widget variants for different use cases
4. Seamless integration with the main app

---

## 📊 Widget Types

### 1. Single Facility Widget (✅ Phase 1 - Implemented)

**Purpose**: Monitor a specific parking facility

#### System Small ✅ 
- Facility name (2 lines max)
- Vacancy (XX/YY format)
- Status indicator (colored dot)
- Availability text

#### System Medium (⏳ Phase 2)
```
┌────────────────────────────────┐
│ 🅿️ Blacktown Station    🟢    │
│                                │
│ 45/100 spaces                  │
│ Available                      │
│                                │
│ 📍 2.5 km away                 │
│ 🚗 7 min drive                 │
└────────────────────────────────┘
```

Features:
- Everything from Small
- Distance from current location
- ETA with travel time
- Optional mini occupancy gauge

#### System Large (⏳ Phase 2)
```
┌────────────────────────────────┐
│ 🅿️ Blacktown Station    🟢    │
│                                │
│ ┌────────────────────┐         │
│ │  [Mini Map View]   │         │
│ │    📍 You          │         │
│ │     ↓              │         │
│ │    🅿️ Facility     │         │
│ └────────────────────┘         │
│                                │
│ 45/100 spaces  •  Available    │
│ 2.5 km  •  7 min drive         │
│                                │
│ Updated 2 min ago              │
└────────────────────────────────┘
```

Features:
- Everything from Medium
- Mini map showing location
- Last updated timestamp
- Possibly "Get Directions" button

#### Accessory Widgets (⏳ Phase 3)
- **Rectangular**: Facility name + vacancy
- **Circular**: Just vacancy number with color ring
- **Inline**: "45 spaces at Blacktown"

---

### 2. Nearby Facilities Widget (⏳ Phase 3)

**Purpose**: Watchlist of parking options, sorted by distance

#### System Medium
```
┌────────────────────────────────┐
│ 🅿️ Nearby Parking              │
│                                │
│ Blacktown Stn    45   🟢  2km  │
│ Parramatta       12   🟡  3km  │
│ Seven Hills       0   🔴  5km  │
└────────────────────────────────┘
```

Features:
- 3 nearest facilities
- Name + vacancy + status + distance
- Auto-sorted by distance
- Quick tap to open in app

#### System Large
```
┌────────────────────────────────┐
│ 🅿️ Nearby Parking              │
│                                │
│ Blacktown Stn    ▃▅▇▇█ 45  2km│
│ Parramatta       ▁▃▃▃▅ 12  3km│
│ Seven Hills      ▇▇▇██  0  5km│
│ Penrith West     ▃▃▅▅▅ 23  7km│
│ Mount Druitt     ▅▅▇▇▇ 34  9km│
│                                │
│ Updated just now               │
└────────────────────────────────┘
```

Features:
- 5-6 nearest facilities
- Sparkline showing occupancy trend (like stocks)
- Color-coded availability
- Last update time

#### System Extra Large (iPadOS)
```
┌─────────────────────────────────────────────┐
│ 🅿️ Nearby Parking               Updated now│
│                                             │
│ Facility          Trend      Spaces    ETA  │
│ ───────────────────────────────────────────│
│ Blacktown Stn    ▃▅▇▇█      45/100    7min │
│ Parramatta       ▁▃▃▃▅      12/89     9min │
│ Seven Hills      ▇▇▇██       0/120   12min │
│ Penrith West     ▃▃▅▅▅      23/95    15min │
│ Mount Druitt     ▅▅▇▇▇      34/110   18min │
│ Westmead         ▅▅▅▅█      56/150   11min │
│ Olympic Park     ▃▅▇▇▇      89/200   20min │
└─────────────────────────────────────────────┘
```

Features:
- Extended list (7+ facilities)
- Tabular layout
- More detailed information
- Better for iPad

---

## 🔴 Live Activities

### Purpose
Real-time monitoring while user is traveling to or parked at a facility

### Trigger Points
1. **From Detail View**: "Start Tracking" button
2. **From List**: Swipe action → "Track"
3. **Auto-start**: When user starts navigation in Maps
4. **Parking**: When user arrives at facility

### Dynamic Island (iPhone 14 Pro+)

#### Minimal (Collapsed)
```
🅿️ 45
```
Just the parking icon and available spaces

#### Compact (Side by side with other activities)
```
┌────────────┐
│ 🅿️ 45  7min│
└────────────┘
```
Spaces + ETA

#### Expanded
```
┌─────────────────────────┐
│   Blacktown Station     │
│                         │
│   45/100 spaces         │
│   Available             │
│                         │
│   📍 2.5 km away        │
│   🚗 7 min drive        │
│                         │
│   [Get Directions] [×]  │
└─────────────────────────┘
```

Interactive buttons:
- **Get Directions**: Opens Maps
- **× Stop**: Ends activity

### Lock Screen

```
┌─────────────────────────────┐
│ 🅿️ Blacktown Station        │
│                             │
│ ▓▓▓▓▓▓▓▓▓░░░░░░░  45/100   │
│                             │
│ Available                   │
│                             │
│ 📍 2.5 km • 🚗 7 min        │
│                             │
│ Updated 30 sec ago          │
└─────────────────────────────┘
```

### Update Strategy

**Frequency:**
- Active navigation: Every 1 minute
- Stationary: Every 5 minutes
- Critical changes: Immediate push

**Update Triggers:**
1. Vacancy drops below threshold
2. User location changes significantly
3. ETA changes by >2 minutes
4. Status changes (available → almost full → full)

**Auto-end Conditions:**
- User arrives at facility (location-based)
- User manually stops
- After 3 hours of inactivity
- Facility closes

---

## 🔧 Technical Implementation

### Data Architecture

```
┌──────────────┐
│  Main App    │
│              │
│  SwiftData   │◄─────┐
└──────────────┘      │
                      │
                App Group
              UserDefaults
                      │
┌──────────────┐      │
│   Widgets    │      │
│              │◄─────┘
│  Timeline    │
│  Provider    │
└──────────────┘
        │
        ▼
┌──────────────┐
│ Live Activity│
│              │
│ ActivityKit  │
└──────────────┘
```

### Shared Data Layer

**App Group Container:**
- SwiftData models (ParkingFacility, ParkingZone)
- UserDefaults for quick access
- File-based cache for larger data

**UserDefaults Keys:**
```swift
// Single facility widget
"selectedFacility" -> WidgetFacilityData (JSON)

// Favorites list
"favoriteFacilityIds" -> [String]

// Nearby facilities cache
"nearbyFacilities" -> [WidgetFacilityData] (JSON)

// Last update time
"lastWidgetUpdate" -> Date

// User preferences
"widgetUpdateFrequency" -> Int (minutes)
"showETAInWidget" -> Bool
```

### Update Mechanisms

#### 1. Timeline-based (Widgets)
```swift
// Every 5-15 minutes depending on battery
Timeline(entries: [entry], policy: .after(nextUpdate))
```

#### 2. Push Notifications (Live Activities & Important Updates)
```swift
// Critical updates (e.g., facility full)
ActivityKit.update(activity, contentState: newState, pushType: .token)
```

#### 3. Background App Refresh
```swift
// Fetch new data when app is backgrounded
BGTaskScheduler -> Fetch API -> Update shared data -> Reload widgets
```

#### 4. Manual Refresh (App Foreground)
```swift
// User pulls to refresh in app
FacilityManager.loadFacility() -> Update SwiftData -> Update widgets
```

---

## 📱 App Intents Integration (Phase 4)

### Configuration Intents

Allow users to configure widgets directly from widget editor:

```swift
struct SelectFacilityIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Facility"
    
    @Parameter(title: "Facility")
    var facility: FacilityEntity
    
    @Parameter(title: "Show ETA", default: true)
    var showETA: Bool
}
```

### Interactive Intents

Make widgets interactive (iOS 17+):

- **Refresh Button**: Update data without opening app
- **Toggle Favorite**: Star/unstar facility
- **Get Directions**: Open Maps directly
- **Facility Picker**: Switch between facilities

### Shortcut Actions

Expose parking actions to Shortcuts app:

- "Get parking availability at [facility]"
- "Find nearest parking"
- "Start parking timer"
- "Set parking reminder"

---

## 🎨 Design System

### Colors

```swift
// Status colors (already defined in AvailabilityStatus)
Available:    Green  (#34C759)
Almost Full:  Yellow (#FFCC00)
Full:         Red    (#FF3B30)
No Data:      Gray   (#8E8E93)
```

### Typography

```swift
// Widget text sizes
Facility Name:     .subheadline, .semibold
Vacancy (large):   .title, .bold
Vacancy (small):   .callout
Status:            .caption2, .medium
Distance/ETA:      .caption
```

### Spacing

```swift
// Consistent padding
Small:  12pt
Medium: 16pt
Large:  20pt

// Corner radius
Cards:  12pt
Buttons: 8pt
```

### Animations

```swift
// Content transitions
Numbers:   .numericText
Status:    .symbolEffect(.replace)
Colors:    .interpolate
```

---

## 🔔 Notification Strategy

### Smart Notifications

**Triggers:**
1. Facility approaching capacity
2. User's selected facility becomes available
3. Price changes (future feature)
4. Maintenance closures

**Smart Delivery:**
- Only during commute hours
- Only for favorited facilities
- Respectful frequency limits

**Push Token Registration:**
```swift
// Register device for push
ActivityKit.pushToken -> Send to backend
Backend -> APNs -> Update Live Activity
```

---

## 🚀 Implementation Phases

### ✅ Phase 1: Basic Single Widget (Complete)
- [x] App Groups setup
- [x] Shared data layer
- [x] System Small widget
- [x] Set widget from detail view
- [x] Auto-update on refresh

### ⏳ Phase 2: Extended Single Widget (Next)
- [ ] System Medium with ETA
- [ ] System Large with map
- [ ] Lock Screen accessories
- [ ] Better error states
- [ ] Loading states

### ⏳ Phase 3: Nearby Facilities Widget
- [ ] Location tracking in widget
- [ ] Fetch nearby facilities
- [ ] System Medium list
- [ ] System Large with trends
- [ ] Sparkline visualization

### ⏳ Phase 4: App Intents
- [ ] Configuration intents
- [ ] Interactive widgets (iOS 17+)
- [ ] Shortcuts actions
- [ ] Siri integration

### ⏳ Phase 5: Live Activities
- [ ] Activity attributes definition
- [ ] Dynamic Island views
- [ ] Lock Screen views
- [ ] Push notification setup
- [ ] Auto-start/stop logic

### ⏳ Phase 6: Polish & Optimization
- [ ] Battery optimization
- [ ] Network efficiency
- [ ] Error handling
- [ ] Accessibility
- [ ] Localization

---

## 📊 Success Metrics

### User Engagement
- Widget adoption rate
- Daily active widget users
- Live Activity starts
- Interaction rate (taps, buttons)

### Technical Performance
- Widget load time < 1s
- Memory usage < 30MB
- Network requests < 100/day
- Battery impact < 2%

### User Satisfaction
- Ratings mentioning widgets
- Feature requests
- Bug reports
- Support tickets

---

## 🎯 Future Enhancements

### Advanced Features
- Historical occupancy graphs
- Predictive availability (ML)
- Multi-facility comparison
- Route optimization
- Payment integration
- Reservation system

### Platform Expansion
- watchOS complications
- macOS menu bar widget
- CarPlay integration
- Apple Watch standalone

### Social Features
- Share parking spots
- Family location sharing
- Parking buddy system

---

**Document Status:** Living document - Updated as implementation progresses
**Last Updated:** December 16, 2025
**Next Review:** After Phase 2 completion
