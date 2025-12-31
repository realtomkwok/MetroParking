//
//  MetroParkingApp.swift
//  MetroParking
//
//  Created by Tom Kwok on 18/5/2025.
//

import SwiftData
import SwiftUI

@main
struct MetroParkingApp: App {
	
	// MARK: - Model Container

	/// Use the shared container from SharedDataManager to ensure app and widget use the same data store
	var sharedModelContainer: ModelContainer {
		SharedDataManager.sharedContainer
	}

	init() {
		setupConfiguration()
		
		// Initialise AppStateManager to set up lifecycle observers
		_ = AppStateManager.shared
		
		BackgroundTaskManager.shared.registerBackgroundTasks()
	}

	var body: some Scene {
		WindowGroup {
			ContentView()
				.modelContainer(sharedModelContainer)
				.environment(AppStateManager.shared)
				.environment(FacilityManager.shared)
				.environment(LocationManager.shared)
				.environment(LookAroundManager.shared)
				.environment(ETAManager.shared)
				.environment(OnboardingManager.shared)
				.environment(UserPreferences.shared)
				.environment(DeepLinkManager.shared)
				.onOpenURL { url in
					_ = DeepLinkManager.shared.handleURL(url)
				}
				.task {
					// Initialise on first appearance
					await initializeFacilityManager()
				}
		}
	}

	private func setupConfiguration() {
		// Access configuration properties to trigger validation
		// Each property has built-in validation that will fatalError if invalid
		_ = Configuration.tfnswApiKey
		_ = Configuration.carParkBaseUrl

		#if DEBUG
			Configuration.validateInDebug()
			Configuration.printConfiguration()
		#endif
	}

	@MainActor
	private func initializeFacilityManager() async {
		let facilityManager = FacilityManager.shared
		let context = sharedModelContainer.mainContext
		
		// Set up the manager with context
		facilityManager.setModelContext(context)
		
		// Load initial data
		await facilityManager.loadStaticFacilitiesIfNeeded()
		await facilityManager.performLoad()
		facilityManager.startAutoRefresh()
	}
}
