//
//  OpenInMapsHelper.swift
//  MetroParking
//
//  Created by Tom Kwok on 9/12/2025.
//

import Foundation
import MapKit
import UIKit

enum MapProvider: Identifiable, CaseIterable {
	case appleMaps
	case googleMaps

	var id: String { String(localized: self.displayText) }

	var displayText: LocalizedStringResource {
		switch self {
		case .appleMaps:
			return .navigationOptionAppleMaps
		case .googleMaps:
			return .navigationOptionGoogleMaps
		}
	}

	var icon: String {
		switch self {
			case .appleMaps: "map.fill"
			case .googleMaps: "g.circle.fill"
		}
	}
}

func openInMaps(_ mapItem: MKMapItem, provider: MapProvider) {
	let coordinate: CLLocationCoordinate2D = mapItem.location.coordinate
	let placeName: String? = mapItem.name

	switch provider {
	case .appleMaps:
		mapItem
			.openInMaps(
				launchOptions: [
					MKLaunchOptionsMapCenterKey: NSValue(
						mkCoordinate: coordinate
					),
					MKLaunchOptionsMapSpanKey: NSValue(
						mkCoordinateSpan: MKCoordinateSpan(
							latitudeDelta: 0.01,
							longitudeDelta: 0.01
						)
					),
					MKLaunchOptionsDirectionsModeKey: MKDirectionsTransportType
						.automobile.launchOptionsValue,
				]
			)
	case .googleMaps:
		openInGoogleMaps(coordinate: coordinate, destinationName: placeName)

	}
}

/// Opens Google Maps with directions to the specified coordinate
/// Falls back to Google Maps web URL if the app is not installed
/// - Parameters:
///   - coordinate: The destination coordinate
///   - destinationName: Optional name for the destination
func openInGoogleMaps(
	coordinate: CLLocationCoordinate2D,
	destinationName: String? = nil
) {
	let lat = coordinate.latitude
	let lng = coordinate.longitude

	// Google Maps URL scheme for directions
	var urlString =
		"comgooglemaps://?daddr=\(lat),\(lng)&directionsmode=driving"
	if let name = destinationName?.addingPercentEncoding(
		withAllowedCharacters: .urlQueryAllowed
	) {
		urlString += "&destination_place_id=\(name)"
	}

	guard let googleMapsURL = URL(string: urlString) else { return }

	// Web fallback URL
	var webURLString =
		"https://www.google.com/maps/dir/?api=1&destination=\(lat),\(lng)&travelmode=driving"
	if let name = destinationName?.addingPercentEncoding(
		withAllowedCharacters: .urlQueryAllowed
	) {
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
