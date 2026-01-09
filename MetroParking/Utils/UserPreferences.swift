//
//  UserPreferences.swift
//  MetroParking
//
//  Created by Tom Kwok on 26/12/2025.
//

import OSLog
import SwiftUI

/// Centralised user preferences manager using @AppStorage for persistence
/// Provides a single source of truth for user settings across the app
@MainActor
@Observable
final class UserPreferences {
	static let shared = UserPreferences()

	// MARK: - Logger
	private let logger = Logger.userPreferences

	// MARK: - Onboarding

	/// Tracks whether the user has completed the initial onboarding flow
	@ObservationIgnored
	@AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool =
		false

	// MARK: - Notifications

	/// Whether push notifications are enabled for vacancy alerts
	@ObservationIgnored
	@AppStorage("notificationsEnabled") var notificationsEnabled: Bool = false

	/// Vacancy threshold for notifications (5-50 spaces)
	/// User will receive alerts when pinned facilities have fewer than this many spaces
	@ObservationIgnored
	@AppStorage("vacancyThreshold") var vacancyThreshold: Int = 10

	// MARK: - App Preferences

	/// Default sorting option (distance, name, availability, etc.)
	@ObservationIgnored
	@AppStorage(
		"preferredSortOption"
	) var preferredSortOption: SortingOption = .name

	/// Whether haptic feedback is enabled for interactions
	@ObservationIgnored
	@AppStorage("enableHaptics") var enableHaptics: Bool = true

	// MARK: - Initialisation

	private init() {
		// Private initialiser ensures singleton pattern
	}

	// MARK: - Helper Methods

	/// Resets all preferences to default values (useful for testing)
	func resetToDefaults() {
		hasCompletedOnboarding = false
		notificationsEnabled = false
		vacancyThreshold = 10
		preferredSortOption = .name
		enableHaptics = true
	}

	/// Debug helper to print current preferences
	func logCurrentPreferences() {
		#if DEBUG
			logger.debug("=== UserPreferences ===")
			logger.debug("Onboarding completed: \(self.hasCompletedOnboarding)")
			logger.debug("Notifications enabled: \(self.notificationsEnabled)")
			logger.debug("Vacancy threshold: \(self.vacancyThreshold)")
			logger.debug("Preferred sort: \(self.preferredSortOption.rawValue)")
			logger.debug("Haptics enabled: \(self.enableHaptics)")
			logger.debug("======================")
		#endif
	}
}
