//
//  OpenInMapsHelper.swift
//  MetroParking
//
//  Created by Tom Kwok on 9/12/2025.
//

import MapKit
import Foundation
import UIKit

/// Opens Apple Maps with the specified map item
/// - Parameter mapItem: The map item to display in Apple Maps
func openInMaps(_ mapItem: MKMapItem) {
	mapItem.openInMaps(
launchOptions: [
	MKLaunchOptionsMapCenterKey: NSValue(
		mkCoordinate: mapItem.location.coordinate
	),
		MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
	]
)
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

/// Opens Google Maps with directions to the specified coordinate
/// Falls back to Google Maps web URL if the app is not installed
/// - Parameters:
///   - coordinate: The destination coordinate
///   - destinationName: Optional name for the destination
func openInGoogleMaps(coordinate: CLLocationCoordinate2D, destinationName: String? = nil) {
	let lat = coordinate.latitude
	let lng = coordinate.longitude

	// Google Maps URL scheme for directions
	var urlString = "comgooglemaps://?daddr=\(lat),\(lng)&directionsmode=driving"
	if let name = destinationName?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
		urlString += "&destination_place_id=\(name)"
	}

	guard let googleMapsURL = URL(string: urlString) else { return }

	// Web fallback URL
	var webURLString = "https://www.google.com/maps/dir/?api=1&destination=\(lat),\(lng)&travelmode=driving"
	if let name = destinationName?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
		webURLString += "&destination_place_id=\(name)"
	}
	guard let webFallbackURL = URL(string: webURLString) else { return }

	// Try to open Google Maps app first, fall back to web
	if UIApplication.shared.canOpenURL(googleMapsURL) {
		UIApplication.shared.open(googleMapsURL)
	} else {
		UIApplication.shared.open(webFallbackURL)
	}
}
