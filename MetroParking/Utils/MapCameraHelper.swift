//
//  MapCameraManager.swift
//  MetroParking
//
//  Created by Tom Kwok on 1/9/2025.
//

import Foundation
import MapKit
import SwiftUI

struct MapCameraHelper {

	static func calculateRegion(
		for coordinates: [CLLocationCoordinate2D],
		paddingFactor: Double,
		minSpan: Double,
		maxSpan: Double
	) -> MKCoordinateRegion {
		guard !coordinates.isEmpty else {
			return getAllFacilitiesRegion()  // Fallback to default region
		}

		/// Single coordinate
		guard coordinates.count > 1 else {
			return MKCoordinateRegion(
				center: coordinates[0],
				span: MKCoordinateSpan(
					latitudeDelta: 1,
					longitudeDelta: 1
				)
			)
		}

		/// Multiple coordinates
		let latitudes = coordinates.map { $0.latitude }
		let longitudes = coordinates.map { $0.longitude }

		let minLat = latitudes.min()!
		let maxLat = latitudes.max()!
		let minLon = longitudes.min()!
		let maxLon = longitudes.max()!

		/// Calculate centre point
		let centerLat = (minLat + maxLat) / 2.0
		let centerLon = (minLon + maxLon) / 2.0

		/// Calculate span with padding and constraints
		let rawLatSpan = (maxLat - minLat) * paddingFactor
		let rawLonSpan = (maxLon - minLon) * paddingFactor

		let latSpan = max(min(rawLatSpan, maxSpan), minSpan)
		let lonSpan = max(min(rawLonSpan, maxSpan), minSpan)

		return MKCoordinateRegion(
			center: CLLocationCoordinate2D(
				latitude: centerLat,
				longitude: centerLon
			),
			span: MKCoordinateSpan(
				latitudeDelta: latSpan,
				longitudeDelta: lonSpan
			)
		)
	}

	static func calculateCentre(from coordinates: [CLLocationCoordinate2D])
		-> CLLocationCoordinate2D
	{
		guard !coordinates.isEmpty else {
			// Fallback to Sydney
			return CLLocationCoordinate2D(
				latitude: -33.8688,
				longitude: 151.2093
			)
		}

		let latitudes = coordinates.map { $0.latitude }
		let longitudes = coordinates.map { $0.longitude }

		let centreLat = latitudes.reduce(0, +) / Double(coordinates.count)
		let centreLon = longitudes.reduce(0, +) / Double(coordinates.count)

		return CLLocationCoordinate2D(
			latitude: centreLat,
			longitude: centreLon
		)
	}

	/// Calculate centre with sheet offset
	static func calculateCentreWithOffset(
		from coordinates: [CLLocationCoordinate2D],
		latitudeOffset: Double = 0.15
	) -> CLLocationCoordinate2D {
		let centre = calculateCentre(from: coordinates)
		return CLLocationCoordinate2D(
			latitude: centre.latitude + latitudeOffset,
			longitude: centre.longitude
		)
	}

	static func cameraZoomIn(_ facility: ParkingFacility) -> MapCameraPosition {
			/// Calculate offset to position facility above the sheet
		let latitudeOffset = 0.002  // Moves centre down so facility appears higher

		let facilityCoordinate = CLLocationCoordinate2D(
			latitude: facility.latitude,
			longitude: facility.longitude
		)

		let newRegion = calculateRegion(
			for: [facilityCoordinate],
			paddingFactor: 1.0,
			minSpan: 0.001,
			maxSpan: 0.002
		)

		let offsetCentre = CLLocationCoordinate2D(
			latitude: newRegion.center.latitude - latitudeOffset,
			longitude: newRegion.center.longitude
		)

		let finalRegion = MKCoordinateRegion(
			center: offsetCentre,
			span: newRegion.span
		)

		return .region(finalRegion)
	}

	static func cameraZoomOut() -> MapCameraPosition {
		let allFacilitiesRegion = getAllFacilitiesRegion()

		return .region(allFacilitiesRegion)
	}
}

extension MapCameraHelper {

	static func getAllFacilitiesRegion() -> MKCoordinateRegion {
		let allStaticFacilities = ParkingFacility.getAllStaticFacilities()
		let coordinates = allStaticFacilities.map { facility in
			CLLocationCoordinate2D(
				latitude: facility.latitude,
				longitude: facility.longitude
			)
		}

		return calculateRegion(
			for: coordinates,
			paddingFactor: 1.3,
			minSpan: 0.5,
			maxSpan: 2.0
		)
	}

	@MainActor static func getNearestFacilitiesRegion(
		facilities: [ParkingFacility],
		count: Int = 5,
	) -> MKCoordinateRegion {

		let userLocation = LocationManager.shared.userLocation

		let nearestFacilities = DistanceHelper.sortFacilitiesByDistance(
			facilities,
			from: userLocation
		).prefix(
			count
		)

		var coordinates = [userLocation]
		coordinates.append(
			contentsOf: nearestFacilities.map { facility in
				CLLocationCoordinate2D(
					latitude: facility.latitude,
					longitude: facility.longitude
				)
			}
		)

		return calculateRegion(
			for: coordinates,
			paddingFactor: 1.3,
			minSpan: 0.5,
			maxSpan: 2.0
		)
	}
}
