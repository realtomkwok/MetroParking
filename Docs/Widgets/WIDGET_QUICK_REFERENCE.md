# Widget Quick Reference Card

## 🚀 Quick Start (30 seconds)

```bash
1. Create Widget Extension Target
   Xcode → File → New → Target → Widget Extension

2. Configure App Group
   Both targets → Signing & Capabilities → + App Groups

3. Update identifier in SharedDataManager.swift:
   static let appGroupIdentifier = "group.YOUR.ID"

4. Add files to widget target:
   - SharedDataManager.swift ✅
   - ParkingFacility.swift ✅
   - ParkingZone.swift ✅

5. Build & Run!
```

---

## 📋 Essential Commands

### Set Facility as Widget (In App)
```swift
SharedDataManager.shared.updateWidget(with: facility)
```

### Load Widget Data (In Widget)
```swift
let data = SharedDataManager.shared.loadWidgetData()
```

### Reload All Widgets
```swift
WidgetCenter.shared.reloadAllTimelines()
```

### Reload Specific Widget
```swift
WidgetCenter.shared.reloadTimelines(ofKind: "FacilityWidget")
```

---

## 🗂️ File Checklist

### Main App Target
- ✅ SharedDataManager.swift
- ✅ ParkingFacility.swift
- ✅ ParkingZone.swift
- ✅ FacilityDetailView.swift (modified)
- ✅ FacilityManager.swift (modified)

### Widget Target
- ✅ MetroParkingWidget.swift
- ✅ SharedDataManager.swift (shared)
- ✅ ParkingFacility.swift (shared)
- ✅ ParkingZone.swift (shared)

### Documentation
- 📄 WIDGET_SETUP_GUIDE.md
- 📄 WIDGET_IMPLEMENTATION_CHECKLIST.md
- 📄 WIDGET_ARCHITECTURE_PLAN.md
- 📄 WIDGET_IMPLEMENTATION_SUMMARY.md
- 📄 WIDGET_DATA_FLOW.md
- 📄 WIDGET_QUICK_REFERENCE.md (this file)

---

## 🎯 Key Concepts

### App Groups
**Purpose:** Share data between app and widget
**Setup:** Both targets need same identifier
**Usage:** `UserDefaults(suiteName: "group.YOUR.ID")`

### Timeline Provider
**Purpose:** Tell widget when/what to display
**Method:** `getTimeline(completion:)`
**Frequency:** Every 5 minutes (customizable)

### Widget Entry
**Purpose:** Single point-in-time widget display
**Content:** Date + facility data + placeholder flag

### Shared Data
**Purpose:** Lightweight data format for widgets
**Type:** `WidgetFacilityData` (Codable struct)
**Storage:** UserDefaults in App Group

---

## 🔧 Common Tasks

### Change Update Frequency
```swift
// In FacilityProvider.getTimeline()
let nextUpdate = Calendar.current.date(
    byAdding: .minute, 
    value: 10,  // Change this
    to: Date()
)!
```

### Add New Widget Family
```swift
.supportedFamilies([
    .systemSmall,
    .systemMedium,  // Add this
    .systemLarge    // And this
])
```

### Create Different Widget View
```swift
switch family {
case .systemSmall:
    SmallWidgetView(entry: entry)
case .systemMedium:
    MediumWidgetView(entry: entry)
case .systemLarge:
    LargeWidgetView(entry: entry)
default:
    EmptyView()
}
```

### Handle Empty State
```swift
if let facility = entry.facility {
    // Show facility data
} else {
    // Show empty state
    Text("No Facility Selected")
}
```

---

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| Widget shows placeholder | Check App Group identifier matches |
| Build errors | Add missing files to widget target |
| Data not updating | Verify `reloadAllTimelines()` is called |
| Crash on launch | Check all dependencies in widget target |
| Widget not in gallery | Clean build folder & rebuild |

---

## 📊 Widget States

```swift
// Has data
FacilityEntry(
    date: Date(),
    facility: widgetData,
    isPlaceholder: false
)

// Empty state
FacilityEntry(
    date: Date(),
    facility: nil,
    isPlaceholder: false
)

// Placeholder (for gallery)
FacilityEntry(
    date: Date(),
    facility: .sample(),
    isPlaceholder: true
)
```

---

## 🎨 Status Colors

```swift
switch status {
case "available":    return .green
case "almostfull":   return .yellow
case "full":         return .red
default:             return .gray
}
```

---

## 📱 Widget Families

| Family | Size | Best For |
|--------|------|----------|
| `.systemSmall` | 2x2 | Glanceable info |
| `.systemMedium` | 4x2 | More details |
| `.systemLarge` | 4x4 | Rich content |
| `.accessoryRectangular` | Lock Screen | Quick glance |
| `.accessoryCircular` | Lock Screen | Minimal info |
| `.accessoryInline` | Lock Screen | Text only |

---

## 🔄 Update Flow

```
User Action → Update Data → Save to UserDefaults → 
Reload Timelines → Widget Refreshes
```

---

## ⚡ Performance Tips

1. **Keep data small** - Use compact Codable structs
2. **Pre-compute** - Calculate values when saving
3. **Cache smartly** - Balance freshness vs battery
4. **Avoid network** - Fetch data in app, not widget
5. **Optimize views** - Use efficient SwiftUI patterns

---

## 📞 Need More Details?

- **Setup instructions** → `WIDGET_SETUP_GUIDE.md`
- **Step-by-step checklist** → `WIDGET_IMPLEMENTATION_CHECKLIST.md`
- **Full architecture** → `WIDGET_ARCHITECTURE_PLAN.md`
- **Complete summary** → `WIDGET_IMPLEMENTATION_SUMMARY.md`
- **Data flow diagrams** → `WIDGET_DATA_FLOW.md`

---

## 🎯 Success Criteria

Widget is working when:
- ✅ Builds without errors
- ✅ Shows in widget gallery
- ✅ Displays facility data
- ✅ Updates on "Set as Widget" tap
- ✅ Auto-refreshes on data change
- ✅ Shows correct colors
- ✅ Handles empty state

---

## 🚀 Next Steps

1. Complete Phase 1 setup ✅
2. Test thoroughly ✅
3. Add Medium/Large sizes 
4. Implement nearby list widget
5. Add Live Activities
6. Integrate App Intents

---

**Quick Links:**
- [Apple Docs](https://developer.apple.com/documentation/widgetkit)
- [WWDC Video](https://developer.apple.com/videos/play/wwdc2023/10027/)
- [Sample Code](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension)

**Version:** 1.0 | **Phase:** 1 - Basic Widget | **Status:** Ready to Implement
