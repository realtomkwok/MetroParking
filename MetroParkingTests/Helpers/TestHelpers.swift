//
//  TestHelpers.swift
//  MetroParking
//
//  Created by Tom Kwok on 9/2/2026.
//

// TODO: Pre-built test data to bypass injecting model from SwiftData

import Foundation

@testable import MetroParking

enum TestFacility {

	private static func copy(_ source: ParkingFacility) -> ParkingFacility {
		ParkingFacility(
			facilityId: source.facilityId,
			name: source.name,
			suburb: source.location.suburb,
			address: source.location.address,
			latitude: source.location.latitude,
			longitude: source.location.longitude,
			totalSpaces: source.vacancy.total
		)
	}

	static let allFacilities: [ParkingFacility] = ParkingFacility
		.staticFacilityData

	// Gordon (has parenthesised subtitle). Failed if the static data changed
	static func gordon() -> ParkingFacility {
		let facility = allFacilities.first(where: { $0.name.contains("Gordon") }
		)!

		return copy(facility)
	}

	// Kiama (no subtitle in the parenthesis)
	static func kiama() -> ParkingFacility {
		let facility = allFacilities.first(where: { $0.name.contains("Kiama") }
		)!

		return copy(facility)
	}

	static func facility(_ id: String) -> ParkingFacility {
		let facility = allFacilities.first(where: { $0.facilityId == id })!

		return copy(facility)
	}

	static func all() -> [ParkingFacility] {
		return allFacilities
	}

	static func withOccupancy(_ facility: ParkingFacility, occupied: Int)
		-> ParkingFacility
	{
		facility
			.updateOccupancy(
				occupied: occupied,
				totalSpaces: facility.totalSpaces
			)

		return facility
	}

	static func asFavourite(_ facility: ParkingFacility) -> ParkingFacility {
		facility.isFavourite = true

		return facility
	}

	static func makeListWithOccupancy() -> [ParkingFacility] {
		[
			withOccupancy(facility("6"), occupied: 50),  // Gordon: available
			withOccupancy(facility("7"), occupied: 40),  // Kiama: almostFull
			withOccupancy(facility("8"), occupied: 1059),  // Gosford: full
			facility("9"),  // Revesby: noData (no occupancy set)
			withOccupancy(facility("10"), occupied: 100),  // Warriewood: available
		]
	}
}
