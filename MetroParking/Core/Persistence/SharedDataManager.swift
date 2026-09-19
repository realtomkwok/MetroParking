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

@MainActor
final class SharedDataManager {

	// App Group - nonisolated for access from non-MainActor contexts
	nonisolated static let appGroupIdentifier: String = "group.com.tomkwok.MetroParking"

	static var shared = SharedDataManager()

	// MARK: - Widget ID Cache (reduces UserDefaults reads)
	private var _cachedWidgetIds: [String]?
	private var _widgetIdsCacheTime: Date = .distantPast
	private let widgetIdsCacheValidity: TimeInterval = 2.0  // 2 seconds TTL

	private init() {}

	// MARK: - SwiftData Container

	/// Schema version for destructive migration (pre-launch only)
	/// v7: Add name transformation
	private static let schemaVersion = "v7"
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

	nonisolated private static let widgetFacilityIdsKey: String = "widgetFacilityIds"

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
		/// `AvailabilityStatus` raw value. Older caches may hold display text instead; see `status`.
		let availabilityStatus: String

		// Route
		let distance: Double?
		let travelTime: TimeInterval?

		// Metadata
		let lastUpdated: Date
		let cacheTimestamp: Date

		var status: AvailabilityStatus {
			if let status = AvailabilityStatus(rawValue: availabilityStatus) {
				return status
			}
			// Caches written before raw values were stored held English display text.
			switch availabilityStatus.lowercased().replacingOccurrences(of: " ", with: "") {
			case "available": return .available
			case "almostfull": return .almostFull
			case "full": return .full
			default: return .noData
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

	/// Fetches fresh vacancy for a widget facility and updates the shared cache.
	/// - Parameter existingData: Cached data whose name, address and route fields are kept.
	/// - Returns: The updated data, or `nil` if the fetch failed.
	func refreshWidgetData(
		facilityId: String,
		existingData: WidgetFacilityData?
	) async -> WidgetFacilityData? {
		do {
			let response = try await ParkingAPIService.shared.fetchFacility(
				id: facilityId,
				timeout: 10  // Widgets have limited run time
			)

			let total = Int(response.spots) ?? 0
			let occupied = Int(response.occupancy.total ?? "0") ?? 0
			let available = max(0, total - occupied)
			let displayName = ParkingFacility.parseDisplayName(response.facilityName)
			let now = Date()

			let updatedData = WidgetFacilityData(
				facilityId: facilityId,
				name: response.facilityName,
				displayTitle: existingData?.displayTitle ?? displayName.title,
				displaySubtitle: existingData?.displaySubtitle ?? displayName.subtitle,
				address: existingData?.address ?? response.location.address,
				availableSpaces: available,
				totalSpaces: total,
				occupancyRatio: total > 0 ? Double(occupied) / Double(total) : 0,
				availabilityStatus: AvailabilityStatus(available: available, total: total).rawValue,
				distance: existingData?.distance,
				travelTime: existingData?.travelTime,
				lastUpdated: now,
				cacheTimestamp: now
			)

			saveWidgetData(updatedData, triggerReload: false)
			Logger.widget.info(
				"✅ Widget: Fetched fresh data for \(displayName.title) - \(available)/\(total) available"
			)
			return updatedData
		} catch {
			Logger.widget.error(
				"❌ Widget: Failed to fetch facility \(facilityId): \(error.localizedDescription)"
			)
			return nil
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
			invalidateWidgetIdsCache()

			Logger.widget.info("✅ Registered facility ID: \(facilityId)")
		}
	}

	/// Deregisters a widget facility when removed from home screen
	/// Note: Currently requires manual cleanup; automatic detection planned for future release
	func deregisterWidgetFacility(_ facilityId: String) {
		guard let userDefaults = sharedDefaults else {
			Logger.widget.error("❌ Failed to access shared UserDefaults")
			return
		}

		var ids = getWidgetFacilityIDs()
		ids.removeAll { $0 == facilityId }
		userDefaults.set(ids, forKey: Self.widgetFacilityIdsKey)
		invalidateWidgetIdsCache()

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

	func makeWidgetData(from facility: ParkingFacility) -> WidgetFacilityData {
		let vacancy = facility.vacancy
		let displayName = facility.displayName

		return WidgetFacilityData(
			facilityId: facility.facilityId,
			name: facility.name,
			displayTitle: displayName.title,
			displaySubtitle: displayName.subtitle,
			address: facility.location.address,
			availableSpaces: vacancy.available,
			totalSpaces: vacancy.total,
			occupancyRatio: vacancy.occupancy,
			availabilityStatus: facility.availabilityStatus.rawValue,
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

	/// Get all facility IDs currently displayed in widgets
	/// Uses a short-lived cache to avoid repeated UserDefaults reads during view rendering
	func getWidgetFacilityIDs() -> [String] {
		// Return cached value if still valid
		if let cached = _cachedWidgetIds,
		   Date().timeIntervalSince(_widgetIdsCacheTime) < widgetIdsCacheValidity {
			return cached
		}

		guard let userDefaults = sharedDefaults else {
			Logger.widget.warning("Couldn't find user defaults.")
			return []
		}

		let ids = userDefaults.stringArray(forKey: Self.widgetFacilityIdsKey) ?? []
		_cachedWidgetIds = ids
		_widgetIdsCacheTime = Date()
		return ids
	}

	/// Invalidates the widget ID cache, forcing a fresh read on next access
	func invalidateWidgetIdsCache() {
		_cachedWidgetIds = nil
	}

	/// Check if a facility is currently displayed in any widget
	func isCurrentlyInWidget(_ facilityId: String) -> Bool {
		return getWidgetFacilityIDs().contains(facilityId)
	}

	/// Check if a facility is in a widget (nonisolated for use from SwiftData models)
	/// Reads directly from UserDefaults without cache for thread safety
	nonisolated static func isInWidget(_ facilityId: String) -> Bool {
		guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
			return false
		}
		let ids = defaults.stringArray(forKey: widgetFacilityIdsKey) ?? []
		return ids.contains(facilityId)
	}
}
