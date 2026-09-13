//
//  MapSheetModel.swift
//  MetroParking
//
//  Created by Tom Kwok on 13/9/2026.
//

import MapKit
import SwiftUI

/// Shared state for the map and the sheet (or floating panel) layered on top of it.
///
/// Lives outside the presentation so selection and navigation survive
/// switching between the bottom sheet (compact width) and the floating panel
/// (regular width, e.g. the iPhone Duo inner display).
@MainActor
@Observable
final class MapSheetModel {

	enum Route: Hashable {
		case facility(id: String)
	}

	/// Height of the collapsed sheet: navigation bar plus search field.
	static let peekHeight: CGFloat = 148
	static let peekDetent: PresentationDetent = .height(peekHeight)
	static let detents: Set<PresentationDetent> = [peekDetent, .medium, .large]

	/// Camera distance when focusing on a single facility.
	static let focusDistance: CLLocationDistance = 1800

	var path: [Route] = []
	var detent: PresentationDetent = .medium
	var camera: MapCameraPosition = .automatic

	/// The facility currently shown in the sheet, if any.
	/// Derived from the navigation path so the map and sheet can never disagree.
	var selectedFacilityId: String? {
		guard case .facility(let id)? = path.last else { return nil }
		return id
	}

	/// Shows a facility's detail, replacing whatever the sheet was showing.
	func select(_ facilityId: String) {
		guard facilityId != selectedFacilityId else { return }
		path = [.facility(id: facilityId)]
		if detent == Self.peekDetent {
			detent = .medium
		}
	}

	/// Returns the sheet to the facility list.
	func deselect() {
		path.removeAll()
	}

	/// Handles a selection change coming from the map itself.
	/// Tapping a pin shows its detail; tapping empty map closes it.
	func handleMapSelection(_ facilityId: String?) {
		guard let facilityId else {
			deselect()
			return
		}
		select(facilityId)
		// Keep the tapped pin visible above the sheet.
		if detent == .large {
			detent = .medium
		}
	}

	func focus(on coordinate: CLLocationCoordinate2D) {
		camera = .camera(
			MapCamera(
				centerCoordinate: coordinate,
				distance: Self.focusDistance
			)
		)
	}

	func showAll() {
		camera = .automatic
	}
}
