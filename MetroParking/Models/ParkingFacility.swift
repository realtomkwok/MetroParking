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

	var refreshTierType: String = "standard"
	var lastRefreshed: Date = Date.distantPast
	var nextScheduledRefresh: Date = Date.distantPast
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
	
	var refreshTier: RefreshTier {
		switch refreshTierType {
			case "realTime": return .realTime
			case "standard": return .standard
			case "idle": return .idle
			case "onDemand": return .onDemand
			default: return .standard
		}
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

	var isDueForRefresh: Bool {
		return Date() >= nextScheduledRefresh
	}

	var timeSinceLastRefresh: TimeInterval {
		return Date().timeIntervalSince(lastRefreshed)
	}

	var hasRecentFailures: Bool {
		return retrievalFailures > 0
	}
	
	var hasValidRoutingData: Bool {
		guard let age = routingDataAge else { return false }
		return age.timeIntervalSinceNow > -3600		/// Valid for an hour
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
		
		self.classifyRefreshTier()
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
		
		self.classifyRefreshTier()
	}
}

/// Data refresh
extension ParkingFacility {
	
	func classifyRefreshTier() {
		let highFrequencyFacilities = [
			"Gordon", "Kiama", "Mona Vale", "Warriewood",
		]

		for facility in highFrequencyFacilities {
			if name.contains(facility) {
				refreshTierType = isFavourite ? "realTime" : "standard"
				return
			}
		}

		if isFavourite {
			refreshTierType = "standard"
		} else if totalSpaces > 1000 {
			refreshTierType = "standard"
		}  // TODO: Should use the average occupancy?
		else {
			refreshTierType = "idle"
		}
	}

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

	func scheduleNextRefresh(appState: AppState = .active) {
		let baseInterval: TimeInterval =
			switch refreshTier {
			case .realTime:
				appState == .active ? 15 : 60
			case .standard:
				appState == .active ? 600 : 1800
			case .idle:
				appState == .active ? 1800 : 3600
			case .onDemand:
				.infinity
			}

		guard baseInterval != .infinity else {
			nextScheduledRefresh = Date.distantFuture
			return
		}

		let priorityMultiplier = isFavourite ? 0.5 : 1.0

		/// Exponential backoff for retries when failed
		let failureMultiplier =
			retrievalFailures > 0
			? pow(
				2.0,
				Double(min(retrievalFailures, refreshTier.maxFailureBackoff))
			)
			: 1.0

		let finalInterval =
			baseInterval * priorityMultiplier * failureMultiplier
		self.nextScheduledRefresh = Date().addingTimeInterval(finalInterval)

		print(
			"📅 \(name) [\(refreshTier)]: Next refresh in \(Int(finalInterval))s (failures: \(retrievalFailures))"
		)
	}

	func markRefreshFailed() {
		retrievalFailures += 1
		lastFailureDate = Date()

		let baseBackoffMinutes: Double =
			switch refreshTier {
			case .realTime: 2.0  // Quick retry for important data
			case .standard: 5.0  // Moderate backoff
			case .idle: 10.0  // Longer backoff for low priority
			case .onDemand: 2.0  // Quick retry for on-demand data
			}

		let backoffInterval: TimeInterval = min(
			pow(2.0, Double(retrievalFailures)) * baseBackoffMinutes * 60,			// Convert to seconds
			self.refreshTier.maxBackoffTime
		)  //?
		self.nextScheduledRefresh = Date().addingTimeInterval(backoffInterval)

		print(
			"❌ \(name): Failure #\(retrievalFailures), retry in \(Int(backoffInterval/60))min"
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
			return "--"				// TODO: Localisation strings
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
	
	func updateRoutingData(distance: CLLocationDistance, travelTime: TimeInterval) {
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

///// Priority calculation
//struct FacilityLoadPriority {
//	let facility: ParkingFacility
//	let priority: Int
//	let tier: RefreshTier
//	
//	init(
//		_ facility: ParkingFacility,
//		userLocation: (latitude: Double, longitude: Double)
//	) {
//		self.facility = facility
//		self.tier = facility.refreshTier
//		
//		var score = 0
//		
//		if facility.isFavourite { score += 1000 }
//		if let lastVisited = facility.lastVisited,
//		   lastVisited.timeIntervalSinceNow > -86400
//		{
//			score += 500
//		}
//		
//		if let travelTime = facility.lastCalculatedTravelTime {
//				/// Prefer travel time over distance for scoring. The closer travel time = the higher priority score
//			score += max(0, 200 - Int(travelTime / 60))
//		} else {
//			let distance = DistanceCalculator.getSimpleDistance(
//				from: userLocation,
//				to: (facility.latitude, facility.longitude)
//			)
//			
//			/// Validate distance before converting
//			/// If invalid distance (e.g. coordinates are invalid - don't add any distance-based score
//			if distance.isFinite && distance >= 0 {
//				score += max(0, 100 - Int(distance * 1000))
//			}
//		}
//		
//		/// Other prioritising factors
//		/// Large facilities
//		if facility.totalSpaces > 1000 { score += 200 }
//		if facility.refreshTier == .realTime { score += 300 }
//		
//		self.priority = score
//	}
//}


/// Supporting type
enum RefreshTier {
	case realTime
	case standard
	case idle
	case onDemand

	var refreshInterval: TimeInterval {
		switch self {
		case .realTime: return 15
		/// 15 seconds for updating Gordon, Kiama, Mona Vale, Warriewood
		case .standard: return 600
		/// 10 minutes API updates
		case .idle: return 1800
		/// 30 minutes fore rarely used facilities
		case .onDemand: return .infinity
		///	Only when user views or requests
		}
	}

	var maxConcurrency: Int {
		switch self {
		case .realTime: return 2
		case .standard: return 4
		case .idle: return 6
		case .onDemand: return 1
		}
	}

	var baseDelay: TimeInterval {
		switch self {
		case .realTime: return 0.2
		case .standard: return 0.5
		case .idle: return 0.8
		case .onDemand: return 0.3
		}
	}

	var maxFailureBackoff: Int {
		switch self {
		case .realTime: return 3  // Max 2^3 = 8x backoff
		case .standard: return 4  // Max 2^4 = 16x backoff
		case .idle: return 5  // Max 2^5 = 32x backoff
		case .onDemand: return 2  // Max 2^2 = 4x backoff
		}
	}

	var maxBackoffTime: TimeInterval {
		switch self {
		case .realTime: return 900  // 15 minutes max
		case .standard: return 1800  // 30 minutes max
		case .idle: return 3600  // 1 hour max
		case .onDemand: return 7200  // 2 hours max
		}
	}
}

