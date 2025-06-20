//
//  ParkingAPIModels.swift
//  MetroParking
//
//  Created by Tom Kwok on 19/6/2025.
//

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
