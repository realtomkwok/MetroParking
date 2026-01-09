//
//  OpenInMapsHelper.swift
//  MetroParking
//
//  Created by Tom Kwok on 9/12/2025.
//

import MapKit
import Foundation

/// Opens Apple Maps with the specified map item
/// - Parameter mapItem: The map item to display in Apple Maps
func openInMaps(_ mapItem: MKMapItem) {
	mapItem.openInMaps(launchOptions: [
		MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: mapItem.placemark.coordinate),
		MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
	])
}

/// Opens Apple Maps with directions from the current location to the specified map item
/// - Parameters:
///   - mapItem: The destination map item
///   - transportType: The transport type for directions (default: .automobile)
func openInMapsWithDirections(_ mapItem: MKMapItem, transportType: MKDirectionsTransportType = .automobile) {
	mapItem.openInMaps(launchOptions: [
		MKLaunchOptionsDirectionsModeKey: transportType.launchOptionsValue
	])
}
