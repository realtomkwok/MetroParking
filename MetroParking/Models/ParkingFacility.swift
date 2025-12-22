//
//  ParkingFacility.swift
//  MetroParking
//
//	Data model definitions for parking facilities provided by TfNSW.
//
//  Created by Tom Kwok on 19/6/2025.
//

import Foundation
import MapKit
import OSLog
import SwiftData
import SwiftUI

@Model
final class ParkingFacility {
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
	var notificationThreshold: Int?  // TODO: For feature "notify when under X spaces"
	var lastVisited: Date?

	// Occupancy cache - stored properties
	private var _cachedOccupied: Int = 0
	private var _cacheTimestamp: Date = Date.distantPast

	// Refresh tracking - stored properties
	private var _lastRefreshed: Date = Date.distantPast
	private var _lastUpdated: Date = Date.distantPast
	private var _retrievalFailures: Int = 0
	private var _lastFailureDate: Date?

	// Route caching - stored properties
	private var _routeDistance: CLLocationDistance?
	private var _routeTravelTime: TimeInterval?
	private var _routeTimestamp: Date?

	@Relationship(deleteRule: .cascade, inverse: \ParkingZone.facility)
	var zones: [ParkingZone] = []

	// MARK: - Initialisers

	// From API
	init(from apiResponse: ParkingAPIResponse) {
		self.facilityId = apiResponse.facilityId
		self.name = apiResponse.facilityName
		self._suburb = apiResponse.location.suburb
		self._address = apiResponse.location.address
		self._latitude = Double(apiResponse.location.latitude) ?? 0
		self._longitude = Double(apiResponse.location.longitude) ?? 0
		self.totalSpaces = Int(apiResponse.spots) ?? 0

		let dateFormatter = ISO8601DateFormatter()
		self._lastUpdated =
			dateFormatter.date(from: apiResponse.messageDate) ?? Date()
		self.lastVisited = nil

		self.isFavourite = false
		self.notificationThreshold = nil

	}

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
		self.notificationThreshold = nil
	}

	// MARK: - Nested Types

	/// Location information for a parking facility
	struct Location {
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

		var isValid: Bool {
			calculatedAt.timeIntervalSinceNow > -3600  // Valid for 1 hour
		}

		var formattedDistance: String {
			let formatter = MKDistanceFormatter()
			formatter.unitStyle = .abbreviated
			return formatter.string(fromDistance: distance)
		}

		var formattedTravelTime: String {
			let duration: Duration = .seconds(travelTime)
			return duration.formatted(.units(width: .wide))
		}
	}

	/// Refresh and update tracking information
	struct RefreshStatus {
		let lastRefreshed: Date
		let lastUpdated: Date
		let failures: Int
		let lastFailureDate: Date?

		var timeSinceRefresh: TimeInterval {
			Date().timeIntervalSince(lastRefreshed)
		}

		var hasRecentFailures: Bool {
			failures > 0
				&& lastFailureDate?.timeIntervalSinceNow ?? -.infinity > -300  // Within 5 min
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

		var isCacheValid: Bool {
			let cacheAge = Date().timeIntervalSince(cacheTimestamp)
			return cacheAge < tier.cacheValiditySeconds
		}

		var shouldShowData: Bool {
			let cacheAge = Date().timeIntervalSince(cacheTimestamp)
			// Show if valid OR within 2x validity with some spaces
			return isCacheValid
				|| (cacheAge < tier.cacheValiditySeconds * 2 && available > 0)
		}

		var displayText: String {
			shouldShowData ? String(available) : "--"
		}
	}

	// MARK: - Computed Properties

	/// Consolidated location information
	var location: Location {
		Location(
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
		return RouteInfo(
			distance: distance,
			travelTime: travelTime,
			calculatedAt: timestamp
		)
	}

	/// Refresh status information
	var refreshStatus: RefreshStatus {
		RefreshStatus(
			lastRefreshed: _lastRefreshed,
			lastUpdated: _lastUpdated,
			failures: _retrievalFailures,
			lastFailureDate: _lastFailureDate
		)
	}

	var displayName: (title: String, subtitle: String) {
		let stripped = name.removePrefix("Park&Ride - ").localizedCapitalized

		// Match pattern: "Title (Subtitle)"
		// Captures: title before parentheses, and subtitle inside parentheses
		let pattern = /^(.+?)\s*\((.+?)\)$/

		if let match = stripped.firstMatch(of: pattern) {
			let title = String(match.1).trimmingCharacters(in: .whitespaces)
			let subtitle = String(match.2).trimmingCharacters(in: .whitespaces)
			return (title: title, subtitle: subtitle)
		} else {
			// No parentheses found
			return (title: stripped, subtitle: "")
		}
	}

	// Convenience accessors for backward compatibility and cleaner access
	var coordinate: CLLocationCoordinate2D { location.coordinate }
	var suburb: String { _suburb }
	var address: String { _address }
	var latitude: Double { _latitude }
	var longitude: Double { _longitude }

	/// Distance for sorting purposes (returns the cached route distance, or Double.infinity if not available)
	/// This allows sorting by distance with nil values appearing at the end
	var sortableDistance: Double {
		_routeDistance ?? Double.infinity
	}

	var availabilityStatus: AvailabilityStatus {
		let vacancyInfo = vacancy

		guard vacancyInfo.shouldShowData else {
			return .noData
		}

		let available = vacancyInfo.available

		if available == 0 {
			return .full
		} else if available < totalSpaces / 10 {
			return .almostFull
		} else {
			return .available
		}
	}

	// MARK: - Refresh Priority

	var refreshTier: RefreshTier {
		// Set critical -> Favourites OR displayed in any widget
		if self.isFavourite { return .critical }
		if SharedDataManager.shared.isCurrentlyInWidget(self.facilityId) {
			return .critical
		}

		// Standard: recently visited (within 1 hour)
		if let lastVisited = self.lastVisited,
		   lastVisited.timeIntervalSinceNow > -3600 {

			return .standard
		}

		return .background
	}

	// TODO: Localisation
	var formattedLastUpdated: String {
		return _lastUpdated == .distantPast
			? "--"
			: "updated \(_lastUpdated.formatted(.relative(presentation: .numeric, unitsStyle: .narrow)))"
	}

}

// MARK: - Data Refresh
extension ParkingFacility {

	/// Returns an MKMapItem for this facility
	/// - Returns: A configured MKMapItem with the facility's location and details
	func getMapItem() async -> MKMapItem {
		return await MapsManager.shared.createMapItem(for: self)
	}

	func updateFromAPI(_ apiResponse: ParkingAPIResponse) {
		// Update occupancy (single source of truth)
		let newOccupied = Int(apiResponse.occupancy.total ?? "0") ?? 0
		_cachedOccupied = newOccupied
		_cacheTimestamp = Date()

		// Update persistent data
		_lastUpdated = Date()
		_lastRefreshed = Date()
		_retrievalFailures = 0
		_lastFailureDate = nil

		// Update total spaces if it changed
		let newTotalSpaces = Int(apiResponse.spots) ?? self.totalSpaces
		if newTotalSpaces != self.totalSpaces {
			self.totalSpaces = newTotalSpaces
		}
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
		travelTime: TimeInterval
	) {
		self._routeDistance = distance
		self._routeTravelTime = travelTime
		self._routeTimestamp = Date()
	}

	func clearStaleRoutingData() {
		if route?.isValid == false {
			self._routeDistance = nil
			self._routeTravelTime = nil
			self._routeTimestamp = nil
		}
	}
}

// RefreshTier is defined in RefreshConfiguration.swift

// MARK: - Availability Status
// Statuses of availability are based on TfNSW recommendation
// Full: vacancy < 1
// Almost full: vacancy < 10% of total

enum AvailabilityStatus: CaseIterable {
	case available, almostFull, full, noData

	var fill: Color {
		switch self {
		case .available: return .green
		case .almostFull: return .yellow
		case .full: return .red
		case .noData: return Color(.tertiarySystemBackground)
		}
	}

	/// Returns an appropriate text color that contrasts with the status color
	var foreground: Color {
		switch self {
		case .noData: return .secondary.opacity(0.6)
		default:
			return fill.adaptedTextColor()
		}
	}

	var text: String {
		switch self {
		case .available: return "Available"
		case .almostFull: return "Almost Full"
		case .full: return "Full"
		case .noData: return "No Data"
		}
	}

	/// Returns colors for the occupancy gradient (excludes noData)
	static var gradientColors: [Color] {
		return [available.fill, almostFull.fill, full.fill]
	}

	/// Returns all status colors including noData
	static var allColors: [Color] {
		return allCases.map { $0.fill }
	}
}
