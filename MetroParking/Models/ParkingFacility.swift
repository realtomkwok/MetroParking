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
import SwiftData
import OSLog

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

	/// Route caching
	var lastCalculatedDistance: CLLocationDistance?
	var lastCalculatedTravelTime: TimeInterval?
	var routingDataAge: Date?

	private var _cachedOccupancy: Int = 0
	private var _cachedAvailableSpots: Int = 0
	private var _occupancyCacheTime: Date = Date.distantPast
	private var occupancyCacheValidityMinutes: TimeInterval = 15

	@Relationship(deleteRule: .cascade, inverse: \ParkingZone.facility)
	var zones: [ParkingZone] = []

	/// Computed properties
	var displayName: String {
		return name.removePrefix("Park&Ride - ").localizedCapitalized
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

	var isOccupancyCacheValid: Bool {
		let cacheAge = Date().timeIntervalSince(_occupancyCacheTime)
		return cacheAge < (occupancyCacheValidityMinutes * 60)
	}

	var timeSinceLastRefresh: TimeInterval {
		return Date().timeIntervalSince(lastRefreshed)
	}

	var hasRecentFailures: Bool {
		return retrievalFailures > 0
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

	init(from staticInfo: StaticFacilityInfo) {
		self.facilityId = staticInfo.facilityId
		self.name = staticInfo.name
		self.tsn = staticInfo.tsn
		self.tfnswFacilityId = staticInfo.tfnswFacilityId
		self.suburb = staticInfo.suburb
		self.address = staticInfo.address
		self.latitude = staticInfo.latitude
		self.longitude = staticInfo.longitude
		self.totalSpaces = staticInfo.totalSpaces
		self.lastUpdated = Date.distantPast  // No occupancy data yet
		self.isFavourite = false
		self.lastVisited = nil
		self.notificationThreshold = nil
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
		if isOccupancyCacheValid {
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

	var hasValidSpotData: Bool {
		return currentAvailableSpots >= 0
	}

	var occupancy: Double {
		guard totalSpaces > 0 else { return 0.0 }
		guard isOccupancyCacheValid else { return -1.0 }

		let occupancy = Double(currentOccupiedSpots) / Double(totalSpaces)

		return max(0, occupancy)
	}

	var occupancyStatus: String {
		switch occupancy {
		case 0.0..<0.3:
			return "Low"
		case 0.3..<0.7:
			return "Moderate"
		case 0.7..<0.9:
			return "Almost Full"
		default:
			return "Full"
		}
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
