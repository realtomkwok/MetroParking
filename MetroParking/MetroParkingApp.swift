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
		// Handle UI testing launch arguments
		handleUITestingArguments()

		setupConfiguration()

		Task.detached(priority: .userInitiated) {
			_ = await SharedDataManager.prepareStoreDirectory()
		}

		// Initialise AppStateManager to set up lifecycle observers
		_ = AppStateManager.shared

		BackgroundTaskManager.shared.registerBackgroundTasks()

		// Schedule initial processing task if none pending (handles fresh install or force-quit)
		BackgroundTaskManager.shared.scheduleProcessingTaskIfNeeded()

	}

	/// Handles launch arguments for UI testing and screenshot automation
	private func handleUITestingArguments() {
		let arguments = ProcessInfo.processInfo.arguments

		// Check if running in UI testing mode
		guard arguments.contains("UI_TESTING") else { return }

		#if DEBUG
		print("🧪 Running in UI Testing mode")
		#endif

		// Reset state for clean screenshots
		if arguments.contains("RESET_STATE") {
			#if DEBUG
			print("🔄 Resetting app state for UI testing")
			#endif
			// Clear UserDefaults to show onboarding
			if let bundleID = Bundle.main.bundleIdentifier {
				UserDefaults.standard.removePersistentDomain(forName: bundleID)
				UserDefaults.standard.synchronize()
			}
		}

		// Skip onboarding for tests that don't need it
		if arguments.contains("SKIP_ONBOARDING") {
			#if DEBUG
			print("⏭️ Skipping onboarding for UI test")
			#endif
			UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
			UserDefaults.standard.synchronize()
		}
	}

	var body: some Scene {
		WindowGroup {
			ContentView()
				.modelContainer(sharedModelContainer)
				.environment(SearchManager.shared)
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
