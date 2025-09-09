//
//  LocationManager.swift
//  MetroParking
//
//  Created by Tom Kwok on 30/6/2025.
//

import CoreLocation
import Foundation
import MapKit
import OSLog
import SwiftUI

@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {

	static let shared = LocationManager()

	@Published var authorisationStatus: CLAuthorizationStatus = .notDetermined
	@Published var currentLocation: CLLocation?
	@Published var isLocationAvailable: Bool = false
	@Published var isRefreshing: Bool = false
	@Published var errorMsg: String?

	private let locationManager = CLLocationManager()

	override init() {
		super.init()
		setupLocationManger()
	}

	/// Call this when user explicitly wants to use location features
	func requestLocationPermission() {
		print(
			"📍 User requested location permission. Current status: \(authorisationStatus)"
		)

		switch authorisationStatus {
		case .notDetermined:
			locationManager.requestWhenInUseAuthorization()
		case .denied, .restricted:
			showLocationSettingsAlert()
		case .authorizedAlways, .authorizedWhenInUse:
			startLocationUpdates()
		@unknown default:
			break
		}
	}

	/// Get current location or fallback to calculated centre of all facilities
	var userLocation: CLLocationCoordinate2D {
		return currentLocation?.coordinate ?? Self.defaultLocation
	}

	/// Default location -> centre of all facilities
	static let defaultLocation: CLLocationCoordinate2D = {

		let facilities = ParkingFacility.getAllStaticFacilities()

		let coordinates = facilities.map {
			CLLocationCoordinate2D(
				latitude: $0.latitude,
				longitude: $0.longitude
			)
		}

		guard !coordinates.isEmpty else {
			return CLLocationCoordinate2D(
				latitude: -33.8688,
				longitude: 151.2093
			)
		}

		let avgLat =
			coordinates.reduce(0) { $0 + $1.latitude }
			/ Double(coordinates.count)
		let avgLon =
			coordinates.reduce(0) { $0 + $1.longitude }
			/ Double(coordinates.count)

		return CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)

	}()
}

// MARK: - Private methods
extension LocationManager {

	private func setupLocationManger() {
		locationManager.delegate = self
		locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters  // TODO: Play around with different variants
		locationManager.distanceFilter = 100  // Update every 100 metres

		/// Get current authorisation status
		authorisationStatus = locationManager.authorizationStatus
		updateLocationAvailability()

		Logger.location.notice(
			"📍 LocationManager initialised. Default centre: \(Self.defaultLocation.latitude), \(Self.defaultLocation.latitude)"
		)
	}

	private func updateLocationAvailability() {
		isLocationAvailable =
			(authorisationStatus == .authorizedWhenInUse
				|| authorisationStatus == .authorizedAlways)
			&& currentLocation != nil
	}

	private func startLocationUpdates() {
		guard
			authorisationStatus == .authorizedAlways
				|| authorisationStatus == .authorizedWhenInUse
		else {
			print("❌ Location not authorised")
			return
		}

		isRefreshing = true

		locationManager.startUpdatingLocation()
	}

	private func stopLocationUpdates() {
		isRefreshing = false

		locationManager.stopUpdatingLocation()
	}

	private func showLocationSettingsAlert() {
		errorMsg =
			"Location access is required for this feature. Please enable it in Settings."
		print("📍 Need to direct user to Settings")
		// Actually open Settings
		Task { @MainActor in
			if let settingsURL = URL(
				string: UIApplication.openSettingsURLString
			) {
				await UIApplication.shared.open(settingsURL)
			}
		}
	}
}

// MARK: - CLLocationManagerDelegate methods

extension LocationManager {

	/// When iOS successfully gets new location data from GPS/WiFi/cellular
	nonisolated func locationManager(
		_ manager: CLLocationManager,
		didUpdateLocations locations: [CLLocation]
	) {
		guard let location = locations.last else { return }

		Task { @MainActor in
			isRefreshing = false

			/// Only update if location is significantly different (100 m) from the first time
			if currentLocation == nil
				|| currentLocation!.distance(from: location) > 100
			{
				currentLocation = location
				updateLocationAvailability()
				print(
					"📍 Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)"
				)

				// Invalidate cache
				DistanceHelper.clearDistanceCache()
			}
		}
	}

	/// When something went wrong getting location (GPS off, no signal, etc.)
	nonisolated func locationManager(
		_ manager: CLLocationManager,
		didFailWithError error: any Error
	) {
		Task { @MainActor in
			isRefreshing = false

			errorMsg = "Failed to get location: \(error.localizedDescription)"
			print("❌ Location error: \(error.localizedDescription)")
		}
	}

	/// User changes location permissions in Settings or first-time prompt
	nonisolated func locationManagerDidChangeAuthorization(
		_ manager: CLLocationManager
	) {
		Task { @MainActor in
			authorisationStatus = manager.authorizationStatus
			updateLocationAvailability()

			switch manager.authorizationStatus {
			case .notDetermined:
				print("📍 Location permission not determined")
			case .denied, .restricted:
				print("📍 Location permission denied/restricted")
				stopLocationUpdates()
				currentLocation = nil
			case .authorizedWhenInUse, .authorizedAlways:
				print("📍 Location permission granted")
				startLocationUpdates()
			@unknown default:
				break
			}
		}
	}
}
