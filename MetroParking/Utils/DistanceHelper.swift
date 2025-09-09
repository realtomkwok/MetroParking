//
//  FacilitySortingHelper.swift
//  MetroParking
//
//  Created by Tom Kwok on 1/9/2025.
//

import CoreLocation
import Foundation

struct DistanceHelper {

	static var cachedDistances: [String: Double] = [:]
	static var cacheValidLocation: CLLocationCoordinate2D?
	static let cachedValidDistance: Double = 100.0  // metres

	// MARK: - Distance calculation

	static func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D)
		-> Double
	{
		let fromLocation = CLLocation(
			latitude: from.latitude,
			longitude: from.longitude
		)
		let toLocation = CLLocation(
			latitude: to.latitude,
			longitude: to.longitude
		)

		return toLocation.distance(from: fromLocation) / 1000.0  // Convert to km
	}

	static func distanceToFacility(
		_ facility: ParkingFacility,
		from userLocation: CLLocationCoordinate2D
	) -> Double {
		// Check cache
		if let cachedLoc = cacheValidLocation {
			let moveDistance =
				distance(from: userLocation, to: cachedLoc) * 1000  // in metres

			if moveDistance < cachedValidDistance {
				if let cached = cachedDistances[facility.facilityId] {
					return cached
				}
			} else {
				cachedDistances.removeAll()
			}
		}

		let facilityCoordinates = CLLocationCoordinate2D(
			latitude: facility.latitude,
			longitude: facility.longitude
		)
		let newDistance = self.distance(
			from: userLocation,
			to: facilityCoordinates
		)

		cachedDistances[facility.facilityId] = newDistance
		cacheValidLocation = userLocation

		return newDistance
	}

	// MARK: - Sorting methods
	/// Sort facilities by distance from user location
	static func sortFacilitiesByDistance(
		_ facilities: [ParkingFacility],
		from userLocation: CLLocationCoordinate2D
	) -> [ParkingFacility] {
		return facilities.sorted { facility1, facility2 in
			let dist1 = distanceToFacility(facility1, from: userLocation)
			let dist2 = distanceToFacility(facility2, from: userLocation)
			return dist1 < dist2
		}
	}

	// MARK: - Cache

	/// Clear distance cache (call when location updates significantly)
	static func clearDistanceCache() {
		cachedDistances.removeAll()
		cacheValidLocation = nil
	}
}
