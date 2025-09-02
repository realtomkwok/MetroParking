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
	@ObservedObject private var appStateManager = AppStateManager.shared

	/// Location Manager
	@ObservedObject private var locationManager = LocationManager.shared

	/// UI State
	@State private var presentMainSheet = true
	@State private var hasInitialised = false

	var body: some View {
		ZStack {
			BackgroundView(
				appState: appStateManager,
				locationState: locationManager
			)

			// MARK: - Main sheet
			.sheet(isPresented: $presentMainSheet) {

				ForegroundView(
					appState: appStateManager,
					locationState: locationManager
				)
				.presentationCornerRadius(24)
				.presentationBackground(.thinMaterial)
				.presentationDetents(
					Set(SheetState.allCases.map { $0.detent }),
					selection: $appStateManager.currentDetent
				)
				.presentationDragIndicator(.visible)
				.presentationBackgroundInteraction(.enabled)
				.presentationContentInteraction(.resizes)
				.interactiveDismissDisabled()
			}

			.task {
				guard !hasInitialised else { return }
				hasInitialised = true
				await initialisedApp()
			}
			.fontDesign(.rounded)
		}
	}

	private func initialisedApp() async {
		/// Connect the data manager to SwiftData
		facilityManager.setModelContext(modelContext)

		/// Load static facilities
		await facilityManager.loadStaticFacilitiesIfNeeded()

		/// Start loading live data
		await facilityManager.performLoad()

		facilityManager.startAutoRefresh()
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
