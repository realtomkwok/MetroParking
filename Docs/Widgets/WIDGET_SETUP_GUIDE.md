# MetroParking Widget Setup Guide

## 📋 Overview

This guide walks you through setting up the basic parking facility widget for MetroParking. We're starting with a simple `.systemSmall` widget that shows:
- Facility name
- Available spaces / Total spaces
- Availability status with color indicator

## 🛠️ Step-by-Step Setup

### 1. Create Widget Extension Target

1. In Xcode: **File → New → Target**
2. Choose **Widget Extension**
3. Name: `MetroParkingWidget`
4. **Uncheck** "Include Live Activity" (we'll add this later)
5. Product Name: `MetroParkingWidget`
6. Click **Finish**
7. When prompted "Activate scheme?", click **Activate**

### 2. Configure App Groups

Both the main app and widget need access to shared data via App Groups.

#### Main App Target:
1. Select your **MetroParking** target
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **App Groups**
5. Click the **+** button
6. Enter: `group.com.yourteam.MetroParking` (replace `yourteam` with your team ID or reverse domain)
7. Enable the checkbox

#### Widget Extension Target:
1. Select your **MetroParkingWidget** target
2. Repeat steps 2-7 above
3. **Make sure you use the EXACT same App Group identifier**

### 3. Update App Group Identifier in Code

In `SharedDataManager.swift`, update line 18:

```swift
static let appGroupIdentifier = "group.com.yourteam.MetroParking"
```

Replace with your actual App Group identifier from step 2.

### 4. Add Files to Widget Target

You need to share some files between the app and widget:

1. Select `SharedDataManager.swift` in Project Navigator
2. In File Inspector (right panel), under **Target Membership**, check **both**:
   - ✅ MetroParking
   - ✅ MetroParkingWidget

3. Repeat for these model files:
   - `ParkingFacility.swift`
   - `ParkingZone.swift`
   - Any extension files that `ParkingFacility` depends on

4. **Important**: Also add any utility extensions used by these models (like `String` extensions, color adapters, etc.)

### 5. Replace Widget Extension Code

1. Delete the auto-generated `MetroParkingWidget.swift` in the widget target
2. Add the new `MetroParkingWidget.swift` I created (already done ✅)

### 6. Test the Widget

#### In Simulator:
1. Run the **MetroParkingWidget** scheme
2. Choose your simulator
3. Widget should appear in the widget gallery

#### In App:
1. Run the **MetroParking** scheme
2. Navigate to a facility detail view
3. Tap the **"Set as Widget"** button in the toolbar
4. See the confirmation alert
5. Go to home screen → Add Widget → MetroParking → Parking Facility

## 📱 How It Works

### Data Flow

```
App → FacilityDetailView
    → "Set as Widget" button pressed
    → SharedDataManager.updateWidget(facility)
    → Saves to UserDefaults in App Group
    → Triggers WidgetCenter.reloadAllTimelines()
    
Widget → FacilityProvider.getTimeline()
      → SharedDataManager.loadWidgetData()
      → Reads from UserDefaults in App Group
      → Displays facility data
```

### Auto-Updates

The widget automatically updates when:
1. **User sets a facility**: Immediate update
2. **Facility data refreshes in app**: Auto-updates if that facility is shown in widget
3. **Timeline refresh**: Every 5 minutes (configurable)

### Files Added/Modified

#### New Files:
- ✅ `SharedDataManager.swift` - Handles data sharing between app and widget
- ✅ `MetroParkingWidget.swift` - Widget implementation

#### Modified Files:
- ✅ `FacilityDetailView.swift` - Added "Set as Widget" button
- ✅ `FacilityManager.swift` - Auto-updates widget on refresh

## 🎨 Widget Design

### System Small (Current Implementation)
```
┌─────────────────┐
│ 🅿️          🟢  │  ← Icon + Status
│                 │
│ Blacktown Stn   │  ← Facility name
│ 45/100          │  ← Vacancy
│ Available       │  ← Status text
└─────────────────┘
```

## 🚀 Next Steps

### Phase 2: Add More Widget Sizes

1. **System Medium** - Add ETA and distance
2. **System Large** - Add mini map
3. **Lock Screen** - Accessory widgets

### Phase 3: Nearby Facilities Widget

Create a list-style widget showing multiple nearby facilities.

### Phase 4: Live Activities

Add Live Activities for real-time parking tracking.

### Phase 5: App Intents

Add interactive configuration to let users pick facilities directly in the widget editor.

## 🐛 Troubleshooting

### Widget shows "No Facility Selected"
- Make sure you tapped "Set as Widget" in a facility detail view
- Check App Group identifier matches in both targets
- Verify `SharedDataManager.swift` is included in widget target

### Build errors about missing types
- Add required model files to widget target membership
- Check that all dependencies are available

### Data not updating
- Verify App Group identifier is correct
- Check that `WidgetCenter.shared.reloadAllTimelines()` is being called
- Look for print statements in Xcode console

### Widget crashes
- Check that all required files are in widget target
- Verify no UIKit-only code in shared files
- Make sure models are `Codable` where needed

## 📝 Notes

- **Keep widget code lightweight**: Widgets have memory and CPU limits
- **Handle missing data gracefully**: Always provide fallback states
- **Test on device**: Widgets behave differently on device vs simulator
- **Consider battery**: Refresh intervals affect battery life

## 🎯 Current Status

✅ Basic infrastructure setup
✅ System Small widget implemented
✅ App integration complete
✅ Auto-update on refresh
⏳ Medium/Large variants (next)
⏳ App Intents configuration (next)
⏳ Live Activities (later)

---

**Need help?** Check Apple's documentation:
- [Widgets Documentation](https://developer.apple.com/documentation/widgetkit)
- [App Groups](https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_security_application-groups)
