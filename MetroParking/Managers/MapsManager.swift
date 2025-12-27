//
//  MapsManager.swift
//  MetroParking
//
//  Created by Tom Kwok on 9/12/2025.
//

import Contacts
import Foundation
import MapKit
import OSLog

#if canImport(GeoToolbox)
	import GeoToolbox
#endif

/// Centralized manager for all MapKit operations including MapItem creation,
/// directions, Look Around scenes, and Apple Maps integration.
///
/// This manager handles iOS version compatibility, providing fallbacks for
/// older versions while leveraging modern APIs like GeoToolbox when available.
@Observable
@MainActor
final class MapsManager {

	// MARK: - Singleton

	static let shared = MapsManager()

	// MARK: - Published State

	/// Current Look Around scene
	var lookAroundScene: MKLookAroundScene?

	/// Whether a Look Around scene is currently loading
	var isLoadingLookAround: Bool = false

	/// Error message if Look Around loading fails
	var lookAroundError: String?

	/// The coordinate for which we're currently showing/loading Look Around
	var currentLookAroundCoordinate: CLLocationCoordinate2D?

	// MARK: - Private Properties

	private var lookAroundTasks: [String: Task<Void, Never>] = [:]

	// MARK: - Initialization

	private init() {}

	// MARK: - MapItem Creation

	/// Creates an MKMapItem from a ParkingFacility using the most modern API available
	/// - Parameter facility: The parking facility
	/// - Returns: A configured MKMapItem
	/// - Note: This method uses multiple fallback strategies to ensure a MapItem is always created
	func createMapItem(for facility: ParkingFacility) async -> MKMapItem {
		let location = facility.location

		// iOS 26+ supports the modern PlaceDescriptor API via GeoToolbox
		if #available(iOS 26.0, *) {
			// Try modern API first, but fall back to legacy if it fails
			if let mapItem = await createModernMapItem(
				coordinate: location.coordinate,
				name: facility.name,
				address: location.address,
				suburb: location.suburb
			) {
				return mapItem
			}

			Logger.maps.warning(
				"⚠️ Modern MapItem creation failed for \(facility.name), falling back to legacy method"
			)
		}

		// Fallback for older iOS versions or if modern method fails
		return createLegacyMapItem(
			coordinate: location.coordinate,
			name: facility.name,
			address: location.address,
			suburb: location.suburb
		)
	}

	/// Creates a MapItem using modern iOS 26.0+ APIs with PlaceDescriptor
	/// - Returns: An MKMapItem if successful, nil if creation fails
	@available(iOS 26.0, *)
	private func createModernMapItem(
		coordinate: CLLocationCoordinate2D,
		name: String,
		address: String,
		suburb: String
	) async -> MKMapItem? {
		// Validate coordinate before attempting creation
		guard CLLocationCoordinate2DIsValid(coordinate) else {
			Logger.maps.error(
				"❌ Invalid coordinate for \(name): lat=\(coordinate.latitude), lon=\(coordinate.longitude)"
			)
			return nil
		}

		do {
			// Use GeoToolbox PlaceDescriptor for best results with multiple representations
			let placeDescriptor = PlaceDescriptor(
				representations: [
					.coordinate(coordinate),
					.address("\(address), \(suburb)"),
				],
				commonName: name
			)

			// Convert PlaceDescriptor to MKMapItem
			let request = MKMapItemRequest(placeDescriptor: placeDescriptor)
			let mapItem = try await request.mapItem

			Logger.maps.debug(
				"🗺️ Created modern MapItem using PlaceDescriptor for \(name)"
			)
			return mapItem

		} catch let error as NSError {
			// Log specific error details for debugging
			Logger.maps.error(
				"❌ PlaceDescriptor MapItem creation failed for \(name): \(error.localizedDescription) (code: \(error.code))"
			)

			// Try fallback to simpler MKMapItem initialization if available
			return createSimpleModernMapItem(
				coordinate: coordinate,
				name: name,
				address: address,
				suburb: suburb
			)
		}
	}

	/// Creates a simple MapItem using iOS 26.0+ MKMapItem(location:address:) initializer
	@available(iOS 26.0, *)
	private func createSimpleModernMapItem(
		coordinate: CLLocationCoordinate2D,
		name: String,
		address: String,
		suburb: String
	) -> MKMapItem? {
		let location = CLLocation(
			latitude: coordinate.latitude,
			longitude: coordinate.longitude
		)

		let fullAddress = "\(address), \(suburb)"
		let mkAddress = MKAddress(
			fullAddress: fullAddress,
			shortAddress: address
		)

		let mapItem = MKMapItem(location: location, address: mkAddress)
		mapItem.name = name

		Logger.maps.debug("🗺️ Created simple modern MapItem for \(name)")
		return mapItem
	}

	/// Creates a MapItem using legacy MKPlacemark API for iOS < 26
	/// - Returns: An MKMapItem (always succeeds with valid coordinates)
	/// - Note: Uses deprecated MKPlacemark for backward compatibility with iOS < 26
	/// @Avai
	private func createLegacyMapItem(
		coordinate: CLLocationCoordinate2D,
		name: String,
		address: String,
		suburb: String
	) -> MKMapItem {
		// Validate coordinate
		guard CLLocationCoordinate2DIsValid(coordinate) else {
			Logger.maps.error(
				"❌ Invalid coordinate for \(name), using default location"
			)
			// Return a default map item with a zero coordinate as last resort
			if #available(iOS 26.0, *) {
				// Use modern API for iOS 26+
				let location = CLLocation(latitude: 0, longitude: 0)
				let mapItem = MKMapItem(location: location, address: nil)
				mapItem.name = name
				return mapItem
			} else {
				let defaultPlacemark = MKPlacemark(
					coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0)
				)
				let mapItem = MKMapItem(placemark: defaultPlacemark)
				mapItem.name = name
				return mapItem
			}
		}

		// Try to create a more detailed placemark with address components
		var addressDictionary: [String: Any] = [:]

		// Parse address components if possible
		if !address.isEmpty {
			addressDictionary[CNPostalAddressStreetKey] = address
		}
		if !suburb.isEmpty {
			addressDictionary[CNPostalAddressCityKey] = suburb
		}

		// Create placemark with coordinate and address dictionary
		let placemark: MKPlacemark
		if !addressDictionary.isEmpty {
			placemark = MKPlacemark(
				coordinate: coordinate,
				addressDictionary: addressDictionary
			)
		} else {
			// Fallback to simple coordinate-only placemark
			placemark = MKPlacemark(coordinate: coordinate)
		}

		// Create map item
		let mapItem = MKMapItem(placemark: placemark)
		mapItem.name = name

		Logger.maps.debug(
			"🗺️ Created legacy MapItem using MKPlacemark for \(name)"
		)
		return mapItem
	}

	// MARK: - Directions & Routes

	/// Calculate directions from one location to another
	/// - Parameters:
	///   - source: Source coordinate
	///   - destination: Destination map item
	///   - transportType: Type of transport (default: automobile)
	///   - requestAlternates: Whether to request alternate routes (default: true)
	/// - Returns: MKDirections.Response with route information
	func calculateDirections(
		from source: CLLocationCoordinate2D,
		to destination: MKMapItem,
		transportType: MKDirectionsTransportType = .automobile,
		requestAlternates: Bool = true
	) async throws -> MKDirections.Response {
		let sourceItem: MKMapItem
		if #available(iOS 26.0, *) {
			// Use modern API without deprecated MKPlacemark
			let location = CLLocation(
				latitude: source.latitude,
				longitude: source.longitude
			)
			sourceItem = MKMapItem(location: location, address: nil)
		} else {
			// Use legacy MKPlacemark for older iOS versions
			let sourcePlacemark = MKPlacemark(coordinate: source)
			sourceItem = MKMapItem(placemark: sourcePlacemark)
		}

		let request = MKDirections.Request()
		request.source = sourceItem
		request.destination = destination
		request.transportType = transportType
		request.requestsAlternateRoutes = requestAlternates

		let directions = MKDirections(request: request)
		let response = try await directions.calculate()

		Logger.maps.info(
			"🧭 Calculated \(response.routes.count) route(s) to \(destination.name ?? "destination")"
		)
		return response
	}

	/// Calculate ETA from one location to another (faster than full directions)
	/// - Parameters:
	///   - source: Source coordinate
	///   - destination: Destination map item
	///   - transportType: Type of transport (default: automobile)
	/// - Returns: MKDirections.ETAResponse with travel time and distance
	func calculateETA(
		from source: CLLocationCoordinate2D,
		to destination: MKMapItem,
		transportType: MKDirectionsTransportType = .automobile
	) async throws -> MKDirections.ETAResponse {
		let sourceItem: MKMapItem
		if #available(iOS 26.0, *) {
			// Use modern API without deprecated MKPlacemark
			let location = CLLocation(
				latitude: source.latitude,
				longitude: source.longitude
			)
			sourceItem = MKMapItem(location: location, address: nil)
		} else {
			// Use legacy MKPlacemark for older iOS versions
			let sourcePlacemark = MKPlacemark(coordinate: source)
			sourceItem = MKMapItem(placemark: sourcePlacemark)
		}

		let request = MKDirections.Request()
		request.source = sourceItem
		request.destination = destination
		request.transportType = transportType
		request.requestsAlternateRoutes = false

		let directions = MKDirections(request: request)
		let response = try await directions.calculateETA()

		Logger.maps.debug(
			"⏱️ ETA to \(destination.name ?? "destination"): \(response.expectedTravelTime / 60) min"
		)
		return response
	}

//	@available(iOS 26.0, *)
//	func calculateEta(
//		from userLocation: CLLocationCoordinate2D,
//		to destination: MKMapItem,
//		transportType: MKDirectionsTransportType = .automobile
//	) async throws -> MKDirections.ETAResponse {
//		
//	}

	// MARK: - Look Around

	/// Load a Look Around scene for a specific facility
	/// - Parameter facility: The parking facility
	/// - Note: This method updates observable state and should be called from the UI
	func loadLookAroundScene(for facility: ParkingFacility) async {
		let coordinate = facility.coordinate
		let facilityId = facility.facilityId

		// Cancel any existing task for this facility
		lookAroundTasks[facilityId]?.cancel()

		// Check if we're already showing this coordinate
		if let current = currentLookAroundCoordinate,
			current.latitude == coordinate.latitude,
			current.longitude == coordinate.longitude,
			lookAroundScene != nil
		{
			Logger.maps.debug(
				"🔍 Look Around scene already loaded for \(facility.name)"
			)
			return
		}

		isLoadingLookAround = true
		lookAroundError = nil
		currentLookAroundCoordinate = coordinate

		let task = Task {
			do {
				let scene = try await fetchLookAroundScene(for: coordinate)

				// Check if task was cancelled
				guard !Task.isCancelled else {
					Logger.maps.debug(
						"🔍 Look Around loading cancelled for \(facility.name)"
					)
					return
				}

				// Update state on main actor
				lookAroundScene = scene
				isLoadingLookAround = false

				Logger.maps.info(
					"🔍 Look Around scene loaded for \(facility.name)"
				)
			} catch {
				guard !Task.isCancelled else { return }

				lookAroundError = "Look Around not available for this location"
				isLoadingLookAround = false
				lookAroundScene = nil

				Logger.maps.warning(
					"🔍 Look Around unavailable for \(facility.name): \(error.localizedDescription)"
				)
			}

			// Clean up task reference
			lookAroundTasks.removeValue(forKey: facilityId)
		}

		lookAroundTasks[facilityId] = task
	}

	/// Fetch a Look Around scene for a coordinate (without updating shared state)
	/// - Parameter coordinate: The coordinate to fetch Look Around for
	/// - Returns: An MKLookAroundScene if available
	/// - Throws: Error if Look Around is unavailable
	func fetchLookAroundScene(for coordinate: CLLocationCoordinate2D)
		async throws -> MKLookAroundScene
	{
		let request = MKLookAroundSceneRequest(coordinate: coordinate)

		guard let scene = try await request.scene else {
			throw MapsManagerError.lookAroundUnavailable
		}

		return scene
	}

	/// Cancel Look Around loading for a specific facility
	/// - Parameter facilityId: The facility ID (if nil, cancels all)
	func cancelLookAround(for facilityId: String? = nil) {
		if let facilityId = facilityId {
			lookAroundTasks[facilityId]?.cancel()
			lookAroundTasks.removeValue(forKey: facilityId)
		} else {
			lookAroundTasks.values.forEach { $0.cancel() }
			lookAroundTasks.removeAll()
		}
	}

	/// Reset Look Around state
	func resetLookAround() {
		cancelLookAround()
		lookAroundScene = nil
		currentLookAroundCoordinate = nil
		lookAroundError = nil
		isLoadingLookAround = false
	}

	// MARK: - Apple Maps Integration

	/// Opens the facility in Apple Maps
	/// - Parameter facility: The parking facility
	func openInMaps(_ facility: ParkingFacility) async {
		let mapItem = await createMapItem(for: facility)

		mapItem.openInMaps(launchOptions: [
			MKLaunchOptionsMapCenterKey: NSValue(
				mkCoordinate: facility.coordinate
			),
			MKLaunchOptionsMapSpanKey: NSValue(
				mkCoordinateSpan: MKCoordinateSpan(
					latitudeDelta: 0.01,
					longitudeDelta: 0.01
				)
			),
		])

		Logger.maps.info("🗺️ Opened \(facility.name) in Apple Maps")
	}

	/// Opens Apple Maps with directions to the facility
	/// - Parameters:
	///   - facility: The parking facility
	///   - transportType: The transport mode (default: automobile)
	func openInMapsWithDirections(
		_ facility: ParkingFacility,
		transportType: MKDirectionsTransportType = .automobile
	) async {
		let mapItem = await createMapItem(for: facility)

		mapItem.openInMaps(launchOptions: [
			MKLaunchOptionsDirectionsModeKey: transportType.launchOptionsValue
		])

		Logger.maps.info(
			"🧭 Opened directions to \(facility.name) in Apple Maps"
		)
	}

	/// Opens a MapItem in Apple Maps
	/// - Parameter mapItem: The map item to open
	func openInMaps(_ mapItem: MKMapItem) {
		mapItem.openInMaps(launchOptions: [
			MKLaunchOptionsMapCenterKey: NSValue(
				mkCoordinate: mapItem.placemark.coordinate
			),
			MKLaunchOptionsMapSpanKey: NSValue(
				mkCoordinateSpan: MKCoordinateSpan(
					latitudeDelta: 0.01,
					longitudeDelta: 0.01
				)
			),
		])

		Logger.maps.info("🗺️ Opened map item in Apple Maps")
	}

	/// Get a formatted address string from a coordinate
	/// - Parameter coordinate: The coordinate
	/// - Returns: A formatted address string, or nil if geocoding fails
	/// 	- Notes: New method on iOS 26+ as `MKPlacemark` is being deprecated
	func getFormattedAddress(for coordinate: CLLocationCoordinate2D) async
		-> String?
	{
		do {

			let location = CLLocation(
				latitude: coordinate.latitude,
				longitude: coordinate.longitude
			)

			if #available(iOS 26.0, *) {
				guard let request = MKReverseGeocodingRequest(
					location: location
				) else {
					throw MapsManagerError.geocodingFailed
				}

				let mapItems = try await request.mapItems

				guard let mapItem = mapItems.first else {
					throw MapsManagerError.geocodingFailed
				}

				if let address = mapItem.address {
					return address.fullAddress
				} else {
					return nil
				}
			} else {

				let geocoder = CLGeocoder()
				let placemarks = try await geocoder.reverseGeocodeLocation(location)

				Logger.maps.debug(
					"📍 Reverse geocoded coordinate: found \(placemarks.count) result(s)"
				)

				guard let placemark = placemarks.first else {
					return nil
				}

				var addressParts: [String] = []

				if let street = placemark.thoroughfare {
					addressParts.append(street)
				}
				if let city = placemark.locality {
					addressParts.append(city)
				}
				if let state = placemark.administrativeArea {
					addressParts.append(state)
				}
				if let postalCode = placemark.postalCode {
					addressParts.append(postalCode)
				}

				return addressParts.joined(separator: ", ")
			}

		} catch {
			Logger.maps.error(
				"❌ Reverse geocoding failed: \(error.localizedDescription)"
			)
			return nil
		}
	}
}

// MARK: - Extensions

extension MKDirectionsTransportType {
	/// The launch options value for opening Apple Maps
	var launchOptionsValue: String {
		switch self {
		case .automobile:
			return MKLaunchOptionsDirectionsModeDriving
		case .walking:
			return MKLaunchOptionsDirectionsModeWalking
		case .transit:
			return MKLaunchOptionsDirectionsModeTransit
		default:
			return MKLaunchOptionsDirectionsModeDriving
		}
	}
}

// MARK: - Errors

enum MapsManagerError: LocalizedError {
	case mapItemInitFailed
	case lookAroundUnavailable
	case directionsUnavailable
	case geocodingFailed

	var errorDescription: String? {
		switch self {
		case .mapItemInitFailed:
			return "Unable to create MKMapItem"
		case .lookAroundUnavailable:
			return "Look Around is not available for this location"
		case .directionsUnavailable:
			return "Directions are not available"
		case .geocodingFailed:
			return "Unable to determine address"
		}
	}
}
