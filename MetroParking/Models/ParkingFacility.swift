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
	
	var isFavourite: Bool
	var notificationThreshold: Int?				// For feature "notify when under X spaces"
	
	@Relationship(deleteRule: .cascade, inverse: \ParkingZone.facility)
	var zones: [ParkingZone] = []
	
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
		self.isFavourite = false
		self.notificationThreshold = nil
	}
}
