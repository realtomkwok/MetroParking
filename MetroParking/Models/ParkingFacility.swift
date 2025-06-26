//
//  ParkingFacility.swift
//  MetroParking
//
//	Data model definitions for parking facilities provided by TfNSW.
//
//  Created by Tom Kwok on 19/6/2025.
//

import Foundation
import SwiftData

enum RefreshGroup {
	case high, standard
	
	var activeInterval: TimeInterval {
		switch self {
			case .high: return 15				// 15 seconds when app active
			case .standard: return 60			// 60 seconds when app active
		}
	}
	
	var backgroundInterval: TimeInterval {
		switch self {
			case .high: return 300				// 5 minutes in background
			case .standard: return 600 			// 10 minutes in background
		}
	}
}

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
	var notificationThreshold: Int?				// For feature "notify when under X spaces"
	
	var refreshGroupType: String = "standard"
	var lastRefreshed: Date = Date.distantPast
	var nextScheduledRefresh: Date = Date.distantPast
	var retrivalFailures: Int = 0
	var lastFailureDate: Date?
	
	var displayName: String {
		return name.removePrefix("Park&Ride - ")
	}
	
	private var _cachedOccupancy: Int = 0
	private var _cachedAvailableSpots: Int = 0
	private var _occupancyCacheTime: Date = Date.distantPast
	private var occupancyCacheValidityMinutes: TimeInterval = 15
	
	@Relationship(deleteRule: .cascade, inverse: \ParkingZone.facility)
	var zones: [ParkingZone] = []
	
	var availablityStatus: AvailabilityStatus {
		let available = currentAvailableSpots
		let total = totalSpaces
		
		if available == -1 {
			return .noData
		}
		
		if available == 0 {
			return .full
		} else if available < total / 10 {
			return .almostFull
		} else {
			return .available
		}
	}
	
	var refreshGroup: RefreshGroup {
		return refreshGroupType == "high" ? .high : .standard
	}
	
	var currentOccupancy: Int {
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
		get {
			if isOccupancyCacheValid {
				return _cachedAvailableSpots
			}
			return -1
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
		return retrivalFailures > 0
	}
	
	func distanceFrom(latitude: Double, longitude: Double) -> Double {
		let latDiff = self.latitude - latitude
		let lonDiff = self.longitude - longitude
		return sqrt(latDiff * latDiff + lonDiff * lonDiff)
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
		self.lastUpdated = dateFormatter.date(from: apiResponse.messageDate) ?? Date()
		self.lastVisited = nil
		
		self.isFavourite = false
		self.notificationThreshold = nil
		
		self.classifyRefreshGroup()
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
		self.lastUpdated = Date.distantPast // No occupancy data yet
		self.isFavourite = false
		self.lastVisited = nil
		self.notificationThreshold = nil
		
		self.classifyRefreshGroup()
	}
}

extension ParkingFacility {
	
	func classifyRefreshGroup() {
			// Based on API docs - these facilities have 15s update frequency
		let highFrequencyNames = ["Kiama", "Mona Vale", "Warriewood", "Dee Why", "Gordon Henry St"]
		
		for facility in highFrequencyNames {
			if name.contains(facility) {
				refreshGroupType = "high"
				return
			}
		}
		
		refreshGroupType = "standard"
	}
	
	func updateFromAPI(_ apiResponse: ParkingAPIResponse) {
			// Update occupancy cache
		self.currentOccupancy = Int(apiResponse.occupancy.total ?? "0") ?? 0
		
			// Update persistent data
		self.lastUpdated = Date()
		self.lastRefreshed = Date()
		self.retrivalFailures = 0
		self.lastFailureDate = nil
		
			// Update total spaces if it changed
		let newTotalSpaces = Int(apiResponse.spots) ?? self.totalSpaces
		if newTotalSpaces != self.totalSpaces {
			self.totalSpaces = newTotalSpaces
		}
	}
	
	func scheduleNextRefresh(appState: AppState = .active) {
		let baseInterval = appState == .active ? refreshGroup.activeInterval : refreshGroup.backgroundInterval
		
			// Apply favorite priority (50% faster refresh)
		let priorityMultiplier = isFavourite ? 0.5 : 1.0
		
			// Apply exponential backoff for failures
		let failureMultiplier = retrivalFailures > 0 ? pow(2.0, Double(min(retrivalFailures, 4))) : 1.0
		
		let finalInterval = baseInterval * priorityMultiplier * failureMultiplier
		self.nextScheduledRefresh = Date().addingTimeInterval(finalInterval)
		
		print("📅 \(name): Next refresh in \(Int(finalInterval))s (failures: \(retrivalFailures))")
	}
	
	func markRefreshFailed() {
		retrivalFailures += 1
		lastFailureDate = Date()
		
		let backoffInterval: TimeInterval = min(pow(2.0, Double(retrivalFailures)) * 120, 1800)		//?
		self.nextScheduledRefresh = Date().addingTimeInterval(backoffInterval)
		
		print("❌ \(name): Failure #\(retrivalFailures), retry in \(Int(backoffInterval/60))min")
	}
	
	func markAsVisited() {
		lastVisited = Date()
	}
}
