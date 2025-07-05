//
//  LocationManager.swift
//  MetroParking
//
//  Created by Tom Kwok on 30/6/2025.
//

// Key responsibilities:
// 1. Request permissions appropriately
// 2. Handle different permission states
// 3. Provide current location
// 4. Calculate distances to facilities
// 5. Handle location errors gracefully

import CoreLocation
import Foundation
import MapKit
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

  /// Distance caching
  @Published private var cachedDistances: [String: Double] = [:]
  private var cacheValidLocation: CLLocationCoordinate2D?
  private let cacheValidityDistance: Double = 100.0  // metres

  /// Init
  override init() {
    super.init()
    setupLocationManger()
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

  private func setupLocationManger() {
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters  // TODO: Play around with different variants
    locationManager.distanceFilter = 100  // Update every 100 metres

    /// Get current authorisation status
    authorisationStatus = locationManager.authorizationStatus
    updateLocationAvailability()

    print(
      "📍 LocationManager initialised. Default centre: \(Self.defaultLocation)"
    )
  }

  private func updateLocationAvailability() {
    isLocationAvailable =
      (authorisationStatus == .authorizedWhenInUse
        || authorisationStatus == .authorizedAlways)
      && currentLocation != nil
  }
}

/// Public methods
extension LocationManager {

  /// Call this when user explicitly wants to use location features
  func requestLocationPermission() {
    print("User requested location permission")

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

  /// Calculate distance between two coordinates (in metres)
  func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D)
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
    return fromLocation.distance(from: toLocation) / 1000  // Covert to km
  }

  /// Get distance from user's location to a facility (with caching)
  func distanceToFacility(_ facility: ParkingFacility) -> Double {
    let currentUserLoc = userLocation

    /// Check cache
    if let cachedLoc = cacheValidLocation {
      let moveDistance =
        distance(from: cachedLoc, to: currentUserLoc) * 1000  // Covert to metres

      if moveDistance < cacheValidityDistance {
        /// Use cached distance if available
        if let cached = cachedDistances[facility.facilityId] {
          return cached
        }
      } else {
        /// Clear cache if user moved significantly
        cachedDistances.removeAll()
      }
    }

    /// Calculate new distance
    let facilityCoord = CLLocationCoordinate2D(
      latitude: facility.latitude,
      longitude: facility.longitude
    )
    let newDistance = distance(from: currentUserLoc, to: facilityCoord)

    /// Cache the result
    cachedDistances[facility.facilityId] = newDistance
    cacheValidLocation = currentUserLoc

    return newDistance
  }

  /// Sort facilities by distance from user (most efficient for large lists)
  func sortFacilitiesByDistance(_ facilities: [ParkingFacility])
    -> [ParkingFacility]
  {

    let userLoc = userLocation

    return facilities.sorted { facility1, facility2 in
      let coord1 = CLLocationCoordinate2D(
        latitude: facility1.latitude,
        longitude: facility1.longitude
      )
      let coord2 = CLLocationCoordinate2D(
        latitude: facility2.latitude,
        longitude: facility2.longitude
      )

      let dist1 = distance(from: userLoc, to: coord1)
      let dist2 = distance(from: userLoc, to: coord2)

      return dist1 < dist2
    }
  }

  /// Sort static facility info by distance (for initial loading)
  func sortStaticFacilitiesByDistance(_ facilities: [StaticFacilityInfo])
    -> [StaticFacilityInfo]
  {

    let userLoc = userLocation

    return facilities.sorted { facility1, facility2 in
      let coord1 = CLLocationCoordinate2D(
        latitude: facility1.latitude,
        longitude: facility1.longitude
      )
      let coord2 = CLLocationCoordinate2D(
        latitude: facility2.latitude,
        longitude: facility2.longitude
      )

      let dist1 = distance(from: userLoc, to: coord1)
      let dist2 = distance(from: userLoc, to: coord2)

      return dist1 < dist2
    }
  }

  func calculateCentre(from coordinates: [CLLocationCoordinate2D])
    -> CLLocationCoordinate2D
  {

    /// Calculate centre point from coordinates
    guard !coordinates.isEmpty else {
      return CLLocationCoordinate2D(
        latitude: -33.8688,
        longitude: 151.2093
      )  // Sydney fallback
    }

    let latitudes = coordinates.map { $0.latitude }
    let longitudes = coordinates.map { $0.longitude }

    let centerLat = latitudes.reduce(0, +) / Double(coordinates.count)
    let centerLon = longitudes.reduce(0, +) / Double(coordinates.count)

    return CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
  }

  /// Calculate centre with sheet offset
  func calculateCentreWithOffset(
    from coordinates: [CLLocationCoordinate2D],
    latitudeOffset: Double = 0.15
  ) -> CLLocationCoordinate2D {
    let centre = calculateCentre(from: coordinates)
    return CLLocationCoordinate2D(
      latitude: centre.latitude - latitudeOffset,
      longitude: centre.longitude
    )
  }

  /// Get region for user location + nearest N facilities
  func getNearestFacilitiesRegion(
    facilities: [ParkingFacility],
    count: Int = 5,
    paddingFactor: Double = 1.4
  ) -> MKCoordinateRegion {

    let userLocation = self.userLocation

    let nearestFacilities = sortFacilitiesByDistance(facilities)
      .prefix(count)

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
      minimumSpan: 0.5,
      maximumSpan: 2.0
    )
  }

  /// Get map region that encompasses all facilities with proper offset
  func getAllFacilitiesRegion() -> MKCoordinateRegion {
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
      minimumSpan: 0.5,
      maximumSpan: 2.0
    )
  }

  /// Calculate optimal map region for given coordinates with centring and paddings
  func calculateRegion(
    for coordinates: [CLLocationCoordinate2D],
    paddingFactor: Double = 1.4,
    minimumSpan: Double = 0.01,
    maximumSpan: Double = 2.0
  ) -> MKCoordinateRegion {
    guard !coordinates.isEmpty else {
      return getAllFacilitiesRegion()  // Fallback to default region
    }

    /// Single coordinate
    guard coordinates.count > 1 else {
      return MKCoordinateRegion(
        center: coordinates[0],
        span: MKCoordinateSpan(
          latitudeDelta: minimumSpan * 5,
          longitudeDelta: minimumSpan * 5
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

    let latSpan = max(min(rawLatSpan, maximumSpan), minimumSpan)
    let lonSpan = max(min(rawLonSpan, maximumSpan), minimumSpan)

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
}

/// Private methods
extension LocationManager {

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
    // TODO: Present actual settings alert in UI
  }
}

extension LocationManager {

  /// Calculate ETA to facility using the ETA service
  func calculateETAToFacility(_ facility: ParkingFacility) async {
    guard isLocationAvailable else { return }

    await ETAService.shared.calculateETA(
      from: userLocation,
      to: facility
    )
  }

  /// Get estimated driving time based on distance (rough calculation)
  func estimatedDrivingTime(to facility: ParkingFacility) -> TimeInterval {
    let distance = distanceToFacility(facility)  // in km

    // Rough estimate: 30 km/h average speed in urban areas
    let averageSpeed: Double = 30.0  // km/h
    let timeInHours = distance / averageSpeed

    return timeInHours * 3600  // Convert to seconds
  }

  /// Get formatted estimated driving time
  func formattedEstimatedDrivingTime(to facility: ParkingFacility) -> String {
    let timeInterval = estimatedDrivingTime(to: facility)
    return ETAService.shared.formatETA(timeInterval)
  }
}

extension LocationManager {

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
        cachedDistances.removeAll()
      }
    }
  }

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
