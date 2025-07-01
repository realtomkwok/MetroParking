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
    LocationManager.shared.getAllFacilitiesRegion()
  )
  @Published var selectedFacility: ParkingFacility? = nil

  /// Callback for notifying the facility is focused
  var onFacilityFocused: (() -> Void)?

  /// Animation control
  private let animationDuration: TimeInterval = 2

  /// Calculate offset to position facility above the sheet
  private let latitudeOffset = 0.02  // Moves centre down so facility appears higher

}

/// Methods
extension MapStateManager {

  /// Create a new region centred on the facility
  func focusOnFacility(_ facility: ParkingFacility) {

    let facilityCoordinate = CLLocationCoordinate2D(
      latitude: facility.latitude,
      longitude: facility.longitude
    )

    let newRegion = LocationManager.shared.calculateRegion(
      for: [facilityCoordinate],
      paddingFactor: 1.0,
      minimumSpan: 0.01,
      maximumSpan: 0.02
    )

    let offsetCentre = CLLocationCoordinate2D(
      latitude: newRegion.center.latitude - latitudeOffset,
      longitude: newRegion.center.longitude
    )

    let finalRegion = MKCoordinateRegion(center: offsetCentre, span: newRegion.span)

    withAnimation(.snappy(duration: animationDuration)) {
      cameraPosition = .region(finalRegion)
      selectedFacility = facility
    }

    onFacilityFocused?()
  }

  /// Create a driving route to the parking facility from current location

  /// Zoom out to show all facilities
  func showAllFacilities() {
    let allFacilitiesRegion = LocationManager.shared
      .getAllFacilitiesRegion()

    withAnimation(.snappy(duration: animationDuration)) {
      cameraPosition = .region(allFacilitiesRegion)
      selectedFacility = nil
    }
  }
}
