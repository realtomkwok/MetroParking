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

@Model
final class ParkingFacility {
	var facilityId: String
	var name: String
	var tsn: String
	var tfnswFacilityId: String

	var suburb: String
	var address: String
	var latitude: Double
	var longitude: Double

	var totalSpaces: Int
	var lastUpdated: Date
	var lastVisited: Date?

	var isFavourite: Bool
	var notificationThreshold: Int?  // For feature "notify when under X spaces"

	var lastRefreshed: Date = Date.distantPast
	var retrievalFailures: Int = 0
	var lastFailureDate: Date?

	// Route caching
	var lastCalculatedDistance: CLLocationDistance?
	var lastCalculatedTravelTime: TimeInterval?
	var routingDataAge: Date?

	// Occupancy cache
	private var _cachedOccupancy: Int = 0
	private var _cachedAvailableSpots: Int = 0
	private var _occupancyCacheTime: Date = Date.distantPast

	@Relationship(deleteRule: .cascade, inverse: \ParkingZone.facility)
	var zones: [ParkingZone] = []

	// MARK: - Initialisers

	// From API
	init(from apiResponse: ParkingAPIResponse) {
		self.facilityId = apiResponse.facilityId
		self.name = apiResponse.facilityName
		self.tsn = apiResponse.tsn
		self.tfnswFacilityId = apiResponse.tfnswFacilityId
		self.suburb = apiResponse.location.suburb
		self.address = apiResponse.location.address
		self.latitude = Double(apiResponse.location.latitude) ?? 0
		self.longitude = Double(apiResponse.location.longitude) ?? 0
		self.totalSpaces = Int(apiResponse.spots) ?? 0

		let dateFormatter = ISO8601DateFormatter()
		self.lastUpdated =
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
		totalSpaces: Int,
		tsn: String,
		tfnswFacilityId: String
	) {
		self.facilityId = facilityId
		self.name = name
		self.tsn = tsn
		self.tfnswFacilityId = tfnswFacilityId
		self.suburb = suburb
		self.address = address
		self.latitude = latitude
		self.longitude = longitude
		self.totalSpaces = totalSpaces
		self.lastUpdated = Date.distantPast
		self.lastVisited = nil
		self.isFavourite = false
		self.notificationThreshold = nil
	}

	// MARK: - Computed properties
	var displayName: String {
		return name.removePrefix("Park&Ride - ").localizedCapitalized
	}

	var coordinate: CLLocationCoordinate2D {
		return CLLocationCoordinate2D(
			latitude: latitude,
			longitude: longitude
		)
	}

	var availabilityStatus: AvailabilityStatus {
		let available = currentAvailableSpots
		let total = totalSpaces

		if available >= 0 {
			if available == 0 {
				return .full
			} else if available < total / 10 {
				return .almostFull
			} else {
				return .available
			}
		} else {
			return .noData
		}
	}

	// MARK: - Refresh priority tier
	var refreshTier: RefreshTier {
		if self.isFavourite { return .critical }
		if self.lastVisited?.timeIntervalSinceNow ?? -3600 > 3600 {
			return .standard
		}
		return .background
	}

	var isOccupancyCacheValid: Bool {
		let cacheAge = Date().timeIntervalSince(_occupancyCacheTime)
		return cacheAge < refreshTier.cacheValiditySeconds
	}

	var shouldShowCachedData: Bool {
		// Show cached data if:
		// 1. Cache is valid, OR
		// 2. Cache is recently expired (grace period) AND we have previous data
		if isOccupancyCacheValid {
			return true
		}

		// Grace period: show old data for up to 2x cache validity time
		let gracePeriod = refreshTier.cacheValiditySeconds * 2
		let cacheAge = Date().timeIntervalSince(_occupancyCacheTime)
		return cacheAge < gracePeriod && _cachedAvailableSpots > 0
	}

	var timeSinceLastRefresh: TimeInterval {
		return Date().timeIntervalSince(lastRefreshed)
	}

	var hasValidRoutingData: Bool {
		guard let age = routingDataAge else { return false }
		return age.timeIntervalSinceNow > -3600/// Valid for an hour
	}

	// TODO: Localisation
	var formattedLastUpdated: String {
		return lastUpdated == .distantPast
			? "--"
			: "updated \(lastUpdated.formatted(.relative(presentation: .numeric, unitsStyle: .narrow)))"
	}

	// MARK: - MapKit

	var mapItem: MKMapItem {
		let coordinate = CLLocationCoordinate2D(
			latitude: latitude,
			longitude: longitude
		)
		let placeMark = MKPlacemark(coordinate: coordinate)

		// TODO: .init(placemark: placemark) is deprecated, there's a new method for creating a MapItem
		let item = MKMapItem(placemark: placeMark)
		item.name = displayName
		return item
	}
}

/// Data refresh
extension ParkingFacility {

	func updateFromAPI(_ apiResponse: ParkingAPIResponse) {
		// Update occupancy cache
		self.currentOccupiedSpots = Int(apiResponse.occupancy.total ?? "0") ?? 0

		// Update persistent data
		self.lastUpdated = Date()
		self.lastRefreshed = Date()
		self.retrievalFailures = 0
		self.lastFailureDate = nil

		// Update total spaces if it changed
		let newTotalSpaces = Int(apiResponse.spots) ?? self.totalSpaces
		if newTotalSpaces != self.totalSpaces {
			self.totalSpaces = newTotalSpaces
		}
	}

	func markRefreshFailed() {
		retrievalFailures += 1
		lastFailureDate = Date()

		// Don't immediately invalidate cache on first few failures
		// This prevents showing "noData" when API is temporarily down
		if retrievalFailures >= 3 {
			// Force cache invalidation after repeated failures
			_occupancyCacheTime = Date.distantPast
		}

		Logger.facilityRefresh.error(
			"❌ \(self.name): Failure #\(self.retrievalFailures)"
		)
	}

	func markAsVisited() {
		lastVisited = Date()
	}
}

/// Occupancy and availability
extension ParkingFacility {

	var currentOccupiedSpots: Int {
		get {
			if isOccupancyCacheValid {
				return _cachedOccupancy
			}
			return 0
		}
		set {
			_cachedOccupancy = newValue
			_occupancyCacheTime = Date()
			_cachedAvailableSpots = max(0, totalSpaces - newValue)
		}
	}

	var currentAvailableSpots: Int {
		if shouldShowCachedData {
			return _cachedAvailableSpots
		} else {
			return -1
		}
	}

	var displayAvailableSpots: String {
		if currentAvailableSpots == -1 {
			return "--"  // TODO: Localisation strings
		} else {
			return String(currentAvailableSpots)
		}
	}

	var occupancy: Double {
		guard totalSpaces > 0 else { return 0.0 }
		guard isOccupancyCacheValid else { return -1.0 }

		let occupancy = Double(currentOccupiedSpots) / Double(totalSpaces)

		return max(0, occupancy)
	}
}

/// Route Enhancement
extension ParkingFacility {

	func updateRoutingData(
		distance: CLLocationDistance,
		travelTime: TimeInterval
	) {
		self.lastCalculatedDistance = distance
		self.lastCalculatedTravelTime = travelTime
		self.routingDataAge = Date()
	}

	func clearStaleRoutingData() {
		if !hasValidRoutingData {
			self.lastCalculatedDistance = nil
			self.lastCalculatedTravelTime = nil
			self.routingDataAge = nil
		}
	}
}

enum RefreshTier: CaseIterable {
	case critical
	case standard
	case background

	var cacheValiditySeconds: TimeInterval {
		switch self {
		case .critical: return 15  // 15 sec
		case .standard: return 60  // 1 min
		case .background: return 600  // 10 min
		}
	}
}
