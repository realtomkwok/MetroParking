# Onboarding & Settings Implementation Plan

## Overview
This document outlines the implementation plan for two major features:
1. **Onboarding Screen**: First-time user experience using a sheet presentation
2. **Settings Menu**: Populated settings items in the top toolbar menu

**Target Completion**: January 2025
**Estimated Complexity**: Medium (3-4 implementation sessions)

---

## 1. Onboarding Screen Implementation

### 1.1 Design Approach
Similar to [WhatsNewKit](https://github.com/SvenTiigi/WhatsNewKit), we'll create a sheet-based onboarding flow that:
- Displays on first launch only
- Uses SwiftUI `.sheet()` modifier with environment-controlled state
- Allows users to dismiss and proceed to the main app
- Can be re-triggered from Settings for reference

### 1.2 Architecture Changes

#### **New Files to Create**
```
MetroParking/
├── Views/
│   ├── Onboarding/
│   │   ├── OnboardingView.swift           # Main onboarding container
│   │   ├── OnboardingPageView.swift       # Individual page component
│   │   └── OnboardingPage.swift           # Page data model
│   └── Settings/
│       ├── SettingsView.swift             # Main settings screen
│       ├── NotificationsSettingsView.swift # Notifications settings
│       ├── WidgetsSettingsView.swift      # Widget configuration guide
│       ├── LiveActivitiesSettingsView.swift # Live Activities settings
│       └── AboutView.swift                # About & credits
├── Managers/
│   └── OnboardingManager.swift            # Onboarding state management
└── Utils/
    └── UserPreferences.swift              # @AppStorage wrapper for user settings
```

#### **Files to Modify**
- `MetroParking/ContentView.swift`: Add `.sheet()` modifier for onboarding
- `MetroParking/MetroParkingApp.swift`: Initialize `OnboardingManager` in environment
- `CLAUDE.md`: Update project structure and feature documentation
- `README.md`: Update features list and changelog

### 1.3 Implementation Steps

#### **Step 1: User Preferences Infrastructure**
Create `UserPreferences.swift` to manage persistent settings:

```swift
import SwiftUI

@Observable
final class UserPreferences {
    static let shared = UserPreferences()

    // Onboarding
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false

    // Notifications
    @AppStorage("notificationsEnabled") var notificationsEnabled: Bool = false
    @AppStorage("vacancyThreshold") var vacancyThreshold: Int = 10

    // Widgets
    @AppStorage("widgetsConfigured") var widgetsConfigured: Bool = false

    // App Preferences
    @AppStorage("preferredSortOption") var preferredSortOption: String = "distance"
    @AppStorage("enableHaptics") var enableHaptics: Bool = true

    private init() {}
}
```

**Why**: Centralized user preferences using `@AppStorage` for persistence across app launches.

---

#### **Step 2: Onboarding Manager**
Create `OnboardingManager.swift` for state management:

```swift
import SwiftUI

@MainActor
@Observable
final class OnboardingManager {
    static let shared = OnboardingManager()

    var isShowingOnboarding: Bool = false
    var currentPage: Int = 0

    private init() {
        // Show onboarding if not completed
        self.isShowingOnboarding = !UserPreferences.shared.hasCompletedOnboarding
    }

    func completeOnboarding() {
        UserPreferences.shared.hasCompletedOnboarding = true
        isShowingOnboarding = false
    }

    func showOnboarding() {
        isShowingOnboarding = true
        currentPage = 0
    }

    func nextPage() {
        currentPage += 1
    }

    func previousPage() {
        guard currentPage > 0 else { return }
        currentPage -= 1
    }
}
```

**Why**: Separates onboarding logic from view layer, allows for programmatic control.

---

#### **Step 3: Onboarding Page Model**
Create `OnboardingPage.swift`:

```swift
import SwiftUI

struct OnboardingPage: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let systemImage: String
    let gradientColors: [Color]

    static let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Welcome to MetroParking",
            description: "Find real-time parking availability at 37 NSW Transport Park&Ride facilities.",
            systemImage: "parkingsign.circle.fill",
            gradientColors: [.blue, .cyan]
        ),
        OnboardingPage(
            title: "Pin Your Favorites",
            description: "Save frequently used facilities for quick access and priority updates.",
            systemImage: "pin.fill",
            gradientColors: [.purple, .pink]
        ),
        OnboardingPage(
            title: "Live Widgets",
            description: "Add home screen widgets to monitor your favorite facilities at a glance.",
            systemImage: "square.grid.2x2.fill",
            gradientColors: [.orange, .red]
        ),
        OnboardingPage(
            title: "Smart Notifications",
            description: "Get alerts when parking spots become available at your selected facilities.",
            systemImage: "bell.badge.fill",
            gradientColors: [.green, .mint]
        ),
        OnboardingPage(
            title: "Get Started",
            description: "Start finding parking and make your commute easier.",
            systemImage: "hand.wave.fill",
            gradientColors: [.indigo, .blue]
        )
    ]
}
```

**Why**: Defines content structure, easily extensible for new pages.

---

#### **Step 4: Onboarding Page View**
Create `OnboardingPageView.swift`:

```swift
import SwiftUI

@available(iOS 26.0, *)
struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            Image(systemName: page.systemImage)
                .font(.system(size: 100))
                .foregroundStyle(
                    LinearGradient(
                        colors: page.gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(.bounce, value: page.id)

            VStack(spacing: 16) {
                // Title
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                // Description
                Text(page.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
        .padding()
    }
}
```

**Why**: Reusable page component with consistent styling.

---

#### **Step 5: Main Onboarding View**
Create `OnboardingView.swift`:

```swift
import SwiftUI

@available(iOS 26.0, *)
struct OnboardingView: View {
    @Environment(OnboardingManager.self) private var onboardingManager
    @Environment(\.dismiss) private var dismiss

    private let pages = OnboardingPage.pages

    var body: some View {
        ZStack {
            // Background
            BackgroundGradient()

            VStack(spacing: 0) {
                // Page Content
                TabView(selection: $onboardingManager.currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                // Bottom Controls
                VStack(spacing: 16) {
                    if onboardingManager.currentPage == pages.count - 1 {
                        // Get Started Button
                        Button {
                            onboardingManager.completeOnboarding()
                            dismiss()
                        } label: {
                            Text("Get Started")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    } else {
                        // Next & Skip Buttons
                        HStack {
                            Button("Skip") {
                                onboardingManager.completeOnboarding()
                                dismiss()
                            }
                            .foregroundStyle(.secondary)

                            Spacer()

                            Button {
                                withAnimation {
                                    onboardingManager.nextPage()
                                }
                            } label: {
                                Text("Next")
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .interactiveDismissDisabled()
    }
}
```

**Why**: Full-screen onboarding flow with navigation controls.

---

#### **Step 6: Integrate with ContentView**
Modify `ContentView.swift`:

```swift
// Add to ContentView body, after NavigationStack
.sheet(isPresented: $onboardingManager.isShowingOnboarding) {
    if #available(iOS 26.0, *) {
        OnboardingView()
            .environment(onboardingManager)
    }
}

// Add environment object at top of ContentView
@Environment(OnboardingManager.self) private var onboardingManager
```

**Why**: Sheet presentation allows dismissal and doesn't block navigation stack.

---

#### **Step 7: Update MetroParkingApp.swift**
Add `OnboardingManager` to environment:

```swift
.environment(OnboardingManager.shared)
.environment(UserPreferences.shared)
```

**Why**: Makes managers available throughout the app via environment.

---

### 1.4 Testing Checklist
- [ ] Onboarding appears on first launch
- [ ] Pages navigate forward/backward correctly
- [ ] "Skip" button completes onboarding
- [ ] "Get Started" button completes onboarding
- [ ] Onboarding doesn't appear on subsequent launches
- [ ] Can trigger onboarding from Settings → About
- [ ] Sheet dismissal works correctly
- [ ] TabView pagination works smoothly
- [ ] Background gradient displays correctly

---

## 2. Settings Menu Implementation

### 2.1 Menu Structure
Expand the toolbar menu (ContentView.swift:149-167) with the following sections:

```
Settings Menu
├── Settings
│   ├── Notifications (→ NotificationsSettingsView)
│   ├── Widgets (→ WidgetsSettingsView)
│   ├── Live Activities (→ LiveActivitiesSettingsView)
│   └── Preferences (→ PreferencesSettingsView)
├── About
│   ├── About MetroParking (→ AboutView)
│   ├── Show Onboarding Again
│   └── Privacy Policy
└── Developer (Debug only)
    └── API Debug (existing)
```

### 2.2 Implementation Steps

#### **Step 1: Create NotificationsSettingsView**
```swift
import SwiftUI
import UserNotifications

@available(iOS 26.0, *)
struct NotificationsSettingsView: View {
    @Environment(UserPreferences.self) private var preferences
    @State private var notificationAuthStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        Form {
            Section {
                Toggle("Enable Notifications", isOn: $preferences.notificationsEnabled)
                    .onChange(of: preferences.notificationsEnabled) { _, newValue in
                        if newValue {
                            requestNotificationPermission()
                        }
                    }
            } header: {
                Text("Notification Settings")
            } footer: {
                Text("Receive alerts when parking spaces become available.")
            }

            if preferences.notificationsEnabled {
                Section("Vacancy Alerts") {
                    Stepper("Alert when under \(preferences.vacancyThreshold) spaces",
                            value: $preferences.vacancyThreshold,
                            in: 5...50,
                            step: 5)

                    Text("You'll receive a notification when your pinned facilities have fewer than \(preferences.vacancyThreshold) available spaces.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } header: {
                Text("System Settings")
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await checkNotificationStatus()
        }
    }

    private func requestNotificationPermission() {
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .badge, .sound])

                if !granted {
                    preferences.notificationsEnabled = false
                }
            } catch {
                Logger.shared.error("Failed to request notification permission: \(error)")
                preferences.notificationsEnabled = false
            }
        }
    }

    private func checkNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationAuthStatus = settings.authorizationStatus
    }
}
```

**Why**: Handles notification permissions and user preferences for alerts.

---

#### **Step 2: Create WidgetsSettingsView**
```swift
import SwiftUI

@available(iOS 26.0, *)
struct WidgetsSettingsView: View {
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Widget Support", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)

                    Text("MetroParking widgets are available for your home screen and lock screen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("How to Add a Widget") {
                InstructionRow(
                    number: "1",
                    text: "Long press on your home screen"
                )
                InstructionRow(
                    number: "2",
                    text: "Tap the '+' button in the top corner"
                )
                InstructionRow(
                    number: "3",
                    text: "Search for 'MetroParking'"
                )
                InstructionRow(
                    number: "4",
                    text: "Select a widget size and tap 'Add Widget'"
                )
                InstructionRow(
                    number: "5",
                    text: "Tap the widget to configure your facility"
                )
            }

            Section("Available Widgets") {
                WidgetFeatureRow(
                    title: "Focused Facility",
                    description: "Monitor a single facility's availability",
                    systemImage: "square.fill"
                )
            }

            Section {
                NavigationLink(destination: APIUsageDebugView()) {
                    Label("Widget Budget Monitor", systemImage: "gauge")
                }
            } header: {
                Text("Advanced")
            } footer: {
                Text("View widget reload budget and refresh statistics.")
            }
        }
        .navigationTitle("Widgets")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct InstructionRow: View {
    let number: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Color.accentColor)
                .clipShape(Circle())

            Text(text)
                .font(.body)
        }
    }
}

struct WidgetFeatureRow: View {
    let title: String
    let description: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
```

**Why**: Educates users on widget setup and configuration.

---

#### **Step 3: Create LiveActivitiesSettingsView**
```swift
import SwiftUI

@available(iOS 26.0, *)
struct LiveActivitiesSettingsView: View {
    var body: some View {
        Form {
            Section {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Coming Soon")
                            .font(.headline)
                        Text("Live Activities for real-time parking tracking are in development.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "clock.badge.exclamationmark")
                        .foregroundStyle(.orange)
                }
            }

            Section("Planned Features") {
                FeatureStatusRow(
                    title: "Dynamic Island Support",
                    status: "Planned",
                    systemImage: "oval.portrait"
                )
                FeatureStatusRow(
                    title: "Lock Screen Live Activity",
                    status: "Planned",
                    systemImage: "lock.rectangle"
                )
                FeatureStatusRow(
                    title: "Real-time Vacancy Updates",
                    status: "Planned",
                    systemImage: "arrow.triangle.2.circlepath"
                )
            }

            Section {
                Text("Live Activities will allow you to track parking availability for your selected facility directly from your lock screen and Dynamic Island.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Live Activities")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FeatureStatusRow: View {
    let title: String
    let status: String
    let systemImage: String

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Text(status)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Capsule())
        }
    }
}
```

**Why**: Placeholder for future Live Activities feature, sets user expectations.

---

#### **Step 4: Create AboutView**
```swift
import SwiftUI

@available(iOS 26.0, *)
struct AboutView: View {
    @Environment(OnboardingManager.self) private var onboardingManager

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "parkingsign.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(Color.accentColor)

                        Text("MetroParking")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Version 0.3.0")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical)
            }

            Section("About") {
                LabeledContent("Developer", value: "Tom Kwok")
                LabeledContent("Copyright", value: "© 2025 Tom Kwok")
                LabeledContent("License", value: "GPL v3.0")
            }

            Section {
                Link(destination: URL(string: "https://github.com/realtomkwok/MetroParking")!) {
                    Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                }

                Link(destination: URL(string: "https://opendata.transport.nsw.gov.au/")!) {
                    Label("TfNSW Open Data", systemImage: "network")
                }
            }

            Section("Credits") {
                Text("Data provided by Transport for NSW")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Built with SwiftUI, SwiftData, MapKit, and WidgetKit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    onboardingManager.showOnboarding()
                } label: {
                    Label("Show Onboarding Again", systemImage: "arrow.clockwise")
                }
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

**Why**: Provides app information, credits, and re-triggers onboarding.

---

#### **Step 5: Update ContentView Menu**
Replace the existing menu (lines 149-167) in `ContentView.swift`:

```swift
Menu {
    // Settings section
    Section("Settings") {
        NavigationLink(destination: NotificationsSettingsView()) {
            Label("Notifications", systemImage: "bell.badge")
        }

        NavigationLink(destination: WidgetsSettingsView()) {
            Label("Widgets", systemImage: "square.grid.2x2")
        }

        NavigationLink(destination: LiveActivitiesSettingsView()) {
            Label("Live Activities", systemImage: "clock.badge")
        }
    }

    // About section
    Section("About") {
        NavigationLink(destination: AboutView()) {
            Label("About MetroParking", systemImage: "info.circle")
        }

        Button {
            onboardingManager.showOnboarding()
        } label: {
            Label("Show Onboarding", systemImage: "hand.wave")
        }
    }

    // Developer section (Debug only)
    #if DEBUG
    Section("Developer") {
        NavigationLink(destination: APIUsageDebugView()) {
            Label("API Debug", systemImage: "hammer")
        }
    }
    #endif
} label: {
    Label("Settings", systemImage: "ellipsis")
}
```

**Why**: Organizes menu into logical sections with clear navigation paths.

---

### 2.3 Testing Checklist
- [ ] All menu items appear correctly
- [ ] Navigation links work for each settings view
- [ ] Notifications toggle requests permission
- [ ] Widget setup instructions are clear
- [ ] About view displays correct version
- [ ] "Show Onboarding Again" triggers onboarding
- [ ] Debug menu only appears in Debug builds
- [ ] Forms scroll correctly on all screen sizes

---

## 3. Documentation Updates

### 3.1 Update CLAUDE.md

Add the following sections:

#### **Under "Project Structure"** (after line 39):
```markdown
│   │   ├── Onboarding/             # First-time user experience
│   │   │   ├── OnboardingView.swift
│   │   │   ├── OnboardingPageView.swift
│   │   │   └── OnboardingPage.swift
│   │   ├── Settings/               # Settings and preferences
│   │   │   ├── SettingsView.swift
│   │   │   ├── NotificationsSettingsView.swift
│   │   │   ├── WidgetsSettingsView.swift
│   │   │   ├── LiveActivitiesSettingsView.swift
│   │   │   └── AboutView.swift
```

#### **Under "Managers/"** (after line 47):
```markdown
│   │   ├── OnboardingManager.swift # Onboarding state and flow control
│   │   ├── UserPreferences.swift   # User settings with @AppStorage
```

#### **Add new section after "Widget Implementation"** (after line 181):
```markdown
## Onboarding System

### Overview
The app includes a first-time user onboarding flow displayed as a sheet on initial launch. The onboarding can be re-triggered from Settings → About.

### Key Components

**Onboarding Files**:
- `OnboardingView.swift`: Main onboarding container with TabView
- `OnboardingPageView.swift`: Individual page component
- `OnboardingPage.swift`: Page data model with content
- `OnboardingManager.swift`: State management for onboarding flow

**User Preferences**:
- `UserPreferences.swift`: Centralized @AppStorage wrapper
- Tracks onboarding completion, notification settings, widget configuration
- Persists user preferences across app launches

**Onboarding Flow**:
1. App checks `UserPreferences.hasCompletedOnboarding` on launch
2. If false, `OnboardingManager.isShowingOnboarding` becomes true
3. Sheet presents `OnboardingView` with 5-page flow
4. User navigates through pages or taps "Skip"
5. Final page has "Get Started" button to complete onboarding
6. `OnboardingManager.completeOnboarding()` sets preference and dismisses sheet

### Onboarding Pages
1. **Welcome**: Introduction to MetroParking
2. **Pin Favorites**: Explain facility pinning
3. **Live Widgets**: Widget feature overview
4. **Notifications**: Alert system explanation
5. **Get Started**: Final call-to-action

## Settings System

### Overview
The app provides a comprehensive settings menu accessible from the top toolbar. Settings are organized into sections for notifications, widgets, Live Activities, and app information.

### Settings Views

**NotificationsSettingsView**:
- Notification permission management
- Vacancy alert threshold configuration
- System settings integration

**WidgetsSettingsView**:
- Widget setup instructions
- Available widget types
- Budget monitoring access

**LiveActivitiesSettingsView**:
- Placeholder for future Live Activities feature
- Feature status indicators
- Planned capabilities

**AboutView**:
- App version and developer information
- Links to source code and TfNSW Open Data
- Credits and attributions
- Re-trigger onboarding option

### User Preferences

All settings are persisted using `@AppStorage` in `UserPreferences.swift`:
- `hasCompletedOnboarding`: Onboarding completion status
- `notificationsEnabled`: Notification toggle state
- `vacancyThreshold`: Alert threshold (5-50 spaces)
- `widgetsConfigured`: Widget setup status
- `preferredSortOption`: Default sorting preference
- `enableHaptics`: Haptic feedback toggle
```

#### **Update "Known Issues & TODOs"** (after line 352):
```markdown
- [x] Add onboarding screen for first-time users
- [x] Populate settings menu with notification, widget, and about sections
```

#### **Update "Feature Roadmap"** (after line 366):
```markdown
### User Experience
- [x] Onboarding flow for new users
- [x] Settings menu with preferences
- [ ] User preferences for default sort/filter
- [ ] Haptic feedback settings
- [ ] Dark mode customization
```

---

### 3.2 Update README.md

#### **Update "Features" section** (after line 24):
```markdown
- **Onboarding Experience**: First-time user tutorial with feature highlights
- **Settings Menu**: Comprehensive settings for notifications, widgets, and preferences
```

#### **Update "Project Structure"** (after line 146):
```markdown
│   ├── Views/
│   │   ├── Onboarding/     # First-time user experience
│   │   ├── Settings/       # Settings and preferences screens
```

#### **Update "Key Files"** (after line 161):
```markdown
- `OnboardingView.swift`: First-time user onboarding flow
- `OnboardingManager.swift`: Onboarding state management
- `UserPreferences.swift`: User settings with @AppStorage
- `NotificationsSettingsView.swift`: Notification preferences
- `WidgetsSettingsView.swift`: Widget setup guide
- `AboutView.swift`: App information and credits
```

#### **Update Changelog** (after line 260):
```markdown
**User Experience**
- Added first-time onboarding flow with 5-page tutorial
- Populated settings menu with notifications, widgets, Live Activities, and about sections
- Created `UserPreferences` for persistent user settings
- Implemented `OnboardingManager` for flow control
- Added re-trigger onboarding option in About view
```

---

## 4. Implementation Order

### Phase 1: Infrastructure (Session 1)
1. Create `UserPreferences.swift`
2. Create `OnboardingManager.swift`
3. Update `MetroParkingApp.swift` with new environment objects

### Phase 2: Onboarding (Session 2)
4. Create `OnboardingPage.swift`
5. Create `OnboardingPageView.swift`
6. Create `OnboardingView.swift`
7. Integrate with `ContentView.swift`
8. Test onboarding flow

### Phase 3: Settings Views (Session 3)
9. Create `NotificationsSettingsView.swift`
10. Create `WidgetsSettingsView.swift`
11. Create `LiveActivitiesSettingsView.swift`
12. Create `AboutView.swift`
13. Update `ContentView.swift` menu

### Phase 4: Testing & Documentation (Session 4)
14. Test all settings views
15. Test onboarding flow from Settings
16. Update `CLAUDE.md`
17. Update `README.md`
18. Create screenshots for onboarding pages
19. Final QA pass

---

## 5. Design Considerations

### Colors & Styling
- Use existing `BackgroundGradient()` for onboarding background
- Match iOS 26 glass effects in existing app
- Use SF Symbols for all icons
- Gradient colors for onboarding pages match app theme

### Accessibility
- All buttons have accessibility labels
- Form sections have clear headers and footers
- Text sizes respect Dynamic Type
- Color contrast meets WCAG AA standards

### Performance
- Onboarding view only loads when needed
- Settings views use Form for built-in optimization
- `@AppStorage` writes are lightweight
- No network calls in settings views

### Future Extensibility
- `OnboardingPage.pages` array easily extensible
- `UserPreferences` can add new properties
- Settings menu structure supports new sections
- Live Activities view ready for implementation

---

## 6. Risks & Mitigation

### Risk: Notification Permission Rejection
**Mitigation**: Provide clear explanation before requesting permission, link to system settings

### Risk: Onboarding Becomes Stale
**Mitigation**: Version tracking for onboarding, can show "What's New" on updates

### Risk: Settings Complexity Growth
**Mitigation**: Organize into logical sections, use sub-views for complex settings

### Risk: User Dismisses Onboarding Too Early
**Mitigation**: Provide "Show Onboarding Again" in About section

---

## 7. Success Criteria

- [ ] Onboarding appears on first launch
- [ ] All 5 onboarding pages display correctly
- [ ] Settings menu has all planned items
- [ ] Notifications settings request permission correctly
- [ ] Widget setup instructions are clear
- [ ] About view has correct information
- [ ] Onboarding can be re-triggered from About
- [ ] No crashes or layout issues on iPhone SE to iPhone 15 Pro Max
- [ ] All preferences persist across app launches
- [ ] Documentation updated in CLAUDE.md and README.md

---

## 8. Post-Implementation Tasks

1. Create App Store screenshots for onboarding
2. Update App Store description with onboarding mentions
3. Add analytics tracking for onboarding completion rate
4. Monitor user feedback on settings organization
5. Plan "What's New" sheet for v0.4.0

---

**Document Version**: 1.0
**Created**: December 26, 2025
**Last Updated**: December 26, 2025
**Status**: Ready for Review
