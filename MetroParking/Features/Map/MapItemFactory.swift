//
//  MapItemFactory.swift
//  MetroParking
//
//  Created by Tom Kwok on 19/9/2026.
//

import MapKit

extension ParkingFacility {
	/// Builds a map item from local data only: no network request, so it's
	/// safe to call when the user taps "Go" or when starting directions.
	/// Kept out of the model so the widget doesn't need MapKit.
	func makeMapItem() -> MKMapItem {
		let location = CLLocation(
			latitude: self.location.latitude,
			longitude: self.location.longitude
		)
		let address = MKAddress(
			fullAddress: "\(self.location.address), \(self.location.suburb)",
			shortAddress: self.location.address
		)
		let mapItem = MKMapItem(location: location, address: address)
		mapItem.name = displayName.title
		return mapItem
	}
}
