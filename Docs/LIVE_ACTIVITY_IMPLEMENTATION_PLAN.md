# Live Activity Implementation Plan

## Overview
This document outlines the implementation plan for Live Activity support in MetroParking, enabling users to monitor parking vacancy in real-time from the Lock Screen and Dynamic Island.

**Target Version**: 0.5.0 (January 2025)
**Estimated Complexity**: Medium (3-4 implementation sessions)
**Priority**: High (roadmap feature, better UX than notifications)
**iOS Requirement**: iOS 16.1+ (ActivityKit availability)

---

## 1. What Are Live Activities?

**Live Activities** provide always-visible, real-time information on the Lock Screen and Dynamic Island (iPhone 14 Pro+). Perfect for:
- Real-time parking vacancy monitoring
- Glanceable information without opening app
- Dynamic updates as parking fills/empties
- No notification spam - just live data

**Key Differences from Widgets:**
| Feature | Widgets | Live Activities |
|---------|---------|-----------------|
| Location | Home Screen | Lock Screen + Dynamic Island |
| Updates | Timeline-based, budget-limited | Event-driven, frequent updates allowed |
| Lifecycle | Always present | Started/stopped by user action |
| Duration | Permanent | Up to 8 hours (12 hours with push) |
| User Interaction | Tap to open app | Tap to open app + custom actions |

---

## 2. Use Cases for MetroParking

### Primary Use Case: Morning Commute Monitoring
**Scenario**: User is getting ready for work and wants to track parking at their station.

1. User pins their favorite facility (e.g., "Sutherland Station")
2. User starts Live Activity from app
3. Lock Screen shows:
   - Facility name
   - Available spaces (e.g., "15 / 120 spaces")
   - Last update time
   - Capacity indicator (progress bar)
4. Dynamic Island shows compact view with just space count
5. Live Activity updates every 1-2 minutes via background refresh
6. User glances at Lock Screen while getting ready
7. When satisfied with vacancy, user taps to open app and get directions
8. Live Activity ends when user arrives or after 8 hours

### Secondary Use Cases
- **Event Parking**: Monitor Park&Ride for concerts/games
- **Multi-Facility Tracking**: Switch between facilities without opening app
- **Share with Family**: Start Live Activity, family members see on shared devices
- **Commute Home**: Track parking near destination station

---

## 3. Technical Architecture

### 3.1 Components to Create

```
MetroParking/
├── LiveActivityExtension/                     # New target
│   ├── LiveActivityExtension.swift            # Activity widget entry point
│   ├── ParkingLiveActivityView.swift          # Lock Screen UI
│   ├── ParkingDynamicIslandView.swift         # Dynamic Island UI
│   └── Info.plist
│
├── MetroParking/
│   ├── Models/
│   │   └── ParkingActivityAttributes.swift    # ActivityKit attributes
│   │
│   ├── Managers/
│   │   └── LiveActivityManager.swift          # Start/stop/update activities
│   │
│   ├── Views/
│   │   └── LiveActivityControlView.swift      # In-app control UI
│   │
│   └── Utils/
│       └── LiveActivityUpdateCoordinator.swift # Background update coordination
│
└── Shared/                                     # New shared code folder
    └── ParkingActivityAttributes.swift         # Shared between app + extension
```

### 3.2 Files to Modify

**Project Configuration**:
- `MetroParking.xcodeproj`: Add new Live Activity extension target
- `MetroParking.entitlements`: Add Live Activity entitlement
- `Info.plist`: Add `NSSupportsLiveActivities` key

**Managers**:
- `BackgroundTaskManager.swift`: Add Live Activity updates to refresh cycle
- `FacilityManager.swift`: Trigger Live Activity updates on data changes
- `SharedDataManager.swift`: Provide shared container for Live Activity extension

**Views**:
- `FacilityDetailView.swift`: Add "Start Live Activity" button
- `FacilityListView.swift`: Add quick-start from list (long press)

---

## 4. Implementation Plan

### Phase 1: ActivityKit Setup (Session 1)

#### Step 1.1: Create Live Activity Extension Target

**Xcode Steps**:
1. File → New → Target
2. Select "Widget Extension"
3. Name: `LiveActivityExtension`
4. Check "Include Live Activity"
5. Language: Swift
6. Deployment Target: iOS 16.1+

**Project Configuration**:
```xml
<!-- LiveActivityExtension/Info.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN">
<plist version="1.0">
<dict>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.widgetkit-extension</string>
    </dict>
    <key>NSSupportsLiveActivities</key>
    <true/>
</dict>
</plist>
```

**Entitlements**:
```xml
<!-- MetroParking.entitlements - Add this key -->
<key>com.apple.developer.usernotifications.live-activities</key>
<true/>

<!-- LiveActivityExtension.entitlements - New file -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.tomkwok.MetroParking</string>
    </array>
    <key>com.apple.developer.usernotifications.live-activities</key>
    <true/>
</dict>
</plist>
```

**Why**: Live Activity extensions require specific entitlements and project configuration.

#### Step 1.2: Define Activity Attributes

Create shared attributes model:

```swift
// Shared/ParkingActivityAttributes.swift
// IMPORTANT: Add to BOTH app target and LiveActivityExtension target

import ActivityKit
import Foundation

/// Attributes defining a parking Live Activity
/// Static data that doesn't change during the activity's lifetime
struct ParkingActivityAttributes: ActivityAttributes {

    /// Dynamic state that updates during the activity
    public struct ContentState: Codable, Hashable {
        /// Current number of available parking spaces
        var availableSpaces: Int

        /// Total parking capacity
        var totalSpaces: Int

        /// Current number of occupied spaces
        var occupiedSpaces: Int

        /// Timestamp of last data update
        var lastUpdate: Date

        /// Optional status message (e.g., "Data may be stale")
        var statusMessage: String?

        /// Computed properties
        var occupancyPercentage: Double {
            guard totalSpaces > 0 else { return 0 }
            return Double(occupiedSpaces) / Double(totalSpaces)
        }

        var isNearlyFull: Bool {
            availableSpaces < 10
        }

        var isFull: Bool {
            availableSpaces == 0
        }
    }

    // MARK: - Static Attributes (immutable during activity lifetime)

    /// Facility ID
    var facilityId: String

    /// Facility display name (e.g., "Sutherland")
    var facilityName: String

    /// Facility subtitle (e.g., "Station")
    var facilitySubtitle: String

    /// Full facility name (e.g., "Sutherland Station Park&Ride")
    var fullName: String
}
```

**Why**:
- `ActivityAttributes` defines static + dynamic data for Live Activities
- Static data (facility name) never changes, dynamic data (spaces) updates frequently
- Shared between app (starts activity) and extension (renders UI)

#### Step 1.3: Add Logger Category

```swift
// Add to MetroParking/Utils/Logger.swift

extension Logger {
    static let liveActivity = Logger(
        subsystem: "com.tomkwok.MetroParking",
        category: "live-activity"
    )
}
```

---

### Phase 2: Live Activity Manager (Session 2)

#### Step 2.1: Create LiveActivityManager

```swift
// MetroParking/Managers/LiveActivityManager.swift

import ActivityKit
import Foundation
import OSLog
import SwiftData

@MainActor
@Observable
final class LiveActivityManager {

    static let shared = LiveActivityManager()

    // MARK: - State

    /// Currently active Live Activity
    private(set) var currentActivity: Activity<ParkingActivityAttributes>?

    /// Whether a Live Activity is currently running
    var isActivityActive: Bool {
        currentActivity != nil && currentActivity?.activityState == .active
    }

    /// Current facility being tracked
    private(set) var trackedFacilityId: String?

    private init() {
        // Observe activity state changes
        Task {
            await observeActivityState()
        }
    }

    // MARK: - Start Activity

    /// Start a Live Activity for a facility
    /// - Parameter facility: The facility to track
    /// - Returns: Success status
    @discardableResult
    func startActivity(for facility: ParkingFacility) async -> Bool {
        // End any existing activity first
        await endCurrentActivity()

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            Logger.liveActivity.warning("Live Activities not enabled in system settings")
            return false
        }

        let attributes = ParkingActivityAttributes(
            facilityId: facility.facilityId,
            facilityName: facility.displayName.title,
            facilitySubtitle: facility.displayName.subtitle,
            fullName: facility.name
        )

        let initialState = ParkingActivityAttributes.ContentState(
            availableSpaces: facility.vacancy.available,
            totalSpaces: facility.vacancy.total,
            occupiedSpaces: facility.vacancy.occupied,
            lastUpdate: facility.vacancy.lastUpdate ?? Date(),
            statusMessage: nil
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil // Local updates only (can add .token for remote updates later)
            )

            self.currentActivity = activity
            self.trackedFacilityId = facility.facilityId

            Logger.liveActivity.info("✅ Started Live Activity for \(facility.name)")
            return true

        } catch {
            Logger.liveActivity.error("❌ Failed to start Live Activity: \(error)")
            return false
        }
    }

    // MARK: - Update Activity

    /// Update the current Live Activity with new data
    /// - Parameter facility: Updated facility data
    func updateActivity(with facility: ParkingFacility) async {
        guard let activity = currentActivity,
              activity.activityState == .active,
              trackedFacilityId == facility.facilityId else {
            return
        }

        let newState = ParkingActivityAttributes.ContentState(
            availableSpaces: facility.vacancy.available,
            totalSpaces: facility.vacancy.total,
            occupiedSpaces: facility.vacancy.occupied,
            lastUpdate: facility.vacancy.lastUpdate ?? Date(),
            statusMessage: getStatusMessage(for: facility)
        )

        await activity.update(
            .init(
                state: newState,
                staleDate: Calendar.current.date(byAdding: .minute, value: 15, to: Date())
            )
        )

        Logger.liveActivity.debug("🔄 Updated Live Activity: \(facility.vacancy.available) spaces")
    }

    /// Update Live Activity with explicit state
    /// - Parameter state: New content state
    func updateActivity(with state: ParkingActivityAttributes.ContentState) async {
        guard let activity = currentActivity,
              activity.activityState == .active else {
            return
        }

        await activity.update(
            .init(
                state: state,
                staleDate: Calendar.current.date(byAdding: .minute, value: 15, to: Date())
            )
        )

        Logger.liveActivity.debug("🔄 Updated Live Activity with custom state")
    }

    // MARK: - End Activity

    /// End the current Live Activity
    /// - Parameter dismissalPolicy: When to dismiss (.immediate, .default, or .after(Date))
    func endCurrentActivity(dismissalPolicy: ActivityUIDismissalPolicy = .default) async {
        guard let activity = currentActivity else { return }

        let finalState = activity.content.state

        await activity.end(
            .init(state: finalState, staleDate: nil),
            dismissalPolicy: dismissalPolicy
        )

        Logger.liveActivity.info("🛑 Ended Live Activity")

        self.currentActivity = nil
        self.trackedFacilityId = nil
    }

    // MARK: - Helpers

    private func getStatusMessage(for facility: ParkingFacility) -> String? {
        // Check if data is stale (older than 5 minutes)
        if let lastUpdate = facility.vacancy.lastUpdate,
           Date().timeIntervalSince(lastUpdate) > 300 {
            return "Data may be stale"
        }

        // Check if facility is nearly full
        if facility.vacancy.available < 5 && facility.vacancy.available > 0 {
            return "Almost full"
        }

        // Check if full
        if facility.vacancy.available == 0 {
            return "No spaces available"
        }

        return nil
    }

    private func observeActivityState() async {
        guard let activity = currentActivity else { return }

        for await state in activity.activityStateUpdates {
            Logger.liveActivity.info("Live Activity state changed: \(String(describing: state))")

            if state == .dismissed || state == .ended {
                self.currentActivity = nil
                self.trackedFacilityId = nil
            }
        }
    }
}
```

**Why**: Centralized management of Live Activity lifecycle with proper state tracking.

---

### Phase 3: Live Activity UI (Session 3)

#### Step 3.1: Lock Screen View

```swift
// LiveActivityExtension/ParkingLiveActivityView.swift

import SwiftUI
import WidgetKit

@available(iOS 16.1, *)
struct ParkingLiveActivityView: View {
    let context: ActivityViewContext<ParkingActivityAttributes>

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "parkingsign.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.facilityName)
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text(context.attributes.facilitySubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Status badge
                if let status = context.state.statusMessage {
                    Text(status)
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange, in: Capsule())
                }
            }

            // Main content
            HStack(spacing: 20) {
                // Available spaces
                VStack(spacing: 4) {
                    Text("\(context.state.availableSpaces)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(spaceColor)
                        .contentTransition(.numericText())

                    Text("Available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Capacity bar
                VStack(alignment: .leading, spacing: 8) {
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.quaternary)

                            // Fill
                            RoundedRectangle(cornerRadius: 4)
                                .fill(capacityGradient)
                                .frame(width: geometry.size.width * context.state.occupancyPercentage)
                        }
                    }
                    .frame(height: 8)

                    // Capacity text
                    HStack {
                        Text("\(context.state.occupiedSpaces) / \(context.state.totalSpaces)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("\(Int(context.state.occupancyPercentage * 100))% Full")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Footer
            HStack {
                Image(systemName: "clock")
                    .font(.caption2)

                Text("Updated \(context.state.lastUpdate, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()
            }
        }
        .padding(16)
        .activityBackgroundTint(.clear)
        .activitySystemActionForegroundColor(.blue)
    }

    // MARK: - Computed Properties

    private var spaceColor: Color {
        if context.state.isFull {
            return .red
        } else if context.state.isNearlyFull {
            return .orange
        } else {
            return .green
        }
    }

    private var capacityGradient: LinearGradient {
        let percentage = context.state.occupancyPercentage

        if percentage >= 0.9 {
            return LinearGradient(colors: [.red, .red.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
        } else if percentage >= 0.7 {
            return LinearGradient(colors: [.orange, .orange.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
        }
    }
}
```

**Why**: Clean, glanceable Lock Screen UI with color-coded availability and capacity visualization.

#### Step 3.2: Dynamic Island View

```swift
// LiveActivityExtension/ParkingDynamicIslandView.swift

import SwiftUI
import WidgetKit

@available(iOS 16.2, *)
struct ParkingDynamicIslandView: View {
    let context: ActivityViewContext<ParkingActivityAttributes>

    var body: some View {
        DynamicIsland {
            // Expanded view
            DynamicIslandExpandedRegion(.leading) {
                Image(systemName: "parkingsign.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }

            DynamicIslandExpandedRegion(.trailing) {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(context.state.availableSpaces)")
                        .font(.title.bold())
                        .foregroundStyle(spaceColor)
                        .contentTransition(.numericText())

                    Text("Available")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            DynamicIslandExpandedRegion(.center) {
                VStack(spacing: 8) {
                    Text(context.attributes.facilityName)
                        .font(.headline)

                    // Capacity bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.quaternary)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(capacityGradient)
                                .frame(width: geometry.size.width * context.state.occupancyPercentage)
                        }
                    }
                    .frame(height: 6)

                    Text("\(context.state.occupiedSpaces) / \(context.state.totalSpaces) spaces")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            DynamicIslandExpandedRegion(.bottom) {
                HStack {
                    Image(systemName: "clock")
                    Text("Updated \(context.state.lastUpdate, style: .relative) ago")
                    Spacer()
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

        } compactLeading: {
            // Compact leading (parking icon)
            Image(systemName: "parkingsign.circle.fill")
                .foregroundStyle(.blue)
        } compactTrailing: {
            // Compact trailing (space count)
            Text("\(context.state.availableSpaces)")
                .font(.caption.bold())
                .foregroundStyle(spaceColor)
                .contentTransition(.numericText())
        } minimal: {
            // Minimal view (just icon with color indicator)
            Image(systemName: "parkingsign.circle.fill")
                .foregroundStyle(spaceColor)
        }
    }

    private var spaceColor: Color {
        if context.state.isFull {
            return .red
        } else if context.state.isNearlyFull {
            return .orange
        } else {
            return .green
        }
    }

    private var capacityGradient: LinearGradient {
        let percentage = context.state.occupancyPercentage

        if percentage >= 0.9 {
            return LinearGradient(colors: [.red, .red.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
        } else if percentage >= 0.7 {
            return LinearGradient(colors: [.orange, .orange.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
        }
    }
}
```

**Why**: Dynamic Island provides ultra-compact glanceable information for iPhone 14 Pro+ users.

#### Step 3.3: Activity Widget Entry Point

```swift
// LiveActivityExtension/LiveActivityExtension.swift

import ActivityKit
import SwiftUI
import WidgetKit

@main
struct ParkingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ParkingActivityAttributes.self) { context in
            // Lock Screen view
            ParkingLiveActivityView(context: context)
        } dynamicIsland: { context in
            // Dynamic Island view
            if #available(iOS 16.2, *) {
                ParkingDynamicIslandView(context: context)
            } else {
                // Fallback for iOS 16.1
                DynamicIsland {
                    DynamicIslandExpandedRegion(.center) {
                        Text("Parking: \(context.state.availableSpaces) spaces")
                    }
                } compactLeading: {
                    Image(systemName: "parkingsign")
                } compactTrailing: {
                    Text("\(context.state.availableSpaces)")
                } minimal: {
                    Image(systemName: "parkingsign")
                }
            }
        }
    }
}
```

**Why**: Registers the Live Activity widget with the system.

---

### Phase 4: Integration & Background Updates (Session 4)

#### Step 4.1: Integrate with FacilityManager

```swift
// Add to FacilityManager.swift

/// Update Live Activity if tracking this facility
private func updateLiveActivityIfNeeded(for facility: ParkingFacility) async {
    guard LiveActivityManager.shared.isActivityActive,
          LiveActivityManager.shared.trackedFacilityId == facility.facilityId else {
        return
    }

    await LiveActivityManager.shared.updateActivity(with: facility)
}

// Call from performLoad() after updating facility occupancy:
await updateLiveActivityIfNeeded(for: facility)
```

#### Step 4.2: Integrate with BackgroundTaskManager

```swift
// Add to BackgroundTaskManager.swift

private func performQuickRefresh() async {
    // ... existing refresh logic ...

    // Update Live Activity if active
    if let trackedId = LiveActivityManager.shared.trackedFacilityId {
        if let facility = facilities.first(where: { $0.facilityId == trackedId }) {
            await LiveActivityManager.shared.updateActivity(with: facility)
        }
    }
}
```

#### Step 4.3: In-App Control UI

```swift
// MetroParking/Views/LiveActivityControlView.swift

@available(iOS 16.1, *)
struct LiveActivityControlView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LiveActivityManager.self) private var activityManager

    let facility: ParkingFacility

    var body: some View {
        VStack(spacing: 12) {
            if activityManager.isActivityActive &&
               activityManager.trackedFacilityId == facility.facilityId {
                // Active state
                VStack(spacing: 8) {
                    Label("Live Activity Active", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)

                    Text("Tracking on Lock Screen")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button(role: .destructive) {
                        Task {
                            await activityManager.endCurrentActivity()
                        }
                    } label: {
                        Label("Stop Tracking", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            } else {
                // Inactive state
                Button {
                    Task {
                        await activityManager.startActivity(for: facility)
                    }
                } label: {
                    Label("Start Live Activity", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
```

#### Step 4.4: Add to FacilityDetailView

```swift
// Add to FacilityDetailView.swift, in the main VStack:

if #available(iOS 16.1, *) {
    LiveActivityControlView(facility: facility)
        .padding(.horizontal)
}
```

---

## 5. Testing Checklist

- [ ] Live Activity starts successfully from app
- [ ] Lock Screen shows correct facility data
- [ ] Dynamic Island shows compact view (iPhone 14 Pro+)
- [ ] Expanding Dynamic Island shows full details
- [ ] Data updates reflect in Live Activity within 1-2 min
- [ ] Background refresh updates Live Activity
- [ ] Tapping Live Activity opens app to facility detail
- [ ] Live Activity dismisses after manual end
- [ ] Live Activity auto-dismisses after 8 hours
- [ ] Multiple start/stop cycles work correctly
- [ ] Color indicators reflect capacity correctly
- [ ] "Updated X ago" timestamp is accurate
- [ ] Works on Lock Screen while device locked
- [ ] No memory leaks or crashes

---

## 6. Known Limitations

**System Constraints**:
- Live Activities limited to 8 hours (can extend to 12 hours with push notifications)
- Only one Live Activity per app type at a time
- System may kill Live Activity if device is low on resources
- No guaranteed update frequency - system controls scheduling

**Device Support**:
- Lock Screen: All devices iOS 16.1+
- Dynamic Island: iPhone 14 Pro/Max, iPhone 15 Pro/Max, iPhone 16 Pro/Max only
- Older devices show Lock Screen view only

**Data Freshness**:
- Updates depend on background app refresh
- May be delayed if system deprioritizes app
- Not suitable for second-by-second tracking

---

## 7. Future Enhancements

**v0.6.0+**:
- [ ] Push notification updates (extend to 12 hours)
- [ ] Custom actions (Get Directions, Pin Facility)
- [ ] Multiple facility tracking (switch between facilities)
- [ ] Historical chart in expanded view
- [ ] Smart auto-start (based on commute time/location)
- [ ] Siri integration ("Start tracking Sutherland parking")

---

## 8. Success Metrics

**Implementation Success**:
- [ ] Live Activity starts/stops reliably
- [ ] Updates occur within 2 minutes of data change
- [ ] No crashes or performance issues
- [ ] Clean UI rendering on all devices
- [ ] Proper lifecycle management

**User Experience Success**:
- [ ] Clear visual hierarchy
- [ ] Color indicators are intuitive
- [ ] Timestamp shows data freshness
- [ ] Easy to start/stop from app
- [ ] Works seamlessly with background refresh

---

## Contact

**Feature Owner**: Tom Kwok
**Implementation Target**: January 2025
**Last Updated**: December 28, 2025

---

*This plan assumes background refresh infrastructure is already in place. Live Activities will leverage existing `BackgroundTaskManager` and `FacilityManager` for data updates.*
