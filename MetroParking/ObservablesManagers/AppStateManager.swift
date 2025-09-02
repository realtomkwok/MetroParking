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

	// MARK: - Sheet states
	private var detentUpdateTask: Task<Void, Never>?
	private let detentUpdateDelay: TimeInterval = 0.1
	@Published var showingFacilityDetail: Bool = false
	@Published private var _currentDetent: PresentationDetent = .medium

	private let mapCamera = MapCameraHelper()

	var currentDetent: PresentationDetent {
		get { _currentDetent }
		set { updateDetent(newValue) }
	}

	var currentDetentBinding: Binding<PresentationDetent> {
		Binding(get: { self._currentDetent }, set: { self.updateDetent($0) })
	}

	// MARK: - Map states
	@Published var cameraPosition: MapCameraPosition = .region(
		MapCameraHelper.getAllFacilitiesRegion()
	)
	@Published var selectedFacility: ParkingFacility? = nil

}

// MARK: - Core methods
extension AppStateManager {
	func selectFacility(_ facility: ParkingFacility) {
		withAnimation(.easeOut(duration: 2.0)) {
			selectedFacility = facility
			showingFacilityDetail = true
			cameraPosition = MapCameraHelper.cameraZoomIn(facility)
		}
	}

	func deselectFacility() {
		withAnimation(.snappy(duration: 0.3)) {
			cameraPosition = MapCameraHelper.cameraZoomOut()
			selectedFacility = nil
			showingFacilityDetail = false
		}
	}

	func toggleFacilityDetail() {
		showingFacilityDetail.toggle()
	}

	func setDetent(_ detent: PresentationDetent, animated: Bool = true) {
		if animated {
			withAnimation(.snappy(duration: 0.3)) {

			}
		}
	}
}

// MARK: - Helper functions
extension AppStateManager {

	private func updateDetent(_ newDetent: PresentationDetent) {

		// Cancel any pending state
		detentUpdateTask?.cancel()

		// Create a new debounced update task
		detentUpdateTask = Task {
			try? await Task.sleep(
				nanoseconds: UInt64(detentUpdateDelay * 1_000_000_000)
			)

			guard !Task.isCancelled else { return }

			if self._currentDetent != newDetent {
				self._currentDetent = newDetent
			}
		}
	}
}

// MARK: - Supporting types
enum SheetState: CaseIterable {
	case minimised  // When interacting with map
	case medium  // When viewing details
	case large  // For detailed views

	var detent: PresentationDetent {
		switch self {
		case .minimised:
			return .fraction(0.2)
		case .medium:
			return .medium
		case .large:
			return .large
		}
	}
}
