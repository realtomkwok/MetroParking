//
//  AppEnvironment.swift
//  MetroParking
//
//  Created by Tom Kwok on 19/9/2026.
//

import SwiftUI

/// The app-wide services views read from the environment.
///
/// Built once and injected at the root, so views never reach for singletons
/// directly, and previews get the complete set from one modifier.
struct AppEnvironment {
	let facilities: FacilityManager
	let location: LocationManager
	let eta: ETAManager
	let appState: AppStateManager
	let onboarding: OnboardingManager
	let preferences: UserPreferences
	let deepLinks: DeepLinkManager
	let search: SearchManager

	/// The services backing the running app. Background tasks and the widget
	/// share these instances, so they stay process-wide.
	static var live: AppEnvironment {
		AppEnvironment(
			facilities: .shared,
			location: .shared,
			eta: .shared,
			appState: .shared,
			onboarding: .shared,
			preferences: .shared,
			deepLinks: .shared,
			search: .shared
		)
	}
}

extension View {
	func appEnvironment(_ services: AppEnvironment) -> some View {
		self
			.environment(services.facilities)
			.environment(services.location)
			.environment(services.eta)
			.environment(services.appState)
			.environment(services.onboarding)
			.environment(services.preferences)
			.environment(services.deepLinks)
			.environment(services.search)
	}

	/// Everything a preview needs; missing environment objects crash previews.
	func previewEnvironment() -> some View {
		appEnvironment(.live)
	}
}
