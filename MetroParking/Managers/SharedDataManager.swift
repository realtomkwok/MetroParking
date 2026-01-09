//
//  SharedDataManager.swift
//  MetroParking
//
//  Created by Tom Kwok on 16/12/2025.
//
// 	Managing data between main app and the widget

import Foundation
import OSLog
import SwiftData
import WidgetKit

class SharedDataManager {

	// App Group
	static let appGroupIdentifier: String = "group.com.tomkwok.MetroParking"

	static var shared = SharedDataManager()

	private init() {}

	// MARK: - SwiftData Container

	/// Schema version for destructive migration (pre-launch only)
	private static let schemaVersion = "v4"
	private static let schemaVersionKey = "ModelSchemaVersion"

	/// Shared ModelContainer instance used by both app and widget
	/// This ensures both targets read from the same SwiftData store
	@MainActor
	static let sharedContainer: ModelContainer = {
		let schema = Schema([
			ParkingFacility.self,
			ParkingZone.self,
		])

		let modelConfiguration = ModelConfiguration(
			schema: schema,
			isStoredInMemoryOnly: false,
			groupContainer: .identifier(appGroupIdentifier)
		)

		// Ensure the Application Support directory exists in the App Group container
		// This prevents CoreData error logs on first launch
		let storeURL = modelConfiguration.url
		let storeDirectory = storeURL.deletingLastPathComponent()

		if !FileManager.default.fileExists(atPath: storeDirectory.path) {
			do {
				try FileManager.default.createDirectory(
					at: storeDirectory,
					withIntermediateDirectories: true,
					attributes: nil
				)
				Logger.facilityData.info("📁 Created store directory: \(storeDirectory.path)")
			} catch {
				Logger.facilityData.error("❌ Failed to create store directory: \(error.localizedDescription)")
			}
		}

		do {
			// Check if schema version has changed
			let storedVersion = UserDefaults.standard.string(
				forKey: schemaVersionKey
			)
			let needsMigration =
				storedVersion != nil && storedVersion != schemaVersion

			if needsMigration {
				Logger.facilityData.info(
					"📦 Schema version changed from \(storedVersion ?? "unknown") to \(schemaVersion)"
				)
				Logger.facilityData.info(
					"🗑️ Clearing old data store for migration..."
				)

				// Clean up old store files
				try? FileManager.default.removeItem(at: storeURL)
				try? FileManager.default.removeItem(
					at: storeURL.appendingPathExtension("shm")
				)
				try? FileManager.default.removeItem(
					at: storeURL.appendingPathExtension("wal")
				)
			}

			let container = try ModelContainer(
				for: schema,
				configurations: [modelConfiguration]
			)

			// Save current schema version
			UserDefaults.standard.set(schemaVersion, forKey: schemaVersionKey)

			return container
		} catch {
			// Schema migration failed - likely due to model changes
			Logger.facilityData.error(
				"⚠️ ModelContainer creation failed: \(error.localizedDescription)"
			)

			do {
				// Try creating the container again with fresh store
				let container = try ModelContainer(
					for: schema,
					configurations: [modelConfiguration]
				)

				// Save schema version after successful recovery
				UserDefaults.standard.set(
					schemaVersion,
					forKey: schemaVersionKey
				)

				return container
			} catch {
				fatalError(
					"Could not create ModelContainer after cleanup: \(error.localizedDescription)"
				)
			}
		}
	}()

	/// Get the shared UserDefaults for App Group
	private var sharedDefaults: UserDefaults? {
		UserDefaults(suiteName: Self.appGroupIdentifier)
	}
}

extension SharedDataManager {

	private static let widgetFacilityIdsKey: String = "widgetFacilityIds"

	// MARK: - Widget Data Strucure
	/// Cache structure
	struct WidgetFacilityData: Codable {
		let facilityId: String
		let name: String
		let displayTitle: String
		let displaySubtitle: String
		let address: String

		// Vacancy
		let availableSpaces: Int
		let totalSpaces: Int
		let occupancyRatio: Double
		let availabilityStatus: String  // "available", "almostFull", "full", "noData" -> as AvailabilityStatus is not codable

		// Route
		let distance: Double?
		let travelTime: TimeInterval?

		// Metadata
		let lastUpdated: Date
		let cacheTimestamp: Date

		var statusColour: String {
			switch availabilityStatus {
			case "available": return "green"
			case "almostFull": return "yellow"
			case "full": return "red"
			default: return "gray"
			}
		}

		/// Check if the cached data is stale (older than 15 minutes)
		var isStale: Bool {
			let staleThreshold: TimeInterval = 15 * 60  // 15 minutes
			return Date().timeIntervalSince(cacheTimestamp) > staleThreshold
		}

		/// Check if data is too old to display reliably
		/// When true, widget should prompt user to refresh instead of showing potentially misleading data
		var isTooOld: Bool {
			return Date().timeIntervalSince(cacheTimestamp) > RefreshConfiguration.Widget.maxStaleAge
		}

		/// Human-readable time since last update
		var timeSinceUpdate: String {
			lastUpdated
				.formatted(
					.relative(presentation: .named, unitsStyle: .abbreviated)
				)
		}
	}

	func registerWidgetFacility(_ facilityId: String) {
		guard let userDefaults = sharedDefaults else {
			Logger.widget.error("❌ Failed to access shared UserDefaults")
			return
		}

		var ids = getWidgetFacilityIDs()
		if !ids.contains(facilityId) {
			ids.append(facilityId)
			userDefaults.set(ids, forKey: Self.widgetFacilityIdsKey)
			userDefaults.synchronize()

			Logger.widget.info("✅ Registered facility ID: \(facilityId)")
		}
	}

	// TODO: Unregister the widget when being removed from the home screen
	func deregisterWidgetFacility(_ facilityId: String) {
		guard let userDefaults = sharedDefaults else {
			Logger.widget.error("❌ Failed to access shared UserDefaults")
			return
		}
		
		var ids = getWidgetFacilityIDs()
		ids.removeAll { $0 == facilityId }
		userDefaults.set(ids, forKey: Self.widgetFacilityIdsKey)
		userDefaults.synchronize()

		Logger.widget.info("✅ Deregistered facility ID: \(facilityId)")
	}

	// MARK: - Widget Data Cache (Multi-Widget Support)

	private static let widgetDataCacheKey: String = "widgetDataCache"

	/// Save widget data cache for a specific facility
	/// Supports multiple widgets by storing data keyed by facilityId
	/// - Parameters:
	///   - data: The facility data to save
	///   - triggerReload: Whether to trigger an immediate widget reload (budget-aware)
	func saveWidgetData(_ data: WidgetFacilityData, triggerReload: Bool = false)
	{
		guard let defaults = sharedDefaults else {
			Logger.widget.error("❌ Failed to access shared UserDefaults")
			return
		}

		// Load existing cache dictionary
		var cache = loadWidgetDataCache()

		// Update cache for this facility
		cache[data.facilityId] = data

		// Save updated cache
		do {
			let encoder = JSONEncoder()
			encoder.dateEncodingStrategy = .iso8601
			let encoded = try encoder.encode(cache)
			defaults.set(encoded, forKey: Self.widgetDataCacheKey)
			defaults.synchronize()

			if triggerReload {
				WidgetBudgetTracker.shared.requestReload()
			}

			Logger.widget.info(
				"✅ Widget data saved for: \(data.displayTitle) (\(data.facilityId))"
			)

		} catch {
			Logger.widget.error("❌ Failed to encode widget data cache: \(error)")
		}
	}

	/// Load all cached widget data as a dictionary [facilityId: WidgetFacilityData]
	private func loadWidgetDataCache() -> [String: WidgetFacilityData] {
		guard let defaults = sharedDefaults else {
			Logger.widget.error("❌ Failed to access shared UserDefaults")
			return [:]
		}

		guard let data = defaults.data(forKey: Self.widgetDataCacheKey) else {
			return [:]
		}

		do {
			let decoder = JSONDecoder()
			decoder.dateDecodingStrategy = .iso8601
			let cache = try decoder.decode(
				[String: WidgetFacilityData].self,
				from: data
			)
			return cache
		} catch {
			Logger.widget.error("❌ Failed to decode widget data cache: \(error)")
			return [:]
		}
	}

	/// Load widget data for a specific facility ID (used by AppIntent widgets)
	func loadWidgetData(forFacilityId facilityId: String) -> WidgetFacilityData?
	{
		let cache = loadWidgetDataCache()
		return cache[facilityId]
	}

	/// Get all currently cached widget data for registered widget facilities
	func getAllWidgetData() -> [WidgetFacilityData] {
		let cache = loadWidgetDataCache()
		let widgetFacilityIds = getWidgetFacilityIDs()

		return widgetFacilityIds.compactMap { cache[$0] }
	}

	/// Legacy method - loads the first widget facility data for backward compatibility
	/// - Note: Deprecated - Use `loadWidgetData(forFacilityId:)` or `getAllWidgetData()` instead
	@available(*, deprecated, message: "Use loadWidgetData(forFacilityId:) or getAllWidgetData() for multi-widget support")
	func loadWidgetData() -> WidgetFacilityData? {
		// Return the first registered widget facility's data
		let widgetIds = getWidgetFacilityIDs()
		guard let firstId = widgetIds.first else { return nil }
		return loadWidgetData(forFacilityId: firstId)
	}

	func makeWidgetData(from facility: ParkingFacility) -> WidgetFacilityData {
		let vacancy = facility.vacancy
		let displayName = facility.displayName

		return WidgetFacilityData(
			facilityId: facility.facilityId,
			name: facility.name,
			displayTitle: displayName.title,
			displaySubtitle: displayName.subtitle,
			address: facility.address,
			availableSpaces: vacancy.available,
			totalSpaces: vacancy.total,
			occupancyRatio: vacancy.occupancy,
			availabilityStatus: facility.availabilityStatus.text,
			distance: facility.route?.distance,
			travelTime: facility.route?.travelTime,
			lastUpdated: facility.refreshStatus.lastUpdated,
			cacheTimestamp: vacancy.cacheTimestamp
		)
	}

	/// Update widget with facility data and trigger reload
	/// - Parameters:
	///   - facility: The facility to display in the widget
	///   - triggerReload: Whether to trigger an immediate widget reload (default: true, budget-aware)
	func updateWidget(
		with facility: ParkingFacility,
		triggerReload: Bool = true
	) {
		let widgetData = makeWidgetData(from: facility)
		saveWidgetData(widgetData, triggerReload: triggerReload)
	}

	/// Cache widget data without triggering a reload
	/// Use this during batch updates to avoid exceeding widget budget
	/// Call `WidgetBudgetTracker.shared.requestReload()` once after all updates
	func cacheWidgetDataIfSelected(_ facility: ParkingFacility) {
		// Check if this facility is registered in any widget
		guard isCurrentlyInWidget(facility.facilityId) else {
			// This facility is not shown in any widget
			return
		}

		// Update cache without triggering reload
		let widgetData = makeWidgetData(from: facility)
		saveWidgetData(widgetData, triggerReload: false)
		Logger.widget.debug(
			"💾 Cached widget data for: \(facility.displayName.title)"
		)
	}

	/// Update widget only if this facility is currently selected in the widget
	func updateWidgetIfSelected(_ facility: ParkingFacility) {
		// Check if this facility is registered in any widget
		guard isCurrentlyInWidget(facility.facilityId) else {
			// This facility is not shown in any widget
			return
		}

		// Update the widget with fresh data
		updateWidget(with: facility)
		Logger.widget
			.info("🔄 Widget updated for: \(facility.displayName.title)")
	}

	/// Get all facility IDs currently displayed in widgets
	func getWidgetFacilityIDs() -> [String] {
		guard let userDefaults = sharedDefaults else {
			Logger.widget.warning("Couldn't find user defaults.")
			return []
		}

		return userDefaults.stringArray(forKey: Self.widgetFacilityIdsKey) ?? []
	}

	/// Check if a facility is currently displayed in any widget
	func isCurrentlyInWidget(_ facilityId: String) -> Bool {
		return getWidgetFacilityIDs().contains(facilityId)
	}
}

