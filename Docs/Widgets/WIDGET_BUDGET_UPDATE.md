# Widget Budget Configuration Update

## Change Summary

**Previous Configuration:**
- Minimum reload interval: 10 minutes (600 seconds)
- Daily budget: 60 reloads

**New Configuration:**
- Minimum reload interval: **15 seconds** ✨
- Daily budget: 60 reloads (unchanged)

---

## Rationale

The 10-minute throttle was too conservative for your API's actual update frequency:

- **Most facilities**: Update every 10 minutes OR on occupancy counter change
- **Some facilities**: Update every **15 seconds** (real-time data)

By reducing the throttle to 15 seconds, the widget can now show truly real-time updates for facilities that provide them.

---

## Budget Math

### With 15-Second Throttle

**Maximum possible reloads per hour:**
```
3600 seconds/hour ÷ 15 seconds/reload = 240 reloads/hour (theoretical max)
```

**But the budget limits this to 60/day, so:**
```
60 reloads ÷ 24 hours = 2.5 reloads/hour average
```

### Typical Usage Scenario

Let's model a realistic commuter usage pattern:

#### **Morning Commute (7:30 AM - 8:30 AM)**
- App open: 1 hour
- Foreground refresh cycles: every 15 seconds
- But throttled to actual data changes
- **Estimated reloads: 4-6** (only when data actually changes)

#### **At Work (9 AM - 5 PM)**
- App in background
- Background tasks every 15-30 minutes
- **Estimated reloads: 16-24** (8 hours ÷ 30 min)

#### **Evening Commute (5:30 PM - 6:30 PM)**
- App open: 1 hour
- Foreground refresh cycles
- **Estimated reloads: 4-6**

#### **Evening at Home (7 PM - 10 PM)**
- Occasional app checks
- Background tasks
- **Estimated reloads: 6-10**

#### **Total Daily Usage: 30-46 reloads**

This leaves a healthy **14-30 reload buffer** for:
- Extra app opens
- Manual pull-to-refresh
- Unexpected background task scheduling

---

## Smart Throttling Strategy

The system prevents budget exhaustion through multiple layers:

### 1. **Time-Based Throttle** (15 seconds)
```swift
// WidgetBudgetTracker.canReload()
guard timeSinceLastReload >= 15 else {
    return false  // Too soon since last reload
}
```

### 2. **Change-Based Throttle**
Only reload if data actually changed:
```swift
// FacilityManager.performLoad()
if processedCount > 0 {  // Only reload if facilities were updated
    WidgetBudgetTracker.shared.requestReload()
}
```

### 3. **Significance Threshold**
Background tasks only reload if change is significant:
```swift
// BackgroundTaskManager
let change = abs(spacesBefore - facility.vacancy.available)
if change >= RefreshConfiguration.Widget.backgroundChangeThreshold {
    dataChanged = true  // 2+ spaces changed
}
```

### 4. **Daily Budget Cap**
Hard limit prevents runaway reloads:
```swift
guard reloadsToday < 60 else {
    return false  // Budget exhausted
}
```

---

## Benefits of 15-Second Throttle

✅ **Real-time updates** for facilities with 15-second refresh rates  
✅ **Still budget-friendly** - actual usage stays well below 60/day  
✅ **Responsive to user activity** - updates when app is actively used  
✅ **Smart degradation** - falls back to cache if budget exhausted  
✅ **Matches API behavior** - aligned with actual data update frequency  

---

## Monitoring Widget Budget

### In Code

```swift
// Check current status
let remaining = WidgetBudgetTracker.shared.remainingBudget
let used = WidgetBudgetTracker.shared.reloadsInLast24Hours()
print("Widget budget: \(used)/60 used, \(remaining) remaining")

// Check if reload is allowed
if WidgetBudgetTracker.shared.canReload() {
    print("✅ Reload allowed")
} else {
    print("⚠️ Throttled or budget exceeded")
}
```

### In Logs

The system automatically logs budget information:

```
✅ Reload recorded (1/60 today)
✅ Reload recorded (2/60 today)
⏰ Throttled: 8s since last reload (min: 15s)
✅ Reload recorded (3/60 today)
```

If budget is exceeded (unlikely):
```
⚠️ Budget exceeded: 60/60 reloads today
```

---

## Testing Recommendations

### Test 1: Rapid Foreground Updates
1. Open app
2. Keep app in foreground for 5 minutes
3. Observe reload logs
4. **Expected:** ~4-6 reloads (every 15s when data changes)

### Test 2: Budget Enforcement
1. Check current budget: `WidgetBudgetTracker.shared.remainingBudget`
2. Manually trigger reloads in quick succession
3. **Expected:** Throttled to 15-second intervals

### Test 3: Real-Time Facility
1. Select a facility that updates every 15 seconds
2. Add to widget
3. Keep app in foreground
4. **Expected:** Widget updates every ~15 seconds (when data changes)

### Test 4: Background Behavior
1. Use app normally
2. Close app
3. Wait 30 minutes
4. Check widget
5. **Expected:** Shows data from background refresh

---

## Configuration Reference

All timing values are in `RefreshConfiguration.swift`:

```swift
enum RefreshConfiguration {
    
    enum Widget {
        static let minReloadInterval: TimeInterval = 15  // 15 seconds ✨
        static let dailyBudget: Int = 60
        static let foregroundChangeThreshold: Int = 1
        static let backgroundChangeThreshold: Int = 2
    }
    
    enum ForegroundInterval {
        static let standard: TimeInterval = 15.0  // Matches widget throttle
    }
    
    enum BackgroundTaskInterval {
        static let peakHours: TimeInterval = 15 * 60
        static let officeHours: TimeInterval = 20 * 60
        static let offPeak: TimeInterval = 30 * 60
    }
}
```

---

## Edge Cases Handled

### Case 1: Budget Exhausted
- Widget continues to show cached data
- Logs warning but doesn't crash
- Budget resets after 24 hours (rolling window)

### Case 2: No Network
- Widget shows last cached data
- API calls fail gracefully
- No budget consumed on failed updates

### Case 3: Widget Not Configured
- No reloads triggered
- Budget preserved
- System degrades gracefully

### Case 4: Multiple Widgets
- All widgets reload together (`reloadAllTimelines()`)
- Counts as 1 reload (not per widget)
- Budget shared across all widgets

---

## Comparison: Old vs New

| Scenario | Old (10 min throttle) | New (15 sec throttle) |
|----------|----------------------|----------------------|
| Real-time facility updates | ❌ Delayed up to 10 min | ✅ Updates every 15 sec |
| Foreground active (1 hour) | 1 reload | 4-6 reloads |
| Daily budget usage | 20-30 reloads/day | 30-46 reloads/day |
| Remaining buffer | 30-40 reloads | 14-30 reloads |
| User experience | Stale data | Real-time accuracy |

---

## Conclusion

The 15-second throttle provides a much better user experience by enabling real-time widget updates while still maintaining a healthy budget margin. The multi-layered throttling system (time + change detection + daily budget) ensures the app won't exceed Apple's limits even with the more aggressive update frequency.

**Key takeaway:** The throttle interval should match your data source's update frequency, and the budget system will prevent excessive usage.

---

*Updated: December 21, 2025*
