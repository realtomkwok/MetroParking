//
//  ETAService.swift
//  MetroParking
//
//  Created by Tom Kwok on 5/7/2025.
//

import Foundation
import MapKit

@MainActor
class ETAService: ObservableObject {

  @Published var currentETA: TimeInterval?
  @Published var isCalculatingETA: Bool = false
  @Published var etaError: String?

  private var currentETARequest: MKDirections.Request?

  static let shared = ETAService()

  private init() {}

  func calculateETA(
    from userLocation: CLLocationCoordinate2D,
    to facility: ParkingFacility,
    transportType: MKDirectionsTransportType = .automobile
  ) async {

    isCalculatingETA = true
    etaError = nil

    // Create source and destination (TODO: maybe we can assign MKPlaceMark to each facility?)
    let sourcePlacemark = MKPlacemark(coordinate: userLocation)
    let destinationPlacemark = MKPlacemark(
      coordinate: CLLocationCoordinate2D(
        latitude: facility.latitude,
        longitude: facility.longitude
      )
    )

    let source = MKMapItem(placemark: sourcePlacemark)
    let destination = MKMapItem(placemark: destinationPlacemark)

    let request = MKDirections.Request()
    request.source = source
    request.destination = destination
    request.transportType = transportType
    request.requestsAlternateRoutes = false

    currentETARequest = request

    do {
      let directions = MKDirections(request: request)
      let response = try await directions.calculateETA()

      /// Only update if this is still the current request (same user location?)
      if currentETARequest == request {
        currentETA = response.expectedTravelTime
        isCalculatingETA = false
        print("🚗 ETA calculated: \(formatETA(response.expectedTravelTime))")
      }
    } catch {
      if currentETARequest == request {
        etaError = "Unable to calculate ETA"
        isCalculatingETA = false
        print("❌ ETA calculation failed: \(error.localizedDescription)")
      }
    }
  }

  /// Format ETA time interval to readable string
  func formatETA(_ timeInterval: TimeInterval) -> String {

    let minutes = Int(timeInterval / 60)

    if minutes < 1 {
      return "< 1 min"
    } else if minutes < 60 {
      return "\(minutes) min"
    } else {
      let hours = minutes / 60
      let remainingMinutes = minutes % 60
      if remainingMinutes == 0 {
        return "\(hours) hr"
      } else {
        return "\(hours) hr \(minutes) min"
      }
    }
  }

  /// Get formatted ETA string  for display
  var formattedETA: String? {

    guard let eta = currentETA else { return nil }
    return formatETA(eta)
  }

  /// Cancel current ETA calculation
  func cancelETA() {

    currentETARequest = nil
    isCalculatingETA = false
    etaError = nil
  }

  /// Reset
  func resetETA() {

    cancelETA()
    currentETA = nil
  }
}
