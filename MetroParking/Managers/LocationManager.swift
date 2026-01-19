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
@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {

	static let shared = LocationManager()

	var authorisationStatus: CLAuthorizationStatus = .notDetermined
	var currentLocation: CLLocation?
	var isLocationAvailable: Bool = false
	var isRefreshing: Bool = false
	var errorMsg: String?

	/// Check if location permission was explicitly denied
	var isLocationDenied: Bool {
		return authorisationStatus == .denied
			|| authorisationStatus == .restricted
	}

	private let CLLocationMgr = CLLocationManager()

	override init() {
		super.init()
		setupLocationManger()
	}

	/// Call this when user explicitly wants to use location features
	func requestLocationPermission() {
		Logger.location.info(
			"📍 User requested location permission. Current status: \(self.authorisationStatus.description)"
		)

		switch authorisationStatus {
		case .notDetermined:
			// Show native iOS permission dialog
			CLLocationMgr.requestWhenInUseAuthorization()
		case .denied, .restricted:
			// Open Settings so user can enable location
			CLLocationMgr.requestWhenInUseAuthorization()
//			openSettings()
		case .authorizedAlways, .authorizedWhenInUse:
			startLocationUpdates()
		@unknown default:
			break
		}
	}
}

// MARK: - Private methods
extension LocationManager {



	private func setupLocationManger() {
		CLLocationMgr.delegate = self
		// 100m accuracy provides good balance for parking distance calculations while preserving battery life
		CLLocationMgr.desiredAccuracy = kCLLocationAccuracyHundredMeters
		CLLocationMgr.distanceFilter = 100  // Update every 100 metres

		/// Get current authorisation status
		authorisationStatus = CLLocationMgr.authorizationStatus
		updateLocationAvailability()
	}

	private func updateLocationAvailability() {
		let wasAvailable = isLocationAvailable
		isLocationAvailable =
			(authorisationStatus == .authorizedWhenInUse
				|| authorisationStatus == .authorizedAlways)
			&& currentLocation != nil

		Logger.location.debug("📍 updateLocationAvailability()")
		Logger.location.debug(
			"  → Authorisation: \(self.authorisationStatus.description)"
		)
		Logger.location
			.debug(
				" → Current location: \(self.currentLocation?.description ?? "Failed to get current location.")"
			)
		Logger.location.debug(
			"  → isLocationAvailable: \(wasAvailable) → \(self.isLocationAvailable)"
		)
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

		CLLocationMgr.startUpdatingLocation()
	}

	private func stopLocationUpdates() {
		isRefreshing = false

		CLLocationMgr.stopUpdatingLocation()
	}

	private func showLocationSettingsAlert() {
		errorMsg =
			"Location access is required for this feature. Please enable it in Settings."
		print("📍 Need to direct user to Settings")
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
			Logger.location.debug("📍 didUpdateLocations")
			Logger.location.debug(
				"  → New location: \(location.coordinate.latitude, format: .fixed(precision: 6)), \(location.coordinate.longitude, format: .fixed(precision: 6))"
			)
			Logger.location.debug(
				"  → Previous location: \(self.currentLocation?.description ?? "Failed to retrieve previous location")"
			)

			isRefreshing = false

			/// Only update if location is significantly different (100 m) from the first time
			if currentLocation == nil
				|| currentLocation!.distance(from: location) > 100
			{
				Logger.location.info(
					"📍 Updating current location (significant change or first location)"
				)
				currentLocation = location
				updateLocationAvailability()

				// Invalidate cache
				DistanceHelper.clearDistanceCache()
			} else {
				Logger.location.debug(
					"  → Location change not significant (<100m), skipping update"
				)
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
			Logger.location.error(
				"❌ Location error: \(error.localizedDescription)"
			)
		}
	}

	/// User changes location permissions in Settings or first-time prompt
	nonisolated func locationManagerDidChangeAuthorization(
		_ manager: CLLocationManager
	) {
		Task { @MainActor in
			Logger.location.debug("📍 didChangeAuthorization")
			Logger.location.debug(
				"  → Old status: \(self.authorisationStatus.description)"
			)
			Logger.location.debug(
				"  → New status: \(manager.authorizationStatus.description)"
			)

			authorisationStatus = manager.authorizationStatus
			updateLocationAvailability()

			switch manager.authorizationStatus {
			case .notDetermined:
				Logger.location.info("📍 Location permission not determined")
			case .denied, .restricted:
				Logger.location.info("📍 Location permission denied/restricted")
				stopLocationUpdates()
				currentLocation = nil
			case .authorizedWhenInUse, .authorizedAlways:
				Logger.location.info(
					"📍 Location permission granted - starting location updates"
				)
				startLocationUpdates()
			@unknown default:
				break
			}
		}
	}
}

extension CLAuthorizationStatus {
	var description: String {
		switch self {

		case .notDetermined:
			return "notDetermined"
		case .restricted:
			return "restricted"
		case .denied:
			return "denied"
		case .authorizedAlways:
			return "authorizedAlways"
		case .authorizedWhenInUse:
			return "authorizedWhenInUse"
		@unknown default:
			return "unknown"
		}
	}
}
