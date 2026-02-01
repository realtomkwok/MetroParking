//
//  FacilityDetailView.swift
//  MetroParking
//
//  Created by Tom Kwok on 5/12/2025.
//

import CoreLocationUI
import Foundation
import MapKit
import SwiftUI
import SwiftUIBackports

struct FacilityDetailView: View {
	var namespace: Namespace.ID
	var facility: ParkingFacility
	var currentLocation: CLLocationCoordinate2D?
	var eta: TimeInterval?

	@Environment(FacilityManager.self) var facilityDataMgr
	@Environment(LookAroundManager.self) var lookAroundMgr
	@Environment(ETAManager.self) var etaMgr
	@Environment(LocationManager.self) var locationMgr
	@Environment(\.modelContext) private var modelContext

	@State private var allowDismissalGesture:
		AllowedNavigationDismissalGestures = .none

	@State private var showMap: Bool = false

	// Fixed camera position to prevent zoom issues
	@State private var cameraPosition: MapCameraPosition

	init(namespace: Namespace.ID, facility: ParkingFacility) {
		self.namespace = namespace
		self.facility = facility
		self.currentLocation = nil
		self.eta = nil
		_cameraPosition = State(
			initialValue: .camera(
				MapCamera(
					centerCoordinate: facility.location.coordinate,
					distance: 500,
					/// Future (v0.5.0+): Dynamic heading with gyroscope movement
					heading: 0,
					pitch: 60
				)
			)
		)
	}

}

/// Body
extension FacilityDetailView {

	private var _navigationTitle: String {
		facility.displayName.subtitle.isEmpty
			? facility.displayName.title
			: "\(facility.displayName.title) (\(facility.displayName.subtitle))"
	}

	var body: some View {
		ScrollView(.vertical) {
			MapHeader
				.zIndex(0)
			// Detail Content with background that overlays the map

			DetailSections(facility: facility)
				.accessibilityIdentifier("detail-sections")
				.backport.concentricClipShape()
				.zIndex(1)
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier("detail-view")
		.containerShape(.rect(cornerRadius: 48))
		.background(Color(UIColor.systemGroupedBackground))
		.scrollTargetBehavior(.paging)
		.scrollIndicators(.hidden)
		.scrollBounceBehavior(.basedOnSize)
		.ignoresSafeArea(edges: .top)
		.toolbarRole(.browser)
		.toolbar {
			TopBarActions()
		}
		.toolbar {
			BottomBarActions()
		}
		.navigationTitle(_navigationTitle)
		.backport.navigationSubtitle(
			Text(facility.location.address)
		)
		.toolbarTitleDisplayMode(.inline)
		.toolbarBackgroundVisibility(.visible, for: .navigationBar)
		// Ensure view resets when switching facilities
		.id(facility.facilityId)
		.task(id: facility.facilityId) {
			try? await Task.sleep(for: .milliseconds(0.3))

			withAnimation(.smooth) {
				showMap = true
			}

			// Update Look Around when facility changes
			lookAroundMgr.coordinate = facility.location.coordinate
			await performInitialTasks()
		}
		.onChange(of: locationMgr.isLocationAvailable) { _, isAvailable in
			if isAvailable {
				// Location just became available, calculate ETA
				Task {
					await calculateETAIfLocationAvailable()
				}
			}
		}
		.navigationAllowDismissalGestures(
			AllowedNavigationDismissalGestures(
				[.swipeToGoBack, .zoomEdgePanToDismiss]
			)
		)
	}

	@ViewBuilder
	private var MapHeader: some View {
		// Sticky Map Header with fixed camera
		if showMap {
			GeometryReader { geometry in
				let minY = geometry.frame(in: .scrollView).minY
				let size = geometry.size
				let height = size.height + max(-minY, minY)

				ZStack(alignment: .bottomTrailing) {
					Map(position: .constant(cameraPosition)) {
						Marker(
							facility.displayName.title,
							systemImage: "parkingsign.circle.fill",
							coordinate: facility.location.coordinate
						)
						.tint(Color.accentColor)
					}
					.safeAreaPadding(.leading, 26)
					.safeAreaPadding(.bottom, 16)
					.mapStyle(
						.standard(
							elevation: .realistic,
							emphasis: .muted,
						)
					)
					.mapControlVisibility(.hidden)
					.frame(width: size.width, height: height)
					.backport.concentricClipShape()
					.allowsHitTesting(false)
					.offset(y: minY > 0 ? -minY : minY * -0.2)
				}
			}
			.frame(height: 400)
			.transition(.blurReplace)
		} else {
			Color.clear
				.frame(height: 400)
		}
	}

	private func performInitialTasks() async {
		// Mark facility as visited for refresh tier tracking
		facility.markAsVisited()
		try? modelContext.save()

		// Run tasks concurrently without waiting for all to complete
		async let lookAroundTask: Void = lookAroundMgr.loadPreview()
		async let etaTask: Void = calculateETAIfLocationAvailable()

		// These two are independent and can start immediately
		_ = await (lookAroundTask, etaTask)

		// Enable dismissal gesture after a short delay
		// This runs after the main tasks to avoid blocking them
		try? await Task.sleep(for: .seconds(1))
		allowDismissalGesture = .all
	}

	/// Calculate ETA if location is available, otherwise show permission prompt if needed
	private func calculateETAIfLocationAvailable() async {
		guard let userLocation = locationMgr.currentLocation?.coordinate else {
			// No location available - request permission if not determined
			if locationMgr.authorisationStatus == .notDetermined {
				locationMgr.requestLocationPermission()
			}
			// If location is denied, respect user's choice and don't show anything
			return
		}

		// Location is available, calculate ETA
		await etaMgr.calculateETA(
			from: userLocation,
			to: facility,
			transportType: .automobile
		)
	}

}

/// Toolbar
extension FacilityDetailView {
	@ToolbarContentBuilder
	func TopBarActions() -> some ToolbarContent {
		ToolbarItem(placement: .topBarTrailing) {
			Button {
				Task {
					await facilityDataMgr.loadFacility(facility)
				}
			} label: {
				ZStack {
					if facilityDataMgr.isRefreshing {
						ProgressView()
							.zIndex(1)
					}

					Image(systemName: "arrow.clockwise")
						.zIndex(0)

				}
				.transition(.blurReplace)
				.contentTransition(.symbolEffect(.replace.downUp))
				.animation(.smooth, value: facilityDataMgr.isRefreshing)
				.disabled(facilityDataMgr.isRefreshing)

			}
			.accessibilityLabel("Refresh")
		}
	}

	@ToolbarContentBuilder
	func BottomBarActions() -> some ToolbarContent {
		ToolbarItem(placement: .bottomBar) {
			Button {
				withAnimation(.smooth) {
					facility.isFavourite.toggle()
					try? modelContext.save()
				}
			} label: {
				Label(
					"Pin",
					systemImage: facility.isFavourite
						? "star.slash.fill" : "star"
				)
			}
			.contentTransition(.symbolEffect(.replace.magic(fallback: .downUp)))
		}

		/// Future (v0.5.0+): Live Activity toolbar button for real-time parking monitoring
	}
}

/// Detail Sections
///  - Vacancy
///  - Traffics
///  - Look Around
///  - Nearby facilities

struct DetailSections: View {
	var facility: ParkingFacility

	@Environment(FacilityManager.self) private var facilityDataMgr
	@Environment(LookAroundManager.self) private var lookAroundMgr
	@Environment(ETAManager.self) private var etaMgr
	@Environment(LocationManager.self) private var locationMgr
	@Environment(\.dismiss) private var dismiss

	@State private var showLocationPermissionAlert: Bool = false

	@ViewBuilder
	func DetailCard<Content: View, TrailingTopContent: View>(
		label: (heading: String, icon: String, color: Color),
		@ViewBuilder content: () -> Content,
		@ViewBuilder trailingTopContent: () -> TrailingTopContent = {
			EmptyView()
		}
	) -> some View {
		VStack(alignment: .leading, spacing: 16) {

			HStack(alignment: .center) {
				Label(label.heading, systemImage: label.icon)
					.foregroundStyle(Color(label.color))
					.font(.subheadline)
					.fontWeight(.semibold)
					.backport.labelIconToTitle(4)

				Spacer()

				trailingTopContent()
			}

			content()
				.frame(
					maxWidth: .infinity,
					alignment: .leading
				)
		}
		.padding(.horizontal, 20)
		.padding(.vertical, 16)
		.background(.regularMaterial)
		.clipShape(.containerRelative)
	}

	@ViewBuilder
	func VacancyView() -> some View {
		HStack(alignment: .center) {
			VStack(alignment: .leading) {
				HStack(alignment: .firstTextBaseline, spacing: 4) {
					let vacancy = facility.vacancy
					HStack(
						alignment: .firstTextBaseline,
						spacing: 0
					) {
						Text("\(vacancy.available)")
							.foregroundStyle(.primary)
							.contentTransition(
								.numericText(value: Double(vacancy.available))
							)
						Text("/\(vacancy.total)")
							.foregroundStyle(.secondary)
							.contentTransition(
								.numericText(value: Double(vacancy.total))
							)
					}
					.font(.title)
					.fontWeight(.semibold)
					.opacity(facility.refreshStatus.staleness.displayOpacity)
					.breathingAnimation(
						facility.refreshStatus.staleness == .stale
							&& facilityDataMgr.isRefreshing
					)

					Text("spaces")
						.font(.callout)
						.foregroundStyle(.secondary)
						.contentTransition(.identity)
				}

				HStack(alignment: .firstTextBaseline, spacing: 4) {
					Text("\(facility.availabilityStatus.text)")
						.font(.headline)
						.transition(.blurReplace)
				}
			}

			Spacer()

			let vacancy = facility.vacancy
			Gauge(
				value: vacancy.occupancy,
				in:
					0...1
			) {
			}
			.frame(width: 96)
			.gaugeStyle(
				.linearCapacity
			)
			.tint(
				AvailabilityStatus.gradient
			)
			.opacity(facility.refreshStatus.staleness.displayOpacity)
		}
		.animation(.smooth, value: facility.refreshStatus.staleness)
	}

	// MARK: - Traffics: ETA, distance to the car park

	@ViewBuilder
	func TrafficView() -> some View {

		// Get ETA from facility's cached route data
		let travelTime: String = {
			if let travelTime = facility.route?.travelTime {
				return etaMgr.formatETA(travelTime)
			}
			return ""
		}()

		let distance: String = {
			if let distance = facility.route?.distance {
				return etaMgr.formatDistance(distance)
			}
			return ""
		}()

		ZStack(alignment: .center) {
			// Loading state
			if !locationMgr.isLocationAvailable {
				if etaMgr.isCalculatingETA {
					ProgressView()
						.controlSize(.large)
						.frame(maxWidth: .infinity, alignment: .center)
						.transition(.blurReplace)
						.zIndex(1)
				} else {
					HStack(alignment: .firstTextBaseline) {
						Text("Location Service is Off")
							.font(.headline)
							.foregroundStyle(.secondary)

						Spacer()

						Button {
							// Check if location is denied, show alert
							// Otherwise, request permission
							if locationMgr.isLocationDenied {
								showLocationPermissionAlert = true
							} else {
								locationMgr.requestLocationPermission()
							}
						} label: {
							Label("Enable", systemImage: "location")
								.font(.subheadline)
								.fontWeight(.semibold)
						}
						.backport.glassButtonStyle(fallbackStyle: .bordered)
						.buttonBorderShape(.capsule)
						.controlSize(.regular)
						.alert(
							"MetroParking works best with Location Services turned on.",
							isPresented: $showLocationPermissionAlert,
							actions: {
								Button("Turn on in Settings") {
									Task { @MainActor in
										if let settingsURL = URL(
											string: UIApplication
												.openSettingsURLString
										) {
											await UIApplication.shared.open(
												settingsURL
											)
										}
									}
								}
								Button(
									"Keep Location Services Off",
									role: .cancel
								) {

								}
							},
							message: {
								Text(
									"You'll get distance, estimated travel times to a carpark from your current location, and improved search results when it is turned on for MetroParking."
								)
							}
						)
					}
					.transition(.blurReplace)
					.zIndex(0)
				}
			} else {
				HStack(alignment: .center) {
					VStack(alignment: .leading, spacing: 4) {
						if travelTime.isEmpty {
							Text("No data")
								.font(.headline)
								.foregroundStyle(.secondary)
						} else {
							Text(travelTime)
								.foregroundStyle(
									facility.route != nil
										? .primary : .secondary
								)
								.font(
									facility.route != nil
										? .title : .headline
								)
								.fontWeight(.semibold)
								.contentTransition(
									.numericText(
										value: etaMgr.currentETA ?? 0
									)
								)
						}

						if !distance.isEmpty {
							HStack(
								alignment: .firstTextBaseline,
								spacing: 4
							) {
								Text(distance)
									.font(.headline)
								Text("away")
									.foregroundStyle(.secondary)
									.font(.caption)
							}
							.foregroundStyle(.primary)
						}
					}
					.frame(maxWidth: .infinity, alignment: .leading)
					.transition(.blurReplace)

					Spacer()

					/// Future: Detect installed map apps and provide selection menu
					Menu {
						Button("Apple Maps") {
							Task {
								let mapItem =
									await facility.getMapItem()
								openInMapsWithDirections(mapItem)
							}
						}
						Button("Google Maps") {
							openInGoogleMaps(
								coordinate: facility.location.coordinate,
								destinationName: facility.name
							)
						}
					} label: {
						Label(
							"GO",
							systemImage:
								"arrow.trianglehead.turn.up.right.diamond.fill"
						)
						.fontWeight(.semibold)
						.labelStyle(.titleAndIcon)
					}
					.menuStyle(.button)
					.controlSize(.regular)
					.backport.glassProminentButtonStyle()
					.containerShape(.circle)
					.contentTransition(
						.symbolEffect(.replace.magic(fallback: .downUp))
					)
					.transition(.blurReplace)
				}
				.zIndex(0)

			}
		}

		.animation(
			.smooth,
			value: locationMgr.isLocationAvailable
		)
		.animation(
			.smooth,
			value: etaMgr.isCalculatingETA
		)
		.animation(
			.smooth,
			value: facility.route?.travelTime
		)
	}

	@ViewBuilder
	func LookAroundView() -> some View {
		let label: (heading: String, icon: String, color: Color) = (
			"Look Around", "binoculars.fill", .accentColor
		)

		ZStack {
			// Loading state
			if lookAroundMgr.isLoading {
				DetailCard(label: label) {
					VStack(spacing: 12) {
						ProgressView()
							.controlSize(.large)
					}
					.frame(maxWidth: .infinity)
				}
				.transition(.blurReplace)
				.zIndex(1)
			} else if let errorMsg = lookAroundMgr.errorMessage {
				DetailCard(label: label) {
					Text(errorMsg)
						.font(.headline)
						.foregroundStyle(.secondary)
						.transition(.blurReplace)
						.zIndex(0)
				}
			} else if let scene = lookAroundMgr.lookAroundScene {
				LookAroundPreview(initialScene: scene)
					.frame(height: 200)
					.clipShape(.containerRelative)
					.transition(.blurReplace)
					.backport.glassEffect(
						.clear,
						in: .rect(
							corners: .concentric,
							isUniform: true
						),
						fallbackBackground: Color(
							UIColor.secondarySystemGroupedBackground
						)
					)
					.zIndex(0)
			}
		}
		.clipShape(.containerRelative)
		.animation(.smooth, value: lookAroundMgr.isLoading)
	}

	/// Future (v0.6.0+): Display nearby parking facilities

	var body: some View {
		VStack {
			DetailCard(
				label: (
					"Vacancy",
					"parkingsign.circle.fill",
					.blue
				),
				content: VacancyView,
				trailingTopContent: {
					TimelineView(.periodic(from: .now, by: 60)) { context in
						let timeInterval = context.date.timeIntervalSince(
							facility.refreshStatus.lastUpdated
						)

						if timeInterval < 60 {
							Text("updated just now")
						} else {
							Text(
								"updated \(facility.refreshStatus.lastUpdated.formatted(.relative(presentation: .named, unitsStyle: .narrow)))"
							)
						}
					}
					.monospacedDigit()
					.font(.footnote)
				}
			)

			DetailCard(
				label: ("Travels", "location.north.circle.fill", .accentColor),
				content: TrafficView
			)

			LookAroundView()
		}
		.padding()

	}
}

#Preview("Available Facility") {
	@Previewable @Namespace var namespace

	NavigationStack {
		FacilityDetailView(
			namespace: namespace,
			facility: ParkingFacility.sample(status: .available)
		)
		.environment(FacilityManager.shared)
		.environment(LookAroundManager.shared)
		.environment(ETAManager.shared)
		.environment(LocationManager.shared)
	}
	.modelContainer(.preview())
}

#Preview("No Data") {
	@Previewable @Namespace var namespace

	NavigationStack {
		FacilityDetailView(
			namespace: namespace,
			facility: ParkingFacility.sample(status: .noData)
		)
		.environment(FacilityManager.shared)
		.environment(LookAroundManager.shared)
		.environment(ETAManager.shared)
		.environment(LocationManager.shared)
	}
	.modelContainer(.preview())
}
