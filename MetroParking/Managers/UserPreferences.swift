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
/// Also provide observable properties for SwiftUI views
@MainActor
@Observable
final class UserPreferences {
	static let shared = UserPreferences()

	// MARK: - Logger
	@ObservationIgnored
	private let logger = Logger.userPreferences

	// MARK: - Onboarding

	/// Tracks whether the user has completed the initial onboarding flow
	var hasCompletedOnboarding: Bool {
		get { access(keyPath: \.hasCompletedOnboarding); return _hasCompletedOnboarding }
		set { withMutation(keyPath: \.hasCompletedOnboarding) { _hasCompletedOnboarding = newValue } }
	}
	@ObservationIgnored
	@AppStorage("hasCompletedOnboarding") private var _hasCompletedOnboarding: Bool = false

	// MARK: - Notifications

	/// Whether push notifications are enabled for vacancy alerts
	var notificationsEnabled: Bool {
		get { access(keyPath: \.notificationsEnabled); return _notificationsEnabled }
		set { withMutation(keyPath: \.notificationsEnabled) { _notificationsEnabled = newValue } }
	}
	@ObservationIgnored
	@AppStorage("notificationsEnabled") private var _notificationsEnabled: Bool = false

	/// Vacancy threshold for notifications (5-50 spaces)
	/// User will receive alerts when pinned facilities have fewer than this many spaces
	var vacancyThreshold: Int {
		get { access(keyPath: \.vacancyThreshold); return _vacancyThreshold }
		set { withMutation(keyPath: \.vacancyThreshold) { _vacancyThreshold = newValue } }
	}
	@ObservationIgnored
	@AppStorage("vacancyThreshold") private var _vacancyThreshold: Int = 10

	// MARK: - App Preferences

	/// Default sorting option (distance, name, availability, etc.)
	var preferredSortOption: SortingOption {
		get { access(keyPath: \.preferredSortOption); return _preferredSortOption }
		set { withMutation(keyPath: \.preferredSortOption) { _preferredSortOption = newValue } }
	}
	@ObservationIgnored
	@AppStorage("preferredSortOption") private var _preferredSortOption: SortingOption = .name

	/// Default sorting order (ascending or descending)
	var preferredSortingOrder: SortingOrder {
		get { access(keyPath: \.preferredSortingOrder); return _preferredSortingOrder }
		set { withMutation(keyPath: \.preferredSortingOrder) { _preferredSortingOrder = newValue } }
	}
	@ObservationIgnored
	@AppStorage("preferredSortingOrder") private var _preferredSortingOrder: SortingOrder = .ascending

	/// Default filter option (pinned, available, etc.)
	var preferredFilterOption: FilterOption {
		get { access(keyPath: \.preferredFilterOption); return _preferredFilterOption }
		set { withMutation(keyPath: \.preferredFilterOption) { _preferredFilterOption = newValue } }
	}
	@ObservationIgnored
	@AppStorage("preferredFilterOption") private var _preferredFilterOption: FilterOption = .available

	/// Whether filtering is enabled by default
	var filterIsOn: Bool {
		get { access(keyPath: \.filterIsOn); return _filterIsOn }
		set { withMutation(keyPath: \.filterIsOn) { _filterIsOn = newValue } }
	}
	@ObservationIgnored
	@AppStorage("filterIsOn") private var _filterIsOn: Bool = false

	/// Whether haptic feedback is enabled for interactions
	var enableHaptics: Bool {
		get { access(keyPath: \.enableHaptics); return _enableHaptics }
		set { withMutation(keyPath: \.enableHaptics) { _enableHaptics = newValue } }
	}
	@ObservationIgnored
	@AppStorage("enableHaptics") private var _enableHaptics: Bool = true

	// MARK: - Initialisation

	private init() {
		// Private initialiser ensures singleton pattern
	}

	// MARK: - Helper Methods

	/// Resets all preferences to default values (useful for testing)
	func resetToDefaults() {
		_hasCompletedOnboarding = false
		_notificationsEnabled = false
		_vacancyThreshold = 10
		_preferredSortOption = .name
		_preferredSortingOrder = .ascending
		_preferredFilterOption = .available
		_filterIsOn = false
		_enableHaptics = true
	}

	/// Debug helper to print current preferences
	func logCurrentPreferences() {
		#if DEBUG
			logger.debug("=== UserPreferences ===")
			logger.debug("Onboarding completed: \(self._hasCompletedOnboarding)")
			logger.debug("Notifications enabled: \(self._notificationsEnabled)")
			logger.debug("Vacancy threshold: \(self._vacancyThreshold)")
			logger.debug("Preferred sort: \(self._preferredSortOption.rawValue)")
			logger.debug("Preferred sort order: \(self._preferredSortingOrder.rawValue)")
			logger.debug("Preferred filter: \(self._preferredFilterOption.rawValue)")
			logger.debug("Filter enabled: \(self._filterIsOn)")
			logger.debug("Haptics enabled: \(self._enableHaptics)")
			logger.debug("======================")
		#endif
	}
}
