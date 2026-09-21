//
//  ParkingAPIServiceTests.swift
//  MetroParking
//
//  Created by Tom Kwok on 13/9/2026.
//

import Foundation
import Testing

@testable import MetroParking

@Suite("API decoding", .tags(.api))
struct ParkingAPIServiceTests {

	private static func facilityJSON(id: String, name: String, spots: String, occupied: String?) -> String {
		let total = occupied.map { "\"\($0)\"" } ?? "null"
		return """
			{
			  "tsn": "207210",
			  "spots": "\(spots)",
			  "zones": [],
			  "location": {
			    "suburb": "Gordon",
			    "address": "Henry Street",
			    "latitude": "-33.755",
			    "longitude": "151.153"
			  },
			  "occupancy": {
			    "loop": null,
			    "total": \(total),
			    "monthlies": null,
			    "open_gate": null,
			    "transients": null
			  },
			  "MessageDate": "2026-09-13T10:00:00",
			  "facility_id": "\(id)",
			  "facility_name": "\(name)",
			  "tfnsw_facility_id": "2072TPR001"
			}
			"""
	}

	@Test func `decodes a single facility object`() throws {
		let json = Self.facilityJSON(
			id: "6",
			name: "Park&Ride - Gordon Henry St (north)",
			spots: "210",
			occupied: "120"
		)

		let model = try ParkingAPIService.decode(Data(json.utf8), facilityId: "6")

		#expect(model.facilityId == "6")
		#expect(model.spots == "210")
		#expect(model.occupancy.total == "120")
	}

	@Test func `decodes a dictionary keyed by facility ID`() throws {
		let json = """
			{
			  "7": \(Self.facilityJSON(id: "7", name: "Park&Ride - Kiama", spots: "42", occupied: "40")),
			  "6": \(Self.facilityJSON(id: "6", name: "Park&Ride - Gordon Henry St (north)", spots: "210", occupied: "1"))
			}
			"""

		let model = try ParkingAPIService.decode(Data(json.utf8), facilityId: "6")

		#expect(model.facilityId == "6")
		#expect(model.occupancy.total == "1")
	}

	@Test func `rejects a payload that isn't a facility`() {
		#expect(throws: APIError.self) {
			try ParkingAPIService.decode(Data(#"{"error": "nope"}"#.utf8), facilityId: "6")
		}
	}

	@Test func `rejects an empty dictionary`() {
		#expect(throws: APIError.self) {
			try ParkingAPIService.decode(Data("{}".utf8), facilityId: "6")
		}
	}
}

@MainActor
@Suite("Shared availability thresholds", .tags(.model, .widget))
struct AvailabilityThresholdTests {

	@Test(
		arguments: [
			// (available, total, expected)
			(0, 100, AvailabilityStatus.full),
			(9, 100, .almostFull),
			(10, 100, .available),
			(2, 42, .almostFull),
			(0, 0, .noData),
		]
	)
	func `status from vacancy`(available: Int, total: Int, expected: AvailabilityStatus) {
		#expect(AvailabilityStatus(available: available, total: total) == expected)
	}

	@Test(arguments: AvailabilityStatus.allCases)
	func `widget cache round-trips the status`(status: AvailabilityStatus) {
		let data = WidgetFacilityDataFixture.make(status: status.rawValue)
		#expect(data.status == status)
	}

	@Test(
		arguments: [
			("Available", AvailabilityStatus.available),
			("Almost Full", .almostFull),
			("Full", .full),
			("No Data", .noData),
			("几乎满", .noData),
		]
	)
	func `widget cache reads legacy display text`(text: String, expected: AvailabilityStatus) {
		let data = WidgetFacilityDataFixture.make(status: text)
		#expect(data.status == expected)
	}

	@Test(
		arguments: [
			("Park&Ride - Gordon Henry St (north)", "Gordon Henry St", "North"),
			("Park&Ride - Kiama", "Kiama", ""),
			("Park&Ride - Penrith (at-grade)", "Penrith", "At-Grade"),
		]
	)
	func `parses display names`(name: String, title: String, subtitle: String) {
		let parsed = ParkingFacility.parseDisplayName(name)
		#expect(parsed.title == title)
		#expect(parsed.subtitle == subtitle)
		#expect(!parsed.full.contains("Park&Ride"))
	}
}

private enum WidgetFacilityDataFixture {
	@MainActor
	static func make(status: String) -> SharedDataManager.WidgetFacilityData {
		SharedDataManager.WidgetFacilityData(
			facilityId: "6",
			name: "Park&Ride - Gordon Henry St (north)",
			displayTitle: "Gordon Henry St",
			displaySubtitle: "North",
			address: "Henry Street",
			availableSpaces: 10,
			totalSpaces: 100,
			occupancyRatio: 0.9,
			availabilityStatus: status,
			distance: nil,
			travelTime: nil,
			lastUpdated: .now,
			cacheTimestamp: .now
		)
	}
}
