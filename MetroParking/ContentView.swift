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

struct ForegroundView: View {
	@ObservedObject var appState: AppStateManager
	@ObservedObject var locationState: LocationManager

	@State private var selectedScreen: ScreenView = .pinned
	@State private var showSettingsSheet: Bool = false
	@State private var detailSheetDetent: PresentationDetent = .medium

	/// Tracking scroll position and dynamically change the background of Topbar
	@State private var isScrolled = false
	@State private var initialPosition: CGFloat?

	@ObservedObject private var facilityManager = FacilityManager.shared

	/// SwiftData Queries
	@Query private var allFacilities: [ParkingFacility]

	var body: some View {
		ScrollView {
			/// Track scroll position with GeometryReader
			GeometryReader { proxy in
				Color.clear
					.onChange(of: proxy.frame(in: .named("scroll")).minY) {
						_,
						newValue in
						// Store initial position on first read
						if initialPosition == nil {
							initialPosition = newValue
						}

						// Show background after scrolling 30 points from initial position
						if let initial = initialPosition {
							isScrolled = newValue < (initial)
						}
					}
			}
			.frame(height: 0)

			LazyVStack(alignment: .leading, pinnedViews: .sectionHeaders) {
				Section {
					selectedScreen.destinationView()
				} header: {
					TopBar(showBackground: isScrolled) {
						/// Menu (select views)
						HStack(alignment: .center) {
							Menu {
								ForEach(ScreenView.allCases) { screen in
									Button(action: {
										selectedScreen = screen
									}) {
										HStack {
											Text(screen.displayName)
											Image(systemName: screen.iconName)
										}
									}
								}
							} label: {
								HStack(alignment: .center) {
									Text(selectedScreen.displayName)
										.font(.title)
										.lineLimit(1)
										.multilineTextAlignment(.leading)
										.tracking(-0.4)
									Image(systemName: "chevron.down")
										.font(.callout)
									Spacer()
								}
								.foregroundStyle(.primary)
							}

						}
					} trailingContent: {
						/// Topbar trailing buttons
						HStack(spacing: 16) {

							Button {
								Task {
									await facilityManager
										.performLoad(forced: true)
								}
							} label: {
								Label("Refresh", systemImage: "arrow.clockwise")
									.fontWeight(.semibold)
									.symbolEffect(
										.rotate.clockwise.byLayer,
										options: .repeat(.continuous),
										isActive: facilityManager.isRefreshing
									)
									.frame(width: 24, height: 24)
									.foregroundStyle(.secondary)
							}
							.frame(width: 36, height: 36)
							.disabled(facilityManager.isRefreshing)
							.buttonBorderShape(.circle)
							.buttonStyle(.bordered)
							.foregroundStyle(.primary)
							.controlSize(.regular)

							Button {
								showSettingsSheet = true
							} label: {
								Label("More", systemImage: "ellipsis")
									.fontWeight(.semibold)
									.symbolEffect(
										.wiggle.byLayer,
										options: .nonRepeating,
										isActive: showSettingsSheet
									)
									.frame(width: 24, height: 24)
									.foregroundStyle(.secondary)
							}
							.frame(width: 36, height: 36)
							.buttonBorderShape(.circle)
							.buttonStyle(.bordered)
							.foregroundStyle(.primary)
							.controlSize(.regular)
						}
					}
				}
			}
		}
		.fontDesign(.rounded)
		.coordinateSpace(name: "scroll")
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
					onDismiss: appState
						.toggleFacilityDetail
				)
				.presentationDetents(
					Set(SheetState.allCases.map { $0.detent }),
					selection: $detailSheetDetent
				)
				.presentationDragIndicator(.hidden)
				.presentationBackgroundInteraction(.enabled(upThrough: .medium))
				.presentationBackground(.thinMaterial)
			}
		}
		.sheet(isPresented: $showSettingsSheet) {
			SettingsView()
				.presentationDetents([.large])
				.presentationDragIndicator(.visible)
				.presentationBackground(.thickMaterial)
		}
	}
}

struct BackgroundView: View {
	@ObservedObject var appState: AppStateManager
	@ObservedObject var locationState: LocationManager

	@Query var allFacilities: [ParkingFacility]
	@State private var showLocationPermissionAlert = false
	@State private var showLocationSettingsAlert = false

	var body: some View {
		VStack {
			Map(
				position: $appState.cameraPosition
			) {
				UserAnnotation()

				ForEach(allFacilities, id: \.facilityId) { facility in

					Annotation(
						facility.displayName,
						coordinate: CLLocationCoordinate2D(
							latitude: facility.latitude,
							longitude: facility.longitude
						)
					) {
						ParkingMapAnnotation(
							facility: facility,
							isSelected: appState.selectedFacility?.facilityId
								== facility.facilityId
						)
						.onTapGesture {
							appState.selectFacility(facility)
						}
					}

				}
			}
			.mapStyle(
				.standard(
					elevation: .realistic,
					emphasis: .muted,
					pointsOfInterest: [.publicTransport],
					showsTraffic: false
				)
			)
			.mapControls {
				MapScaleView()
				MapCompass()
			}
		}
		.overlay(alignment: .trailing) {
			VStack {
				Button {
					switch locationState.authorisationStatus {
					case .notDetermined, .restricted, .denied:
						showLocationPermissionAlert = true
					case .authorizedAlways, .authorizedWhenInUse:

						let newRegion =
							MapCameraHelper.getNearestFacilitiesRegion(
								facilities: allFacilities,
								count: 5,
							)

						withAnimation(.snappy(duration: 1.5)) {
							appState.cameraPosition = .region(newRegion)
						}

					@unknown default:
						showLocationPermissionAlert = true
					}
				} label: {
					VStack(alignment: .center, spacing: 8) {
						if locationState.isRefreshing {
							ProgressView()
						} else {
							Label(
								"Current Location",
								systemImage: locationState.isLocationAvailable
									? "location.fill" : "location"
							)
							.font(.headline)
							.frame(width: 40, height: 40)
							.background(.regularMaterial, in: Circle())
							.padding(.trailing)
							.contentTransition(
								.symbolEffect(.replace, options: .default)
							)
							.labelStyle(.iconOnly)
						}
					}
				}
				.sheet(isPresented: $showLocationPermissionAlert) {
					PermissionView()
						.presentationDetents([.medium])
						.presentationBackgroundInteraction(.disabled)

				}
				Spacer()
			}
		}
	}
}

#Preview("Normal App State") {
	ContentView()
		.modelContainer(PreviewHelper.previewContainer(withSamplePins: false))
}

#Preview("Foreground Sheet") {
	ForegroundView(
		appState: AppStateManager(),
		locationState: LocationManager()
	)
	.modelContainer(PreviewHelper.previewContainer(withSamplePins: false))
}
