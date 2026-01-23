//
//  ScreenshotTests.swift
//  MetroParkingUITests
//
//  Created for Fastlane snapshot automation.
//  Run with: fastlane snapshot
//

import XCTest

/// UI Tests designed for Fastlane snapshot automation.
/// These tests capture screenshots at key screens for App Store submissions.
///
/// To use with Fastlane:
/// 1. Add `snapshot` to your Fastfile
/// 2. Run `fastlane snapshot` to generate screenshots
///
/// Launch arguments:
/// - `UI_TESTING`: Enables UI testing mode
/// - `SKIP_ONBOARDING`: Skips onboarding for tests that don't need it
/// - `RESET_STATE`: Resets app state for clean screenshots
final class ScreenshotTests: XCTestCase {

    var app: XCUIApplication!

	@MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments += ["UI_TESTING"]

        // Enable Fastlane snapshot support
        setupSnapshot(app)

        // Set up handler for system permission alerts (location, notifications, etc.)
        addUIInterruptionMonitor(withDescription: "System Permission Alert") { alert in
            // Look for common permission allow buttons
            let allowButtons = ["Allow While Using App", "Allow Once", "Allow", "OK"]
            for buttonText in allowButtons {
                let button = alert.buttons[buttonText]
                if button.exists {
                    button.tap()
                    return true
                }
            }
            return false
        }
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Screenshot Tests

    /// Captures the onboarding screen shown on first launch
    @MainActor
    func test01_OnboardingScreen() throws {
        // Launch with fresh state to show onboarding
        app.launchArguments += ["RESET_STATE"]
        app.launch()

        // Wait for onboarding to appear
        let onboardingView = app.otherElements["onboarding-view"]
        let exists = onboardingView.waitForExistence(timeout: 5)

        if exists {
            // Give time for animations to settle
            Thread.sleep(forTimeInterval: 1.0)
            snapshot("01_Onboarding")
        } else {
            // Onboarding might already be completed, skip this test
            XCTSkip("Onboarding already completed")
        }
    }

    /// Captures the main facility list screen
    @MainActor
    func test02_MainScreen() throws {
        // Skip onboarding for this test
        app.launchArguments += ["SKIP_ONBOARDING"]
        app.launch()

        // Wait for the facility list to load (SwiftUI List can appear as collectionView or table)
        let facilityListExists = waitForFacilityList(timeout: 10)
        XCTAssertTrue(facilityListExists, "Facility list should appear")

        // Wait for data to load (check for any facility row)
        let firstRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'facility-row-'")).firstMatch
        _ = firstRow.waitForExistence(timeout: 10)

        // Give time for list to populate and animations to settle
        Thread.sleep(forTimeInterval: 2.0)

        snapshot("02_MainScreen")
    }

    /// Captures the main screen with a filter applied
    @MainActor
    func test03_MainScreenWithFilter() throws {
        app.launchArguments += ["SKIP_ONBOARDING"]
        app.launch()

        // Wait for the facility list to load
        let facilityListExists = waitForFacilityList(timeout: 10)
        XCTAssertTrue(facilityListExists, "Facility list should appear")

        // Wait for data to load
        Thread.sleep(forTimeInterval: 2.0)

        // Tap the filter toggle in the bottom toolbar
        let filterToggle = app.buttons["filter-toggle"]
        if filterToggle.waitForExistence(timeout: 5) {
            filterToggle.tap()

            // Wait for filter UI to appear and animate
            Thread.sleep(forTimeInterval: 1.0)

            snapshot("03_MainScreen_Filtered")
        } else {
            XCTFail("Filter toggle not found")
        }
    }

    /// Captures the facility detail page
    @MainActor
    func test04_DetailPage() throws {
        app.launchArguments += ["SKIP_ONBOARDING"]
        app.launch()

        // Wait for the facility list to load
        let facilityListExists = waitForFacilityList(timeout: 10)
        XCTAssertTrue(facilityListExists, "Facility list should appear")

        // Wait for data to load
        Thread.sleep(forTimeInterval: 2.0)

        // Tap the first facility row
        let firstFacilityRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'facility-row-'")).firstMatch

        if firstFacilityRow.waitForExistence(timeout: 5) {
            firstFacilityRow.tap()

            // Handle location permission alert if it appears
            handleLocationPermissionAlert()

            // Wait for detail view to appear - try multiple query strategies
            let detailSections = app.otherElements["detail-sections"]
            let detailView = app.scrollViews["detail-view"]

            // Wait for either element to appear (detail sections is more reliable)
            let detailAppeared = detailSections.waitForExistence(timeout: 5) || detailView.waitForExistence(timeout: 2)

            if !detailAppeared {
                // Fallback: just wait a bit more - navigation animations can be slow
                Thread.sleep(forTimeInterval: 1.0)
            }

            // Give time for map and Look Around to load
            Thread.sleep(forTimeInterval: 3.0)

            // Handle location alert again in case it appeared after delay
            handleLocationPermissionAlert()

            snapshot("04_DetailPage")
        } else {
            XCTFail("No facility rows found")
        }
    }

    // MARK: - Helpers

    /// Waits for the facility list to appear (handles SwiftUI List appearing as different element types)
    @MainActor
    private func waitForFacilityList(timeout: TimeInterval) -> Bool {
        // SwiftUI List can appear as collectionView, table, or other element types depending on iOS version
        let collectionView = app.collectionViews["facility-list"]
        let table = app.tables["facility-list"]
        let otherElement = app.otherElements["facility-list"]

        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            if collectionView.exists || table.exists || otherElement.exists {
                return true
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return false
    }

    /// Handles the system location permission alert by tapping "Allow While Using App"
    @MainActor
    private func handleLocationPermissionAlert() {
        // Use springboard to handle system alerts
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

        // Check for location permission alert (may have different button texts)
        let allowButtons = [
            "Allow While Using App",
            "Allow Once",
            "허용",  // Korean
            "允许使用App时访问"  // Chinese
        ]

        for buttonText in allowButtons {
            let button = springboard.buttons[buttonText]
            if button.waitForExistence(timeout: 2) {
                button.tap()
                return
            }
        }

        // Also try the app's own alerts
        for buttonText in allowButtons {
            let button = app.buttons[buttonText]
            if button.exists {
                button.tap()
                return
            }
        }
    }

    /// Captures the settings screen
    @MainActor
    func test05_SettingsScreen() throws {
        app.launchArguments += ["SKIP_ONBOARDING"]
        app.launch()

        // Wait for the main screen to load
        let facilityListExists = waitForFacilityList(timeout: 10)
        XCTAssertTrue(facilityListExists, "Facility list should appear")

        // Tap the settings button (ellipsis menu)
        let settingsButton = app.buttons["settings-button"]
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()

            // Wait for settings sheet to appear
            Thread.sleep(forTimeInterval: 1.0)

            snapshot("05_Settings")
        } else {
            XCTFail("Settings button not found")
        }
    }
}
