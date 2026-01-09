# Widget Implementation Checklist

## ✅ Pre-Implementation Setup

- [ ] Create Widget Extension target in Xcode
  - [ ] Named: `MetroParkingWidget`
  - [ ] Unchecked "Include Live Activity"
  - [ ] Activated the scheme

## ✅ App Groups Configuration

- [ ] Main app has App Groups capability
- [ ] Widget extension has App Groups capability  
- [ ] Both use **identical** App Group identifier
- [ ] Updated `SharedDataManager.appGroupIdentifier` with actual ID

## ✅ File Target Membership

Add these files to **both** app and widget targets:

- [ ] `SharedDataManager.swift`
- [ ] `ParkingFacility.swift`
- [ ] `ParkingZone.swift`
- [ ] Any String extensions (check imports in ParkingFacility)
- [ ] Any Color extensions (if used)

**How to check:**
1. Select file in Project Navigator
2. View File Inspector (right panel)
3. Check **Target Membership** section
4. Ensure both MetroParking ✅ and MetroParkingWidget ✅

## ✅ Code Integration

- [ ] `MetroParkingWidget.swift` added to widget target
- [ ] `FacilityDetailView.swift` updated with "Set as Widget" button
- [ ] `FacilityManager.swift` calls `updateWidgetIfSelected()` on refresh

## ✅ Testing

### Basic Functionality
- [ ] Widget builds without errors
- [ ] Widget runs in simulator
- [ ] Widget appears in widget gallery
- [ ] Main app builds and runs

### Widget Setting
- [ ] Open facility detail in app
- [ ] Tap "Set as Widget" button
- [ ] See confirmation alert
- [ ] Add widget to home screen
- [ ] Widget shows facility data

### Data Updates
- [ ] Widget shows correct initial data
- [ ] Pull to refresh in app updates widget
- [ ] Widget auto-refreshes after 5 minutes
- [ ] Selecting different facility updates widget

### Edge Cases
- [ ] Widget shows empty state when no facility selected
- [ ] Widget handles missing ETA data
- [ ] Widget shows correct status colors
  - [ ] Green for available
  - [ ] Yellow for almost full
  - [ ] Red for full
  - [ ] Gray for no data

## ✅ Build Variants

Test on:
- [ ] Debug build
- [ ] Release build (important for App Store)
- [ ] Simulator
- [ ] Physical device (if available)

## 🐛 Common Issues & Solutions

### Issue: "No such module WidgetKit"
**Solution:** Make sure widget target has WidgetKit framework linked

### Issue: Widget shows placeholder forever
**Solution:** Check App Group identifier matches in both targets

### Issue: Build errors about missing types
**Solution:** Add missing files to widget target membership

### Issue: Widget doesn't update
**Solution:** 
- Verify `WidgetCenter.shared.reloadAllTimelines()` is called
- Check UserDefaults suite name matches App Group identifier
- Print debug statements to verify data is being saved

### Issue: Crash on launch
**Solution:**
- Check all model dependencies are in widget target
- Verify no UIKit-only code in shared files
- Make sure `@MainActor` functions are called properly

## 📊 Verification Steps

1. **Clean Build Folder**: Product → Clean Build Folder (Shift+Cmd+K)
2. **Delete Derived Data**: 
   - Xcode → Settings → Locations → Derived Data
   - Click arrow to open folder
   - Delete all contents
3. **Rebuild**: Cmd+B
4. **Run Widget Scheme**: Select MetroParkingWidget scheme, run
5. **Run App Scheme**: Select MetroParking scheme, run

## 🎯 Success Criteria

Widget is working correctly when:
- ✅ Builds without warnings or errors
- ✅ Displays in widget gallery
- ✅ Shows facility name, vacancy, and status
- ✅ Colors match availability status
- ✅ Updates when "Set as Widget" is tapped
- ✅ Auto-refreshes on app data update
- ✅ Shows empty state when appropriate

## 📝 Next Phase Prep

Once basic widget is working:
- [ ] Document any custom requirements
- [ ] Note any performance issues
- [ ] List desired features for medium/large widgets
- [ ] Consider design improvements
- [ ] Plan App Intents configuration approach

---

**Status**: 
- Current Phase: 1 - Basic Widget ⚠️ In Progress
- Next Phase: 2 - Medium/Large Variants
- Future: 3 - Nearby List Widget, 4 - Live Activities

**Last Updated**: December 16, 2025
