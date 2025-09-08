//
//  ContentView.swift
//  MetroParking
//
//  Created by Tom Kwok on 18/5/2025.
//

import MapKit
import SwiftData
import SwiftUI

struct ContentView: View {
	@Namespace var namespace

	/// Load SwiftData environment
	@Environment(\.modelContext) private var modelContext

	@ObservedObject private var facilityManager = FacilityManager.shared
	@ObservedObject private var appState = AppStateManager.shared
	@ObservedObject private var mapCamera = MapCameraManager.shared

	/// Location Manager
	@ObservedObject private var locationManager = LocationManager.shared

	/// UI State
	@State private var showingMainSheet = true
	@State private var hasInitialised = false

	private var shouldDisableMainSheetDismiss: Bool {
		appState.showingFacilityDetail
			|| appState.currentSheetDetent == .medium
			|| appState.currentSheetDetent == .large
	}

	private func initialisedApp() async {
		/// Connect the data manager to SwiftData
		facilityManager.setModelContext(modelContext)

		/// Load static facilities
		await facilityManager.loadStaticFacilitiesIfNeeded()

		/// Start loading live data
		await facilityManager.performLoad()

		// Might just replace it with hardcoded coordinates
		mapCamera.setupInitialCameraPosition()

		facilityManager.startAutoRefresh()
	}

	var body: some View {
		ZStack {
			BackgroundView()

				// MARK: - Main sheet
				.sheet(isPresented: $appState.showingMainSheet) {
					ForegroundView()
						.presentationCornerRadius(24)
						.presentationBackground(.thinMaterial)
						.presentationDetents(
							[.fraction(0.2), .medium, .large],
							selection: $appState.currentSheetDetent
						)
						.presentationDragIndicator(.visible)
						.presentationBackgroundInteraction(.enabled)
						.presentationContentInteraction(.automatic)
						.interactiveDismissDisabled(
							true
						)
				}

				// MARK: - Detail Sheet
				.sheet(
					isPresented: $appState.showingFacilityDetail,
					onDismiss: {
						appState.deselectFacility()
					}
				) {
					if let facility = appState.selectedFacility {
						ParkingDetailView(
							facility: facility,
						)
						.presentationDetents(
							[.fraction(0.2), .medium, .large],
							selection: $appState.currentSheetDetent
						)
						.presentationDragIndicator(.hidden)
						.presentationBackgroundInteraction(.enabled)
						.presentationBackground(.thinMaterial)
						.interactiveDismissDisabled(true)
					}
				}
				.task {
					guard !hasInitialised else { return }
					hasInitialised = true
					await initialisedApp()
				}
				.fontDesign(.rounded)
		}
	}

}

enum ScreenView: String, CaseIterable, Identifiable {
	case pinned
	case all

	var id: String { self.rawValue }

	var displayName: String {
		switch self {
		case .pinned: "Pins & Recents"
		case .all: "All Parking"
		}
	}

	var iconName: String {
		switch self {
		case .pinned: "star"
		case .all: "parkingsign.square"
		}
	}

	@ViewBuilder
	func destinationView() -> some View {
		VStack(spacing: 8) {
			Spacer()
			switch self {
			case .pinned:
				PinnedAndRecents()

			case .all:
				AllFacilitiesView()
			}
		}
	}
}

#Preview("Normal App State") {
	ContentView()
		.modelContainer(PreviewHelper.previewContainer(withSamplePins: false))
}
