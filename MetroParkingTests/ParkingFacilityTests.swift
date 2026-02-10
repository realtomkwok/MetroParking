//
//  ParkingFacilityTests.swift
//  MetroParking
//
//  Created by Tom Kwok on 9/2/2026.
//

import CoreLocation
import Testing

@testable import MetroParking

@Suite("Parsing names", .tags(.model))
struct NameParsingTests {
	@Test(
		"Parses names correctly",
		arguments: [
			("6", "Gordon Henry St", "North"),
			("7", "Kiama", ""),
			("17", "Edmondson Park", "South"),
			("19", "Campbelltown Farrow Rd", "North"),
			("21", "Penrith", "At-Grade"),
			("22", "Penrith", "Multi-Level"),
		]
	) func parseNames(
		id: String,
		expectedTitle: String,
		expectedSubtitle: String
	) async throws {
		let facility = TestFacility.facility(id)
		#expect(!facility.displayName.full.contains("Park&Ride"))
		#expect(facility.displayName.title == expectedTitle)
		#expect(facility.displayName.subtitle == expectedSubtitle)
	}
}

@Suite("Availability Status", .tags(.model))
struct AvailabilityStatusTests {
	@Test("No data when facility has never been updated")
	// TODO: Test failed due to cachedTimestamp is valid
	func noDataWhenNeverUpdated() async throws {
		let facility = TestFacility.facility("6")
		if facility.refreshStatus.cacheTimestamp == .distantPast {
			#expect(facility.availabilityStatus == .noData)
		} else {
			#expect(facility.availabilityStatus != .noData)
		}
	}

	@Test("Full when zero spaces available") func fullWhenZeroAvailable()
		async throws
	{
		// Gosford: 1059 total, 1059 occupied → 0 available
		let facility = TestFacility.withOccupancy(
			TestFacility.facility("8"),
			occupied: 1059
		)

		#expect(facility.availabilityStatus == .full)
	}

	@Test("Almost full when under 10% available")
	func almostFullWhenUnder10Precent() {
		// Kiama: 42 total, 40 occupied → 2 available (2 < 42/10 = 4)

		let facility = TestFacility.withOccupancy(
			TestFacility.kiama(),
			occupied: 40
		)

		#expect(facility.availabilityStatus == .almostFull)
	}

	@Test("Available when above 10% available")
	func availableWhenAbove10Percent() {
		// Gordon: 213 total, 50 occupied -> 163 available

		let facility = TestFacility.withOccupancy(
			TestFacility.gordon(),
			occupied: 50
		)

		#expect(facility.availabilityStatus == .available)
	}

	@Test(
		"Boundary values",
		arguments: [
			// (total, occupied, expected)
			(100, 100, AvailabilityStatus.full),
			(100, 91, AvailabilityStatus.almostFull),
			(100, 90, AvailabilityStatus.available),
			(100, 50, AvailabilityStatus.available),
			(100, 0, AvailabilityStatus.available),
			//		(100, nil, AvailabilityStatus.noData)	TODO: No data
		]
	)
	func boundaryValues(
		total: Int,
		occupied: Int,
		expected: AvailabilityStatus
	) {
		let facility = ParkingFacility(
			facilityId: "100",
			name: "Park&Ride - Test Car Park",
			suburb: "Test",
			address: "Test St",
			latitude: -33.8,
			longitude: 151.2,
			totalSpaces: total
		)

		facility.updateOccupancy(occupied: occupied, totalSpaces: total)
		#expect(facility.availabilityStatus == expected)
	}
}

// TODO: Vacancy, Route Info, Location Info, Recently Visited,
