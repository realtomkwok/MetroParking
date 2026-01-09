# Widget Data Flow Diagram

## 📊 Complete System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER INTERACTION                         │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
        ┌─────────────────────────────────────────┐
        │         Main App (MetroParking)         │
        │                                         │
        │  ┌───────────────────────────────────┐ │
        │  │   FacilityDetailView              │ │
        │  │                                   │ │
        │  │  ┌─────────────────────────────┐ │ │
        │  │  │ "Set as Widget" button      │ │ │
        │  │  │  tapped                     │ │ │
        │  │  └─────────────────────────────┘ │ │
        │  │            │                      │ │
        │  └────────────┼──────────────────────┘ │
        │               │                        │
        │               ▼                        │
        │  ┌────────────────────────────────┐   │
        │  │  SharedDataManager.            │   │
        │  │    updateWidget(facility)      │   │
        │  └────────────────────────────────┘   │
        │               │                        │
        └───────────────┼────────────────────────┘
                        │
                        ▼
        ┌───────────────────────────────────────┐
        │        App Group Container            │
        │   group.com.yourteam.MetroParking     │
        │                                       │
        │  ┌─────────────────────────────────┐ │
        │  │  UserDefaults (Shared Suite)    │ │
        │  │                                 │ │
        │  │  Key: "selectedFacility"        │ │
        │  │  Value: WidgetFacilityData      │ │
        │  │    - facilityId                 │ │
        │  │    - name                       │ │
        │  │    - availableSpaces            │ │
        │  │    - totalSpaces                │ │
        │  │    - status                     │ │
        │  │    - distance                   │ │
        │  │    - travelTime                 │ │
        │  │    - lastUpdated                │ │
        │  └─────────────────────────────────┘ │
        │                                       │
        │  ┌─────────────────────────────────┐ │
        │  │  SwiftData Container            │ │
        │  │    - ParkingFacility            │ │
        │  │    - ParkingZone                │ │
        │  └─────────────────────────────────┘ │
        └───────────────────────────────────────┘
                        │
                        │ (reads)
                        ▼
        ┌───────────────────────────────────────┐
        │    Widget Extension (Timeline)         │
        │   MetroParkingWidget                   │
        │                                        │
        │  ┌─────────────────────────────────┐  │
        │  │  FacilityProvider               │  │
        │  │    .getTimeline()               │  │
        │  │         │                       │  │
        │  │         ▼                       │  │
        │  │  SharedDataManager.             │  │
        │  │    loadWidgetData()             │  │
        │  │         │                       │  │
        │  │         ▼                       │  │
        │  │  FacilityEntry(               │  │
        │  │    date: Date(),                │  │
        │  │    facility: data               │  │
        │  │  )                              │  │
        │  │         │                       │  │
        │  │         ▼                       │  │
        │  │  Timeline(                      │  │
        │  │    entries: [entry],            │  │
        │  │    policy: .after(5 min)        │  │
        │  │  )                              │  │
        │  └─────────────────────────────────┘  │
        │               │                        │
        │               ▼                        │
        │  ┌─────────────────────────────────┐  │
        │  │  FacilityWidgetSmallView        │  │
        │  │                                 │  │
        │  │   🅿️              🟢           │  │
        │  │                                 │  │
        │  │   Blacktown Stn                 │  │
        │  │   45/100                        │  │
        │  │   Available                     │  │
        │  └─────────────────────────────────┘  │
        └───────────────────────────────────────┘
                        │
                        ▼
        ┌───────────────────────────────────────┐
        │         Home Screen Widget             │
        │      (User sees this)                  │
        └───────────────────────────────────────┘
```

---

## 🔄 Automatic Update Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                   FACILITY DATA REFRESH                          │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
        ┌─────────────────────────────────────────┐
        │         Main App (MetroParking)         │
        │                                         │
        │  ┌───────────────────────────────────┐ │
        │  │   FacilityManager                 │ │
        │  │    .loadFacility(facility)        │ │
        │  │            │                      │ │
        │  │            ▼                      │ │
        │  │   API Call to TfNSW               │ │
        │  │            │                      │ │
        │  │            ▼                      │ │
        │  │   facility.updateFromAPI()        │ │
        │  │            │                      │ │
        │  │            ▼                      │ │
        │  │   withAnimation(.snappy) {        │ │
        │  │     // Update properties          │ │
        │  │   }                               │ │
        │  │            │                      │ │
        │  │            ▼                      │ │
        │  │   SharedDataManager.              │ │
        │  │     updateWidgetIfSelected()      │ │
        │  │            │                      │ │
        │  │            ▼                      │ │
        │  │   Check: Is this facility         │ │
        │  │   currently in widget?            │ │
        │  │      │              │             │ │
        │  │   NO │              │ YES         │ │
        │  │      ▼              ▼             │ │
        │  │   Skip        Update widget       │ │
        │  └───────────────────────────────────┘ │
        │                       │                │
        └───────────────────────┼────────────────┘
                                │
                                ▼
        ┌───────────────────────────────────────┐
        │     Save to App Group UserDefaults    │
        └───────────────────────────────────────┘
                                │
                                ▼
        ┌───────────────────────────────────────┐
        │   WidgetCenter.shared                  │
        │     .reloadAllTimelines()              │
        └───────────────────────────────────────┘
                                │
                                ▼
        ┌───────────────────────────────────────┐
        │   Widget Extension Re-renders          │
        │   with Updated Data                    │
        └───────────────────────────────────────┘
```

---

## ⏰ Timeline-Based Update Flow

```
        ┌───────────────────────────────────────┐
        │   Widget Extension Timeline           │
        │      (Every 5 minutes)                │
        └───────────────────────────────────────┘
                        │
                        ▼
        ┌───────────────────────────────────────┐
        │  System calls:                         │
        │    provider.getTimeline(               │
        │      completion: callback              │
        │    )                                   │
        └───────────────────────────────────────┘
                        │
                        ▼
        ┌───────────────────────────────────────┐
        │  Load data from App Group:             │
        │    SharedDataManager.loadWidgetData()  │
        └───────────────────────────────────────┘
                        │
                        ▼
        ┌───────────────────────────────────────┐
        │  Create entry:                         │
        │    FacilityEntry(                      │
        │      date: Date(),                     │
        │      facility: data                    │
        │    )                                   │
        └───────────────────────────────────────┘
                        │
                        ▼
        ┌───────────────────────────────────────┐
        │  Schedule next update:                 │
        │    Timeline(                           │
        │      entries: [entry],                 │
        │      policy: .after(                   │
        │        Date() + 5.minutes              │
        │      )                                 │
        │    )                                   │
        └───────────────────────────────────────┘
                        │
                        ▼
        ┌───────────────────────────────────────┐
        │  Call completion callback              │
        └───────────────────────────────────────┘
                        │
                        ▼
        ┌───────────────────────────────────────┐
        │  System renders widget view            │
        └───────────────────────────────────────┘
```

---

## 🎯 Data Structure Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    ParkingFacility (Model)                       │
│                                                                  │
│  - facilityId: String                                            │
│  - name: String                                                  │
│  - coordinate: CLLocationCoordinate2D                            │
│  - totalSpaces: Int                                              │
│  - vacancy: VacancyInfo                                          │
│    ├─ available: Int                                             │
│    ├─ occupied: Int                                              │
│    ├─ occupancy: Double                                          │
│    └─ cacheTimestamp: Date                                       │
│  - route: RouteInfo?                                             │
│    ├─ distance: CLLocationDistance                               │
│    ├─ travelTime: TimeInterval                                   │
│    └─ calculatedAt: Date                                         │
│  - availabilityStatus: AvailabilityStatus                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  │ Converts to ▼
                                  │
┌─────────────────────────────────────────────────────────────────┐
│               WidgetFacilityData (Codable)                       │
│                                                                  │
│  - facilityId: String                                            │
│  - name: String                                                  │
│  - displayTitle: String                                          │
│  - displaySubtitle: String                                       │
│  - address: String                                               │
│  - availableSpaces: Int                                          │
│  - totalSpaces: Int                                              │
│  - occupancyRatio: Double                                        │
│  - availabilityStatus: String                                    │
│  - distance: Double?                                             │
│  - travelTime: TimeInterval?                                     │
│  - lastUpdated: Date                                             │
│  - cacheTimestamp: Date                                          │
│                                                                  │
│  Computed:                                                       │
│  - statusColor: String ("green", "yellow", "red")                │
│  - formattedVacancy: String ("45/100")                           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  │ Encodes to JSON ▼
                                  │
┌─────────────────────────────────────────────────────────────────┐
│            UserDefaults (App Group Suite)                        │
│                                                                  │
│  Key: "selectedFacility"                                         │
│  Value: Data (JSON blob)                                         │
│                                                                  │
│  {                                                               │
│    "facilityId": "TfNSW:1234",                                   │
│    "name": "Park&Ride - Blacktown Station",                     │
│    "displayTitle": "Blacktown Station",                          │
│    "displaySubtitle": "Park&Ride",                               │
│    "availableSpaces": 45,                                        │
│    "totalSpaces": 100,                                           │
│    "availabilityStatus": "available",                            │
│    "distance": 2500.0,                                           │
│    "travelTime": 420.0,                                          │
│    ...                                                           │
│  }                                                               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  │ Reads & Decodes ▼
                                  │
┌─────────────────────────────────────────────────────────────────┐
│                 FacilityEntry (Timeline Entry)                   │
│                                                                  │
│  - date: Date                                                    │
│  - facility: WidgetFacilityData?                                 │
│  - isPlaceholder: Bool                                           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  │ Passed to View ▼
                                  │
┌─────────────────────────────────────────────────────────────────┐
│            FacilityWidgetSmallView (SwiftUI)                     │
│                                                                  │
│  Displays:                                                       │
│  - entry.facility.displayTitle                                   │
│  - entry.facility.availableSpaces / totalSpaces                  │
│  - entry.facility.availabilityStatus (colored)                   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔐 Security & Privacy Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                      App Entitlements                            │
│                                                                  │
│  ✓ App Groups: group.com.yourteam.MetroParking                  │
│  ✓ Background Modes: fetch, processing                          │
│  ✓ Location: When In Use                                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Widget Entitlements                            │
│                                                                  │
│  ✓ App Groups: group.com.yourteam.MetroParking                  │
│    (Must match main app exactly)                                │
│                                                                  │
│  ✗ Location: Widgets can't request location                     │
│    (Must use location from main app)                            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Shared Container Access                         │
│                                                                  │
│  Both app and widget can:                                        │
│  ✓ Read/Write to App Group UserDefaults                         │
│  ✓ Access SwiftData in group container                          │
│  ✓ Share files in group directory                               │
│                                                                  │
│  Data is sandboxed and isolated from:                           │
│  ✗ Other apps                                                   │
│  ✗ Other app groups                                             │
│  ✗ System directories                                           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Complete Lifecycle

```
1. USER OPENS APP
   └─> App launches
       └─> FacilityManager loads facilities
           └─> SwiftData fetches from persistent store

2. USER VIEWS FACILITY
   └─> FacilityDetailView displays
       └─> Calculates ETA if location available
           └─> Updates facility.route property

3. USER TAPS "SET AS WIDGET"
   └─> setAsWidget() called
       └─> SharedDataManager.updateWidget(facility)
           └─> Converts to WidgetFacilityData
               └─> JSON encodes
                   └─> Saves to UserDefaults
                       └─> Calls WidgetCenter.reloadAllTimelines()
                           └─> Shows confirmation alert

4. WIDGET RENDERS
   └─> System calls provider.getTimeline()
       └─> loadWidgetData() from UserDefaults
           └─> JSON decodes to WidgetFacilityData
               └─> Creates FacilityEntry
                   └─> Passes to view
                       └─> View renders on home screen

5. DATA REFRESHES (IN APP)
   └─> FacilityManager.loadFacility()
       └─> API call
           └─> facility.updateFromAPI()
               └─> Updates SwiftData
                   └─> SharedDataManager.updateWidgetIfSelected()
                       └─> Checks if this is widget facility
                           └─> Updates UserDefaults
                               └─> Reloads widget timeline

6. TIMELINE EXPIRES (5 MINUTES LATER)
   └─> System calls provider.getTimeline() again
       └─> Loads possibly updated data
           └─> Creates new entry
               └─> Schedules next update
                   └─> Widget re-renders

7. USER CLOSES APP
   └─> App enters background
       └─> Data persists in App Group
           └─> Widget continues to function
               └─> Timeline updates continue

8. BACKGROUND REFRESH (FUTURE)
   └─> System wakes app
       └─> Fetch new facility data
           └─> Update SwiftData
               └─> Update shared data
                   └─> Reload widgets
                       └─> App returns to background
```

---

## 📊 Performance Considerations

```
┌─────────────────────────────────────────────────────────────────┐
│                      Widget Limits                               │
│                                                                  │
│  Memory:    ~30 MB max                                           │
│  CPU:       Limited processing time                              │
│  Network:   Strongly discouraged in views                        │
│  Updates:   Controlled by system (battery-aware)                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                   Optimization Strategy                          │
│                                                                  │
│  ✓ Use lightweight Codable structs                              │
│  ✓ Cache data in UserDefaults (fast access)                     │
│  ✓ Avoid network calls in timeline provider                     │
│  ✓ Use efficient SwiftUI views                                  │
│  ✓ Minimize data transformation                                 │
│  ✓ Pre-compute values when saving                               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

This diagram shows the complete flow from user interaction to widget display!
