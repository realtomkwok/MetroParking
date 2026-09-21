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
import Synchronization
import WidgetKit

@MainActor
final class SharedDataManager {

	// App Group - nonisolated for access from non-MainActor contexts
	nonisolated static let appGroupIdentifier: String = "group.com.tomkwok.MetroParking"

	static let shared = SharedDataManager()

	// MARK: - Widget ID Cache (reduces UserDefaults reads)
	private var _cachedWidgetIds: [String]?
	private var _widgetIdsCacheTime: Date = .distantPast
	private let widgetIdsCacheValidity: TimeInterval = 2.0  // 2 seconds TTL

	private init() {}

	// MARK: - SwiftData Container

	/// Shared ModelContainer used by the app, background tasks and the widget,
	/// so every target reads the same store in the App Group.
	///
	/// SwiftData's lightweight migration handles additive model changes. If the
	/// store can't be opened at all (e.g. an incompatible schema), it is deleted
	/// and rebuilt: facility data is re-fetched from the API, but pinned car
	/// parks are lost, so this is logged as a fault. As a last resort the app
	/// runs on an in-memory store instead of crashing.
	nonisolated static let sharedContainer: ModelContainer = {
		let schema = Schema([
			ParkingFacility.self,
			ParkingZone.self,
		])

		let configuration = ModelConfiguration(
			schema: schema,
			isStoredInMemoryOnly: false,
			groupContainer: .identifier(appGroupIdentifier)
		)

		do {
			return try ModelContainer(for: schema, configurations: [configuration])
		} catch {
			Logger.facilityData.fault(
				"⚠️ Could not open the data store, rebuilding it: \(error.localizedDescription)"
			)
		}

		destroyStore(at: configuration.url)

		do {
			return try ModelContainer(for: schema, configurations: [configuration])
		} catch {
			Logger.facilityData.fault(
				"❌ Could not rebuild the data store, using memory only: \(error.localizedDescription)"
			)
			let inMemory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
			// An in-memory store with a valid schema can't fail to open.
			return try! ModelContainer(for: schema, configurations: [inMemory])
		}
	}()

	/// Removes a SQLite store and its sidecar files.
	nonisolated private static func destroyStore(at url: URL) {
		let fileManager = FileManager.default
		for suffix in ["", "-wal", "-shm"] {
			let fileURL = URL(fileURLWithPath: url.path + suffix)
			try? fileManager.removeItem(at: fileURL)
		}
	}

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

		/// Data older than the watched tier's background validity is shown as stale.
		var isStale: Bool {
			Date().timeIntervalSince(cacheTimestamp)
				> RefreshConfiguration.CacheValidity.Background.watched
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
		guard APIUsageMonitor.canMakeCall else {
			Logger.widget.warning("⚠️ Widget: daily API limit reached, using cached data")
			return nil
		}

		do {
			APIUsageMonitor.recordCall()
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
		Self.widgetIdCache.withLock { $0.readAt = .distantPast }
	}

	/// Check if a facility is currently displayed in any widget
	func isCurrentlyInWidget(_ facilityId: String) -> Bool {
		return getWidgetFacilityIDs().contains(facilityId)
	}

	/// Short-lived cache of widget facility IDs. `refreshTier` reads this from
	/// sort comparators, filters and every list row, so it must not hit
	/// UserDefaults each time.
	nonisolated private static let widgetIdCache = Mutex(
		(ids: Set<String>(), readAt: Date.distantPast)
	)
	nonisolated private static let widgetIdCacheValidity: TimeInterval = 2

	/// Whether a facility is shown in any widget. Safe to call from any context.
	nonisolated static func isInWidget(_ facilityId: String) -> Bool {
		widgetIdCache.withLock { cache in
			if Date().timeIntervalSince(cache.readAt) >= widgetIdCacheValidity {
				let defaults = UserDefaults(suiteName: appGroupIdentifier)
				cache = (Set(defaults?.stringArray(forKey: widgetFacilityIdsKey) ?? []), Date())
			}
			return cache.ids.contains(facilityId)
		}
	}
}
