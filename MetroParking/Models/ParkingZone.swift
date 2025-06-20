//
//  ParkingZone.swift
//  MetroParking
//
//  Created by Tom Kwok on 19/6/2025.
//

import Foundation
import SwiftData

@Model
final class ParkingZone {
	var zoneId: String
	var zoneName: String
	var totalSpaces: Int
	var occupiedSpaces: Int
	var parentZoneId: String
	var lastUpdated: Date
	
	var isFavourite: Bool
	
	var facility: ParkingFacility?
	
	init(from apiZone: ParkingZoneAPI, facility: ParkingFacility) {
		self.zoneId = apiZone.parentZoneId
		self.zoneName = apiZone.zoneName
		self.totalSpaces = Int(apiZone.spots) ?? 0
		self.occupiedSpaces = Int(apiZone.occupancy.total ?? "0") ?? 0
		self.parentZoneId = apiZone.parentZoneId
		self.lastUpdated = Date()
		self.isFavourite = false
		self.facility = facility
	}
	
	
}
