//
//  CalcDistanceHelper.swift
//  MetroParking
//
//  Created by Tom Kwok on 12/8/2025.
//

import MapKit

class DistanceCalculator {
	private static var routeCache: [String: RouteData] = [:]

	static func getSimpleDistance(
		from: (latitude: Double, longitude: Double),
		to: (latitude: Double, longitude: Double)
	) -> Double {
		/// Fallback to the simple distance between two locations
		let latDiff = from.latitude - to.latitude
		let lonDiff = from.longitude - to.longitude

		return sqrt(latDiff * latDiff + lonDiff * lonDiff)
	}

	/// Grid-based caching
	private static func gridKey(
		latitude: Double,
		longitude: Double,
		gridSize: Double = 0.01
	) -> String {
		/// Round to nearest grid cell (~1km)
		let gridLat = round(latitude / gridSize) * gridSize
		let gridLon = round(longitude / gridSize) * gridSize
		return "\(gridLat),\(gridLon)"
	}

	static func getRoutingDistance(
		from: (latitude: Double, longitude: Double),
		to: (latitude: Double, longitude: Double),
		transportType: MKDirectionsTransportType = .automobile
	) async -> RouteData? {
		let fromGrid = gridKey(
			latitude: from.latitude,
			longitude: from.longitude
		)
		let toGrid = gridKey(latitude: to.latitude, longitude: to.longitude)
		let cacheKey = "\(fromGrid)-\(toGrid)"
		
		/// Check cache first
		if let cached = routeCache[cacheKey] {
			return cached
		}
		
		let fromLocation = CLLocationCoordinate2D(latitude: from.latitude, longitude: from.longitude)
		let toLocation = CLLocationCoordinate2D(latitude: to.latitude, longitude: to.longitude)
		
		let request = MKDirections.Request()
		request.source = MKMapItem(placemark: MKPlacemark(coordinate: fromLocation))
		request.destination = MKMapItem(placemark: MKPlacemark(coordinate: toLocation))
		request.transportType = transportType
		
		do {
			let direction = MKDirections(request: request)
			let response = try await direction.calculate()
			
			if let route = response.routes.first {
				let result = RouteData(distance: route.distance, travelTime: route.expectedTravelTime)
				routeCache[cacheKey] = result
				return result
			}
		} catch {
			print("❌ Failed to calculate route: \(error)")
		}
		
		return nil
	}
}

/// Supporting type
struct RouteData {
	let distance: CLLocationDistance
	let travelTime: TimeInterval
	let transportType: MKDirectionsTransportType = .automobile

	var formattedDistance: String {
		let formatter = MKDistanceFormatter()
		return formatter.string(fromDistance: distance)
	}
	 
	var formattedTravelTime: String {
		return TimeFormatter.shared.formatTravelTime(travelTime, style: .abbreviated)
	}
}
