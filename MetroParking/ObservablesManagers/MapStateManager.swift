//
//  MapStateManager.swift
//  MetroParking
//
//  Created by Tom Kwok on 27/6/2025.
//

import Foundation
import MapKit
import SwiftUI

@MainActor
class MapStateManager: ObservableObject {

  /// Properties
  @Published var cameraPosition: MapCameraPosition = .region(
    MKCoordinateRegion(
		center: CLLocationCoordinate2D(latitude: -33.8688 - 0.1, longitude: 151.2093 - 0.1),
      span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    ))
  @Published var selectedFacility: ParkingFacility? = nil

  /// Callback for notifying the facility is focused
  var onFacilityFocused: (() -> Void)?

  /// Animation control
  private let animationDuration: TimeInterval = 2

  /// Calculate offset to position facility above the sheet
  let latitudeOffset = 0.004  // Moves center down so facility appears higher

}

/// Methods
extension MapStateManager {

  /// Create a new region centred on the facility
  func focusOnFacility(_ facility: ParkingFacility) {
    let newRegion = MKCoordinateRegion(
      center: CLLocationCoordinate2D(
        latitude: facility.latitude - latitudeOffset,
        longitude: facility.longitude
      ),
      span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )

    withAnimation(.snappy(duration: animationDuration)) {
      cameraPosition = .region(newRegion)
      selectedFacility = facility
    }

    onFacilityFocused?()
  }

  /// Create a driving route to the parking facility from current location

  /// Zoom out to show all facilities
  func showAllFacilities() {
    let allFacilitiesRegion = MKCoordinateRegion(
      center: CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093),  // TODO: Replace this with user's current location
	  span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5))

    withAnimation(.snappy(duration: animationDuration)) {
      cameraPosition = .region(allFacilitiesRegion)
      selectedFacility = nil
    }
  }
}
