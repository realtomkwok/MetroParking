//
//  ParkingAPIModels.swift
//  MetroParking
//
//  Created by Tom Kwok on 19/6/2025.
//

import SwiftUI

struct ParkingAPIResponse: Codable {
	let tsn: String
	let spots: String
	let zones: [ParkingZoneAPI]
	let parkId: String
	let location: ParkingLocationAPI
	let occupancy: ParkingOccupancyAPI
	let messageDate: String
	let facilityId: String
	let facilityName: String
	let tfnswFacilityId: String
	
	enum CodingKeys: String, CodingKey {
		case facilityId = "facility_id"
		case facilityName = "facility_name"
		case tsn, spots, zones
		case parkId = "ParkID"
		case location, occupancy
		case messageDate = "MessageDate"
		case tfnswFacilityId = "tfnsw_facility_id"
	}
}

struct ParkingZoneAPI: Codable {
	let zoneId: String
	let zoneName: String
	let spots: String
	let occupancy: ParkingOccupancyAPI
	let parentZoneId: String
	
	enum CodingKeys: String, CodingKey {
		case zoneId = "zone_id"
		case zoneName = "zone_name"
		case spots, occupancy
		case parentZoneId = "parent_zone_id"
	}
}

struct ParkingLocationAPI: Codable {
	let suburb: String
	let address: String
	let latitude: String
	let longitude: String
}

struct ParkingOccupancyAPI: Codable {
	let loop: String?
	let total: String?
	let monthlies: String?
	let openGate: String?
	let transients: String?
	
	enum CodingKeys: String, CodingKey {
		case loop, total, monthlies
		case openGate = "open_gate"
		case transients
	}
}

// Statuses of availability are based on TfNSW recommendation
// Full: availableSpots < 1
// Almost full: availableSpots < 10% of total

enum AvailabilityStatus {
	case available, almostFull, full, noData
	
	var color: Color {
		switch self {
			case .available: return .green
			case .almostFull: return .yellow
			case .full: return .red
			case .noData: return .gray
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
}

extension ParkingAPIResponse {
	var availableSpots: Int {
		guard let totalSpots = Int(spots),
			  let occupiedSpots = Int(occupancy.total ?? "0") else {
			return 0
		}
		return max(0, totalSpots - occupiedSpots) 	// Avoid negative value
	}
	
	var availabilityStatus: AvailabilityStatus {
		let available = availableSpots
		let total = Int(spots) ?? 0
		
		if available <= 0 {
			return .full
		} else if available < total / 10 {
			return .almostFull
		} else {
			return .available
		}
	}
}

extension ParkingAPIResponse {
	var staticInfo: StaticFacilityInfo {
		StaticFacilityInfo(
			facilityId: self.facilityId,
			name: self.facilityName,
			suburb: self.location.suburb,
			address: self.location.address,
			latitude: Double(self.location.latitude) ?? 0,
			longitude: Double(self.location.longitude) ?? 0,
			totalSpaces: Int(self.spots) ?? 0,
			tsn: self.tsn,
			tfnswFacilityId: self.tfnswFacilityId
		)
	}
}
