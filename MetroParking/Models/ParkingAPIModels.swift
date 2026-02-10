//
//  ParkingAPIModels.swift
//  MetroParking
//
//  Created by Tom Kwok on 19/6/2025.
//
//	Separated data model for API from the domain model: https://kylebrowning.com/posts/domain-models-vs-api-models/

public protocol ApiModel: Codable, Hashable, Sendable, Equatable {}

struct ParkingApiModel: ApiModel {
	let tsn: String
	let spots: String
	let zones: [ParkingZoneAPI]
	// Field "ParkID" could be Int too from the response
	//	let parkId: String
	let location: ParkingLocationAPI
	let occupancy: ParkingOccupancyAPI
	let messageDate: String
	let facilityId: String
	let facilityName: String
	let tfnswFacilityId: String

	/// `Codable` expects JSON keys to exactly match the property names. Since there's inconsistency from the API's response, it is necessary to include this `CodingKeys`enum to tell the decoder which JSON key corresponds to which property
	enum CodingKeys: String, CodingKey {
		case facilityId = "facility_id"
		case facilityName = "facility_name"
		case tsn, spots, zones
		//		case parkId = "ParkID"
		case location, occupancy
		case messageDate = "MessageDate"
		case tfnswFacilityId = "tfnsw_facility_id"
	}
}

struct ParkingZoneAPI: ApiModel {
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

struct ParkingLocationAPI: ApiModel {
	let suburb: String
	let address: String
	let latitude: String
	let longitude: String
}

struct ParkingOccupancyAPI: ApiModel {
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

extension ParkingApiModel {
	func toDomain() -> ParkingFacility? {
		guard let lat = Double(location.latitude),
			  let lng = Double(location.longitude),
			  let spaces = Int(spots)
				else { return nil }

		return ParkingFacility(
			facilityId: facilityId,
			name: facilityName,
			suburb: location.suburb,
			address: location.address,
			latitude: lat,
			longitude: lng,
			totalSpaces: spaces
		)
	}
}
