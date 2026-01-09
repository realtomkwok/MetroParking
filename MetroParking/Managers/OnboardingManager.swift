//
//  OnboardingManager.swift
//  MetroParking
//
//  Created by Tom Kwok on 26/12/2025.
//

import SwiftUI

/// Manages the onboarding flow state and navigation
/// Controls when onboarding is shown and tracks user progress through pages
///
/// TODO: instead of multiple pages in the onboarding, there'll be only one page
/// on the sheet for the simplicity, however, we can utilise the TIpKIt and track the pages user visits and
/// show useful, contextual tips (for example, explaining what the star button does in the detail view, etc)
///
@MainActor
@Observable
final class OnboardingManager {
	static let shared = OnboardingManager()

	// MARK: - Published State

	/// Whether the onboarding sheet is currently presented
	var isShowingOnboarding: Bool = false


	// MARK: - Initialisation

	private init() {
		// Check if onboarding should be shown on app launch
		self.isShowingOnboarding = !UserPreferences.shared.hasCompletedOnboarding
	}

	// MARK: - Public Methods

	/// Completes the onboarding flow and dismisses the sheet
	/// Sets the hasCompletedOnboarding preference to true
	func completeOnboarding() {
		UserPreferences.shared.hasCompletedOnboarding = true
		isShowingOnboarding = false

		#if DEBUG
		print("✅ Onboarding completed")
		#endif
	}

	/// Triggers the onboarding flow (e.g., from Settings → About)
	/// Resets to the first page
	func showOnboarding() {
		isShowingOnboarding = true

		#if DEBUG
		print("🔄 Onboarding triggered manually")
		#endif
	}

	/// Skips the onboarding flow entirely
	/// Same as completeOnboarding() but with semantic clarity
	func skipOnboarding() {
		completeOnboarding()

		#if DEBUG
		print("⏭️ Onboarding skipped")
		#endif
	}
}
