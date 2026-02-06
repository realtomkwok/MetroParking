//
//  FacilityDetailView.swift
//  MetroParking
//
//  Created by Tom Kwok on 5/12/2025.
//

import Foundation
import MapKit
import SwiftData
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

	var body: some View {
		ScrollView(.vertical) {
			MapHeader
				.zIndex(0)

			DetailSections(
				namespace: namespace,
				selectedFacility: facility,
				nearbyFacilities: nearbyFacilities
			)
			.scrollTargetLayout()
			.accessibilityIdentifier("detail-sections")
			.backport.concentricClipShape()
			.zIndex(1)
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier("detail-view")
		.containerShape(.rect(cornerRadius: 48))
		.backgroundStyle(.background)
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
		.task(id: facility.facilityId, priority: .high) {
			try? await Task.sleep(for: .seconds(0.3))
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

	var nearbyFacilities: [ParkingFacility] {
		let descriptor = FetchDescriptor<ParkingFacility>()
		let allFacilities = (try? modelContext.fetch(descriptor)) ?? []

		return Array(
			allFacilities
				.filter { $0.facilityId != facility.facilityId }
				.sorted { a, b in
					DistanceHelper.distance(
						from: facility.location.coordinate,
						to:
							a.location.coordinate
					)
						< DistanceHelper.distance(
							from: facility.location.coordinate,
							to:
								b.location.coordinate
						)
				}
				.prefix(3)
		)
	}

	private var _navigationTitle: String {
		facility.displayName.subtitle.isEmpty
			? facility.displayName.title
			: "\(facility.displayName.title) (\(facility.displayName.subtitle))"
	}

	@ViewBuilder
	private var MapHeader: some View {
		// https://support.revealapp.com/article/34-ios-application-crash-when-inspecting-views-with-mapkit-overlays
		GeometryReader { geometry in
			let minY = geometry.frame(in: .scrollView).minY
			let size = geometry.size
			let height = size.height + max(-minY, minY)

			Map(position: .constant(cameraPosition)) {
				if !showMap {
					EmptyMapContent()
				} else {
					Marker(
						facility.displayName.title,
						systemImage: "parkingsign.circle.fill",
						coordinate: facility.location.coordinate
					)
					.tint(Color.accentColor)
				}
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
		.frame(height: 400)
		.animation(.snappy, value: showMap)

	}

	private func performInitialTasks() async {
		// Mark facility as visited for refresh tier tracking
		facility.markAsVisited()
		try? modelContext.save()

		lookAroundMgr.coordinate = facility.location.coordinate

		withAnimation(.smooth) {
			showMap = true
		}

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
			RefreshButton(
				action: {
					await facilityDataMgr.loadFacility(facility, forced: true)
				},
				isActive: facilityDataMgr.isRefreshing,
				isDisabled: facilityDataMgr.isRefreshing
			)
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
					facility.isFavourite ? .unpin : .pin,
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
	var namespace: Namespace.ID
	var selectedFacility: ParkingFacility
	var nearbyFacilities: [ParkingFacility]

	@Environment(FacilityManager.self) private var facilityDataMgr
	@Environment(LookAroundManager.self) private var lookAroundMgr
	@Environment(ETAManager.self) private var etaMgr
	@Environment(LocationManager.self) private var locationMgr
	@Environment(\.dismiss) private var dismiss

	@State private var showLocationPermissionAlert: Bool = false
	@State private var nearbyRoutes:
		[String: (distance: CLLocationDistance, travelTime: TimeInterval)] = [:]

	struct sectionLabel {
		var heading: String
		var icon: String
		var color: Color = .accentColor
	}

	@ViewBuilder
	func DetailCard<Content: View, TrailingTopContent: View>(
		label: sectionLabel,
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
		.background(.thickMaterial)
		.clipShape(.containerRelative)
	}

	@ViewBuilder
	func VacancyView() -> some View {
		HStack(alignment: .center) {
			VStack(alignment: .leading) {
				HStack(alignment: .firstTextBaseline, spacing: 4) {
					let vacancy = selectedFacility.vacancy
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
					.opacity(
						selectedFacility.refreshStatus.staleness.displayOpacity
					)
					.breathingAnimation(
						selectedFacility.refreshStatus.staleness == .stale
							&& facilityDataMgr.isRefreshing
					)

					Text(.spaces)
						.font(.callout)
						.foregroundStyle(.secondary)
						.contentTransition(.identity)
				}

				HStack(alignment: .firstTextBaseline, spacing: 4) {
					Text("\(selectedFacility.availabilityStatus.text)")
						.font(.headline)
						.transition(.blurReplace)
				}
			}

			Spacer()

			let vacancy = selectedFacility.vacancy
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
			.opacity(selectedFacility.refreshStatus.staleness.displayOpacity)
		}
		.animation(.smooth, value: selectedFacility.refreshStatus.staleness)
	}

	@ViewBuilder
	func VacancyTrailingView() -> some View {
		TimelineView(.periodic(from: .now, by: 60)) { context in
			let timeInterval = context.date.timeIntervalSince(
				selectedFacility.refreshStatus.lastUpdated
			)

			if timeInterval < 60 {
				Text(.updatedJustNow)
			} else {
				Text(.updated(selectedFacility.refreshStatus.lastUpdated.formatted(.relative(presentation: .named, unitsStyle: .narrow)))
				)
			}
		}
		.monospacedDigit()
		.font(.footnote)
	}

	@ViewBuilder
	func TrafficView() -> some View {

		// Get ETA from facility's cached route data
		let travelTime: String = {
			if let travelTime = selectedFacility.route?.travelTime {
				return etaMgr.formatETA(travelTime)
			}
			return ""
		}()

		let distance: String = {
			if let distance = selectedFacility.route?.distance {
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
						Text(.locationServiceIsOff)
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
							Label(.enable, systemImage: "location")
								.font(.subheadline)
								.fontWeight(.semibold)
						}
						.backport.glassButtonStyle(fallbackStyle: .bordered)
						.buttonBorderShape(.capsule)
						.controlSize(.regular)
						.alert(
							.locationServiceMessageTitle,
							isPresented: $showLocationPermissionAlert,
							actions: {
								Button(.turnOnInSettings) {
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
									.keepLocationServicesOff,
									role: .cancel
								) {

								}
							},
							message: {
								Text(.locationServiceMessageDescription)
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
							Text(.noData)
								.font(.headline)
								.foregroundStyle(.secondary)
						} else {
							Text(travelTime)
								.foregroundStyle(
									selectedFacility.route != nil
										? .primary : .secondary
								)
								.font(
									selectedFacility.route != nil
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
								Text(.away)
									.foregroundStyle(.secondary)
									.font(.callout)
							}
							.foregroundStyle(.primary)
						}
					}
					.frame(maxWidth: .infinity, alignment: .leading)
					.transition(.blurReplace)

					Spacer()

					/// Future: Detect installed map apps and provide selection menu
					Menu {
						Button(.appleMaps, systemImage: "map.fill") {
							Task {
								let mapItem =
									await selectedFacility.getMapItem()
								openInMapsWithDirections(mapItem)
							}
						}
						Button(.googleMaps, systemImage: "g.circle.fill") {
							openInGoogleMaps(
								coordinate: selectedFacility.location
									.coordinate,
								destinationName: selectedFacility.name
							)
						}
					} label: {
						Label(
							.go,
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
			value: selectedFacility.route?.travelTime
		)
	}

	@ViewBuilder
	func LookAroundView() -> some View {
		let sectionLabel = sectionLabel(
			heading: "Look Around",
			icon: "binoculars.fill"
		)

		ZStack {
			// Loading state
			if lookAroundMgr.isLoading {
				DetailCard(label: sectionLabel) {
					VStack(spacing: 12) {
						ProgressView()
							.controlSize(.large)
					}
					.frame(maxWidth: .infinity)
				}
				.transition(.blurReplace)
				.zIndex(1)
			} else if let errorMsg = lookAroundMgr.errorMessage {
				DetailCard(label: sectionLabel) {
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

	@ViewBuilder
	func NearbyParkingView() -> some View {
		VStack(alignment: .leading, spacing: 12) {

			ForEach(
				nearbyFacilities,
				id: \.facilityId
			) { facility in

				NavigationLink {
					FacilityDetailView(
						namespace: namespace,
						facility: facility
					)
				} label: {
					HStack {
						ParkingProgressGauge(
							occupancy: facility.vacancy.occupancy,
							available: facility.vacancy.available,
							total: facility.vacancy.total,
							availabilityStatus: facility.availabilityStatus
						)
						.padding(.trailing, 8)

						VStack(alignment: .leading, spacing: 4) {
							Text(facility.displayName.full)
								.font(.headline)
								.lineLimit(1)
							Text(facility.availabilityStatus.text)
								.font(.subheadline)
								.foregroundStyle(.secondary)
						}

						Spacer()

						if let route = nearbyRoutes[facility.facilityId] {
							VStack(alignment: .trailing, spacing: 4) {
								Text(etaMgr.formatDistance(route.distance))
									.font(.subheadline)
								Text(etaMgr.formatETA(route.travelTime))
									.font(.caption)
									.foregroundStyle(.secondary)
							}
						} else {
							ProgressView()
								.controlSize(.small)
						}

						Image(systemName: "chevron.forward")
							.foregroundStyle(Color(uiColor: .tertiaryLabel))
					}
					.padding(.vertical, 4)
				}
				.contentShape(.containerRelative)
				.buttonStyle(.plain)

				if facility.facilityId != nearbyFacilities.last?.facilityId {
					Divider()
				}
			}
		}
	}

	var body: some View {
		VStack {
			DetailCard(
				label: sectionLabel(
					heading: String(localized: .vacancy),
					icon: "checkmark.circle.fill",

				),
				content: VacancyView,
				trailingTopContent: VacancyTrailingView
			)

			DetailCard(
				label: sectionLabel(
					heading: String(localized: .travels),
					icon: "location.circle.fill",

				),
				content: TrafficView
			)
			DetailCard(
				label: sectionLabel(
					heading: String(localized: .nearbyParking),
					icon: "parkingsign.circle.fill",

				),
				content: NearbyParkingView
			)
			LookAroundView()

		}
		.padding()
		.task(id: selectedFacility.facilityId) {
			try? await Task.sleep(for: .seconds(0.3))

			nearbyRoutes = [:]
			for nearby in nearbyFacilities {
				if let result = await etaMgr.calculateDistanceBetweenFacilities(
					from: selectedFacility,
					to: nearby
				) {
					nearbyRoutes[nearby.facilityId] = result
				}
			}
		}
	}
}

/// Preview wrapper that inserts a sample facility into the model context
private struct FacilityDetailPreviewContainer: View {
	var status: AvailabilityStatus
	@Namespace private var namespace
	@Environment(\.modelContext) private var modelContext
	@State private var facility: ParkingFacility?

	var body: some View {
		Group {
			if let facility {
				NavigationStack {
					FacilityDetailView(
						namespace: namespace,
						facility: facility
					)
				}
			} else {
				ProgressView("Loading preview...")
			}
		}
		.task {
			let sample = ParkingFacility.sample(status: status)
			modelContext.insert(sample)
			try? modelContext.save()
			facility = sample
		}
	}
}

#Preview("Available Facility") {
	FacilityDetailPreviewContainer(status: .available)
		.environment(FacilityManager.shared)
		.environment(LookAroundManager.shared)
		.environment(ETAManager.shared)
		.environment(LocationManager.shared)
		.modelContainer(.preview(includeSampleData: true))
}

#Preview("No Data") {
	FacilityDetailPreviewContainer(status: .noData)
		.environment(FacilityManager.shared)
		.environment(LookAroundManager.shared)
		.environment(ETAManager.shared)
		.environment(LocationManager.shared)
		.modelContainer(.preview(includeSampleData: true))
}
