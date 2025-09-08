//
//  AppStateManager.swift
//  MetroParking
//
//  Created by Tom Kwok on 31/8/2025.
//

import Foundation
import MapKit
import SwiftUI

@MainActor
class AppStateManager: ObservableObject {

	static let shared = AppStateManager()

	@Published var showingMainSheet: Bool = true
	@Published var showingFacilityDetail: Bool = false
	@Published var selectedFacility: ParkingFacility? = nil
	@Published var currentSheetDetent: PresentationDetent = .medium

	private let mapCamera = MapCameraManager.shared

}

// MARK: - Core methods
extension AppStateManager {
	func selectFacility(_ facility: ParkingFacility) {
		selectedFacility = facility
		showingMainSheet = false
		showingFacilityDetail = true
		setSheetDetent(.medium)
		mapCamera.focusOnFacility(facility)
	}

	func deselectFacility() {
		mapCamera.zoomToAll()
		selectedFacility = nil
		showingMainSheet.toggle()
		showingFacilityDetail = false
		setSheetDetent(.medium)
	}

	func selectFacilityWithContext(
		_ centre: CLLocationCoordinate2D,
		nearby: [ParkingFacility]
	) {

		// Show selected facility with context of nearby facilities
		let coordinates = nearby.map {
			CLLocationCoordinate2D(
				latitude: $0.latitude,
				longitude: $0.longitude
			)
		}

		mapCamera.updateCameraPosition(
			trueCentre: centre,
			context: .single,
			animated: true,
			coordinates: coordinates
		)
	}

	func toggleFacilityDetail() {
		showingFacilityDetail.toggle()
	}

	func setSheetDetent(_ detent: PresentationDetent) {
		guard detent != currentSheetDetent else { return }
		currentSheetDetent = detent
	}
}
