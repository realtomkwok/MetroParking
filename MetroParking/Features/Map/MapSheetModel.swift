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

	/// Gap between the top of the sheet and whatever sits above it: MapKit's
	/// attribution, and our own controls.
	static let controlGap: Double = 16

	/// Metres spanned by the camera when focusing on a single facility.
	static let focusSpan: CLLocationDistance = 1800

	/// Camera span under which annotations show their vacancy count. Roughly a
	/// few suburbs: any wider and neighbouring counts collide.
	static let countSpan: CLLocationDistance = 6_000

	/// Padding applied around the bounding box of the facilities in `showAll`.
	private static let overviewPadding: Double = 1.3

	/// Fallback overview for when no facility coordinates are available yet:
	/// greater Sydney, which is the whole service area.
	static let overviewRegion = MKCoordinateRegion(
		center: CLLocationCoordinate2D(latitude: -33.87, longitude: 151.05),
		latitudinalMeters: 70_000,
		longitudinalMeters: 70_000
	)

	/// How many nearby facilities the opening overview frames.
	static let nearestCount = 5

	var path: [Route] = []
	var detent: PresentationDetent = .medium
	var camera: MapCameraPosition = .automatic

	/// Fraction of the map's height the sheet covers, and of its width the
	/// floating panel covers.
	///
	/// The map draws edge to edge, so nothing else tells the camera about them.
	/// Framing compensates here instead, which keeps the map's drawn area fixed
	/// and leaves the scope change entirely ours to time.
	var bottomOcclusionFraction: Double = 0
	var leadingOcclusionFraction: Double = 0

	/// The facility currently shown in the sheet, if any.
	///
	/// Derived from the navigation path so the map and sheet can never disagree.
	/// Settable so the map can bind its selection straight to it.
	var selectedFacilityId: String? {
		get {
			guard case .facility(let id)? = path.last else { return nil }
			return id
		}
		set { handleMapSelection(newValue) }
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

	/// Frames a single facility.
	///
	/// A region rather than a `MapCamera`: a region is framed into the map's
	/// safe area, so the facility lands in the part of the map the sheet or
	/// panel isn't covering, and it interpolates, so the move glides.
	func focus(on coordinate: CLLocationCoordinate2D) {
		camera = .region(
			framed(
				MKCoordinateRegion(
					center: coordinate,
					latitudinalMeters: Self.focusSpan,
					longitudinalMeters: Self.focusSpan
				)
			)
		)
	}

	/// Frames every facility, falling back to the whole service area when the
	/// store hasn't been seeded yet.
	///
	/// Deliberately not `.automatic`, which re-fits itself whenever the map's
	/// content or insets change — including on every location update and every
	/// refresh write — and so moves the map when nobody asked it to.
	func showAll(fitting coordinates: [CLLocationCoordinate2D]) {
		camera = .region(
			framed(Self.region(fitting: coordinates) ?? Self.overviewRegion)
		)
	}

	/// Turns a region meant for the *visible* part of the map into one for the
	/// whole map frame, so the sheet and panel don't sit on top of the content.
	///
	/// Grows the span so the intended area still fits in what's uncovered, then
	/// pushes the centre under the cover so that area stays centred in the gap.
	func framed(_ region: MKCoordinateRegion) -> MKCoordinateRegion {
		let bottom = Self.usableFraction(bottomOcclusionFraction)
		let leading = Self.usableFraction(leadingOcclusionFraction)
		guard bottom > 0 || leading > 0 else { return region }

		let latitudeDelta = region.span.latitudeDelta / (1 - bottom)
		let longitudeDelta = region.span.longitudeDelta / (1 - leading)

		return MKCoordinateRegion(
			center: CLLocationCoordinate2D(
				// North is up, leading is west: move the centre away from the
				// viewer's gap in both cases.
				latitude: region.center.latitude - latitudeDelta * bottom / 2,
				longitude: region.center.longitude - longitudeDelta * leading / 2
			),
			span: MKCoordinateSpan(
				latitudeDelta: latitudeDelta,
				longitudeDelta: longitudeDelta
			)
		)
	}

	/// Keeps the compensation finite when a cover approaches the whole map.
	private static func usableFraction(_ value: Double) -> Double {
		min(max(value, 0), 0.7)
	}

	/// The region enclosing `coordinates`, padded, with a span no smaller than
	/// a single facility's. `nil` when there is nothing to enclose.
	static func region(
		fitting coordinates: [CLLocationCoordinate2D]
	) -> MKCoordinateRegion? {
		guard let first = coordinates.first else { return nil }

		var minLatitude = first.latitude
		var maxLatitude = first.latitude
		var minLongitude = first.longitude
		var maxLongitude = first.longitude

		for coordinate in coordinates.dropFirst() {
			minLatitude = min(minLatitude, coordinate.latitude)
			maxLatitude = max(maxLatitude, coordinate.latitude)
			minLongitude = min(minLongitude, coordinate.longitude)
			maxLongitude = max(maxLongitude, coordinate.longitude)
		}

		let center = CLLocationCoordinate2D(
			latitude: (minLatitude + maxLatitude) / 2,
			longitude: (minLongitude + maxLongitude) / 2
		)

		// A single facility, or several at one point, spans zero degrees.
		// Clamp to the focus span so the camera doesn't zoom to infinity.
		let minimumSpan = Self.focusSpan / Self.metresPerDegreeLatitude
		let latitudeDelta = max(
			(maxLatitude - minLatitude) * Self.overviewPadding,
			minimumSpan
		)
		let longitudeDelta = max(
			(maxLongitude - minLongitude) * Self.overviewPadding,
			minimumSpan / max(cos(center.latitude * .pi / 180), 0.01)
		)

		return MKCoordinateRegion(
			center: center,
			span: MKCoordinateSpan(
				latitudeDelta: latitudeDelta,
				longitudeDelta: longitudeDelta
			)
		)
	}

	/// Whether the camera is close enough in for annotations to show their counts.
	static func showsCounts(at region: MKCoordinateRegion) -> Bool {
		region.span.latitudeDelta * metresPerDegreeLatitude < countSpan
	}

	/// Close enough anywhere on Earth for framing a map.
	private static let metresPerDegreeLatitude: Double = 111_000
}
