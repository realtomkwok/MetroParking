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
	
	// MARK: - Schema Version Tracking
	
	/// Current schema version for destructive migration (pre-launch only)
	///
	/// **Important**: This destructive migration approach deletes all user data on schema changes.
	/// Before v1.0 launch, implement proper SwiftData versioned migrations to preserve user preferences.
	/// See README.md "Data Migration Strategy" section for implementation details.
	///
	/// To trigger a migration:
	/// 1. Increment this version string (e.g., "v2" → "v3")
	/// 2. Old data will be automatically cleared on next launch
	/// 3. Fresh data will be fetched from API
	private static let schemaVersion = "v3"
	private static let schemaVersionKey = "ModelSchemaVersion"
	
	// MARK: - Model Container
	
	var sharedModelContainer: ModelContainer = {
		let schema = Schema([
			ParkingFacility.self,
			ParkingZone.self,
		])
		let modelConfiguration = ModelConfiguration(
			schema: schema,
			isStoredInMemoryOnly: false
		)

		do {
			// Check if schema version has changed
			let storedVersion = UserDefaults.standard.string(forKey: Self.schemaVersionKey)
			let needsMigration = storedVersion != nil && storedVersion != Self.schemaVersion
			
			if needsMigration {
				print("📦 Schema version changed from \(storedVersion ?? "unknown") to \(Self.schemaVersion)")
				print("🗑️ Clearing old data store for migration...")
				
				// Clean up old store files
				let storeURL = modelConfiguration.url
				try? FileManager.default.removeItem(at: storeURL)
				try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
				try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
			}
			
			let container = try ModelContainer(
				for: schema,
				configurations: [modelConfiguration]
			)
			
			// Save current schema version
			UserDefaults.standard.set(Self.schemaVersion, forKey: Self.schemaVersionKey)
			
			return container
		} catch {
			// Schema migration failed - likely due to model changes
			// Log the error and attempt recovery
			print("⚠️ ModelContainer creation failed: \(error.localizedDescription)")

			do {
				// Try creating the container again with fresh store
				let container = try ModelContainer(
					for: schema,
					configurations: [modelConfiguration]
				)
				
				// Save schema version after successful recovery
				UserDefaults.standard.set(Self.schemaVersion, forKey: Self.schemaVersionKey)
				
				return container
			} catch {
				fatalError(
					"Could not create ModelContainer after cleanup: \(error.localizedDescription)"
				)
			}
		}
	}()

	init() {
		setupConfiguration()
	}

	var body: some Scene {
		WindowGroup {
			ContentView()
				.modelContainer(sharedModelContainer)
				.environment(FacilityManager.shared)
				.environment(LocationManager.shared)
				.environment(LookAroundManager.shared)
				.environment(ETAManager.shared)
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
		_ = Configuration.supabaseUrl
		_ = Configuration.supabasePublishableKey

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
