//
//  ParkingFacility.swift
//  MetroParking
//
//	Data model definitions for parking facilities provided by TfNSW.
//
//  Created by Tom Kwok on 19/6/2025.
//

import CoreLocation
import Foundation
import OSLog
import SwiftData
import SwiftUI

@Model
nonisolated final class ParkingFacility {
	@Attribute(.unique) var facilityId: String
	var name: String

	// Location data - stored properties for SwiftData
	var _latitude: Double
	var _longitude: Double
	var _suburb: String
	var _address: String

	var totalSpaces: Int

	// User preferences
	var isFavourite: Bool
	var lastVisited: Date?

	// Occupancy cache - stored properties
	private var _cachedOccupied: Int = 0
	private var _cacheTimestamp: Date = Date.distantPast

	// Refresh tracking - stored properties
	private var _lastUpdated: Date = Date.distantPast
	private var _retrievalFailures: Int = 0
	private var _lastFailureDate: Date?

	// Route caching - stored properties
	private var _routeOriginLatitude: CLLocationDegrees?
	private var _routeOriginLongitude: CLLocationDegrees?
	private var _routeDistance: CLLocationDistance?
	private var _routeTravelTime: TimeInterval?
	private var _routeTimestamp: Date?

	// Display name cache - avoids regex parsing on every access
	private var _displayTitle: String = ""
	private var _displaySubtitle: String = ""
	private var _displayFullName: String = ""

	@Relationship(deleteRule: .cascade, inverse: \ParkingZone.facility)
	var zones: [ParkingZone] = []

	// MARK: - Initialiser

	// Direct init for static facilities (initial load)
	init(
		facilityId: String,
		name: String,
		suburb: String,
		address: String,
		latitude: Double,
		longitude: Double,
		totalSpaces: Int
	) {
		self.facilityId = facilityId
		self.name = name
		self._suburb = suburb
		self._address = address
		self._latitude = latitude
		self._longitude = longitude
		self.totalSpaces = totalSpaces
		self._lastUpdated = Date.distantPast
		self.lastVisited = nil
		self.isFavourite = false

		/// Parse display name once during initialisation
		self._parseAndCacheDisplayName()
	}

	/// Parses the facility name and caches the display title/subtitle
	/// Called once during initialisation to avoid regex parsing on every access
	private func _parseAndCacheDisplayName() {
		let parsed = Self.parseDisplayName(name)
		_displayFullName = parsed.full
		_displayTitle = parsed.title
		_displaySubtitle = parsed.subtitle
	}

	/// Splits a TfNSW facility name into a display title and subtitle.
	/// e.g. "Park&Ride - Gordon Henry St (north)" → ("Gordon Henry St", "North")
	static func parseDisplayName(_ name: String) -> (
		title: String, subtitle: String, full: String
	) {
		let stripped = name.removePrefix("Park&Ride - ").localizedCapitalized

		if let match = stripped.firstMatch(of: /^(.+?)\s*\((.+?)\)$/) {
			return (
				title: String(match.1).trimmingCharacters(in: .whitespaces),
				subtitle: String(match.2).trimmingCharacters(in: .whitespaces),
				full: stripped
			)
		}
		return (title: stripped, subtitle: "", full: stripped)
	}

	// MARK: - Nested Types

	/// Location information for a parking facility
	struct LocationInfo {
		let coordinate: CLLocationCoordinate2D
		let suburb: String
		let address: String

		var latitude: Double { coordinate.latitude }
		var longitude: Double { coordinate.longitude }
	}

	/// Route information to a parking facility
	struct RouteInfo {
		let distance: CLLocationDistance
		let travelTime: TimeInterval
		let calculatedAt: Date
		let originCoordinate: CLLocationCoordinate2D?

		func isValid(from currentLocation: CLLocationCoordinate2D?) -> Bool {
//			guard let currentLocation else { return isValid }
			let withinTimeLimit = calculatedAt.timeIntervalSinceNow > -3600
			guard withinTimeLimit else { return false }

			if let origin = originCoordinate, let current = currentLocation {
				let originCL = CLLocation(
					latitude: origin.latitude,
					longitude: origin.longitude
				)
				let currentCL = CLLocation(
					latitude: current.latitude,
					longitude: current.longitude
				)

				return originCL.distance(from: currentCL) < 500
			}
			// No new location available to compare - trust the time check
			return true
		}
	}

	/// Data staleness level for UI presentation
	enum DataStaleness {
		case fresh  // Within cache validity period
		case stale  // Beyond cache validity, needs refresh

		/// Visual opacity for displaying stale data
		var displayOpacity: Double {
			switch self {
			case .fresh: return 1.0
			case .stale: return 0.6
			}
		}
	}

	/// Refresh and update tracking information
	struct RefreshStatus {
		let lastUpdated: Date
		let failures: Int
		let lastFailureDate: Date?
		let cacheTimestamp: Date
		let tier: RefreshTier

		var timeSinceLastUpdate: TimeInterval {
			Date().timeIntervalSince(lastUpdated)
		}

		/// Determines staleness level based on cache age and tier
		var staleness: DataStaleness {
			let cacheAge = Date().timeIntervalSince(cacheTimestamp)

			// Never had data
			if cacheTimestamp == .distantPast {
				return .stale
			}

			// Check if within cache validity period for this tier
			if cacheAge < tier.cacheValiditySeconds {
				return .fresh
			}

			return .stale
		}
	}

	/// Structured vacancy information with caching
	struct VacancyInfo {
		let available: Int
		let occupied: Int
		let total: Int
		let cacheTimestamp: Date
		let tier: RefreshTier

		var vacancy: Int { available }
		var occupancy: Double {
			guard total > 0 else { return 0.0 }
			return max(0, min(1.0, Double(occupied) / Double(total)))
		}

		var isValid: Bool { available >= 0 }

		/// Check if cache is valid for foreground operations (uses foreground cache validity)
		var isCacheValid: Bool {
			let cacheAge = Date().timeIntervalSince(cacheTimestamp)
			return cacheAge < tier.cacheValiditySeconds
		}

		/// Check if cache is valid with context-aware validity duration
		/// - Parameter appState: Current app state (active uses foreground validity, background uses background validity)
		/// - Returns: true if cache is still valid for the given app state
		func isCacheValid(for appState: AppState) -> Bool {
			let cacheAge = Date().timeIntervalSince(cacheTimestamp)
			let validity: TimeInterval

			switch appState {
			case .active:
				validity = tier.cacheValiditySeconds
			case .background:
				validity = tier.backgroundCacheValiditySeconds
			}

			return cacheAge < validity
		}
	}

	// MARK: - Computed Properties

	/// Consolidated location information
	var location: LocationInfo {
		LocationInfo(
			coordinate: CLLocationCoordinate2D(
				latitude: _latitude,
				longitude: _longitude
			),
			suburb: _suburb,
			address: _address
		)
	}

	/// Consolidated vacancy information (single source of truth)
	var vacancy: VacancyInfo {
		let available = max(0, totalSpaces - _cachedOccupied)
		return VacancyInfo(
			available: available,
			occupied: _cachedOccupied,
			total: totalSpaces,
			cacheTimestamp: _cacheTimestamp,
			tier: refreshTier
		)
	}

	/// Route information if available
	var route: RouteInfo? {
		guard let distance = _routeDistance,
			let travelTime = _routeTravelTime,
			let timestamp = _routeTimestamp
		else {
			return nil
		}

		let origin: CLLocationCoordinate2D? = {
			guard let lat = _routeOriginLatitude, let lng = _routeOriginLongitude else {
				return nil
			}
			return CLLocationCoordinate2D(latitude: lat, longitude: lng)
		}()

		return RouteInfo(
			distance: distance,
			travelTime: travelTime,
			calculatedAt: timestamp,
			originCoordinate: origin
		)
	}

	/// Refresh status information
	var refreshStatus: RefreshStatus {
		RefreshStatus(
			lastUpdated: _lastUpdated,
			failures: _retrievalFailures,
			lastFailureDate: _lastFailureDate,
			cacheTimestamp: _cacheTimestamp,
			tier: refreshTier
		)
	}

	/// The parsed display name (title and subtitle), stored at initialisation.
	/// Rows saved before these fields existed are parsed on the fly without
	/// writing, so reading this from a view body or sort never mutates the model.
	var displayName: (title: String, subtitle: String, full: String) {
		guard !_displayFullName.isEmpty else {
			return Self.parseDisplayName(name)
		}
		return (
			title: _displayTitle, subtitle: _displaySubtitle,
			full: _displayFullName
		)
	}

	/// Distance for sorting purposes (returns the cached route distance, or Double.infinity if not available)
	/// This allows sorting by distance with nil values appearing at the end
	var sortableDistance: Double {
		_routeDistance ?? Double.infinity
	}

	var availabilityStatus: AvailabilityStatus {
		let vacancyInfo = vacancy

		// Only return .noData if we've NEVER had data (not just stale)
		guard _cacheTimestamp != .distantPast else {
			return .noData
		}

		// For stale data, still show the status but UI should indicate staleness
		return AvailabilityStatus(available: vacancyInfo.available, total: totalSpaces)
	}

	// MARK: - Refresh Priority (2-Tier System)

	/// Determines the refresh tier for this facility
	///
	/// Two tiers:
	/// - **watched**: Favourites OR displayed in any widget (actively monitored)
	/// - **unwatched**: Everything else (refresh on-demand when visible)
	var refreshTier: RefreshTier {
		// Watched: Favourites OR displayed in any widget
		if self.isFavourite { return .watched }
		if SharedDataManager.isInWidget(self.facilityId) {
			return .watched
		}

		return .unwatched
	}

	/// Whether this facility was recently visited (within 1 hour)
	/// Used for prioritising visible facilities in refresh cycle
	var isRecentlyVisited: Bool {
		guard let lastVisited = self.lastVisited else { return false }
		return lastVisited.timeIntervalSinceNow > -3600
	}

}

// MARK: - Data Refresh
extension ParkingFacility {

	// TODO: Should remove the totalSpaces parameter?
	func updateOccupancy(occupied: Int, totalSpaces: Int) {
		_cachedOccupied = occupied
		_cacheTimestamp = Date()
		_lastUpdated = Date()
		_retrievalFailures = 0
		_lastFailureDate = nil

		if totalSpaces != self.totalSpaces {
			self.totalSpaces = totalSpaces
		}
	}

	/// Determines if this facility should be refreshed based on app state and cache validity
	/// Centralises the refresh decision logic used across FacilityManager and BackgroundTaskManager
	/// - Parameters:
	///   - appState: Current app lifecycle state (active uses foreground cache validity, background uses background cache validity)
	///   - forced: Whether to force refresh regardless of cache (applies only to watched facilities)
	/// - Returns: true if facility should be refreshed
	func shouldRefresh(appState: AppState, forced: Bool = false) -> Bool {
		// Forced refresh only applies to watched tier facilities
		if forced && refreshTier == .watched {
			return true
		}

		// Otherwise check cache validity for current app state
		return !vacancy.isCacheValid(for: appState)
	}

	func markRefreshFailed() {
		_retrievalFailures += 1
		_lastFailureDate = Date()

		// Don't immediately invalidate cache on first few failures
		// This prevents showing "noData" when API is temporarily down
		if _retrievalFailures >= 3 {
			// Force cache invalidation after repeated failures
			_cacheTimestamp = Date.distantPast
		}

		Logger.facilityRefresh.error(
			"❌ \(self.name): Failure #\(self._retrievalFailures)"
		)
	}

	func markAsVisited() {
		lastVisited = Date()
	}
}

// MARK: - Route Management
extension ParkingFacility {

	func updateRoutingData(
		distance: CLLocationDistance,
		travelTime: TimeInterval,
		from origin: CLLocationCoordinate2D? = nil
	) {
		self._routeDistance = distance
		self._routeTravelTime = travelTime
		self._routeTimestamp = Date()
		self._routeOriginLatitude = origin?.latitude
		self._routeOriginLongitude = origin?.longitude
	}

	func clearRoutingData() {
		self._routeTimestamp = nil
		self._routeDistance = nil
		self._routeTravelTime = nil
		self._routeOriginLatitude = nil
		self._routeOriginLongitude = nil
	}
}

// RefreshTier is defined in RefreshConfiguration.swift

// MARK: - Availability Status
// Statuses of availability are based on TfNSW recommendation
// Full: vacancy < 1
// Almost full: vacancy < 10% of total

/// Stored by raw value in the widget cache, so keep raw values stable.
nonisolated enum AvailabilityStatus: String, CaseIterable, Codable, Sendable {
	case available, almostFull, full, noData

	/// Status for a known occupancy reading. Single source of the thresholds
	/// shared by the app and the widget.
	init(available: Int, total: Int) {
		if total <= 0 {
			self = .noData
		} else if available <= 0 {
			self = .full
		} else if available < total / 10 {
			self = .almostFull
		} else {
			self = .available
		}
	}

	var fill: Color {
		switch self {
		case .available: return .green
		case .almostFull: return .yellow
		case .full: return .red
		case .noData: return Color(.tertiarySystemBackground)
		}
	}

	var text: String {
		switch self {
		case .available: return String(localized: .availabilityStatusAvailable)
		case .almostFull:
			return String(localized: .availabilityStatusAlmostFull)
		case .full: return String(localized: .availabilityStatusFull)
		case .noData: return String(localized: .availabilityStatusNoData)
		}
	}

	static let gradient = Gradient(colors: [
		available.fill, almostFull.fill, full.fill,
	])
}
