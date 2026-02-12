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

	@Environment(FacilityManager.self) private var facilityDataMgr
	@Environment(LookAroundManager.self) private var lookAroundMgr
	@Environment(ETAManager.self) private var etaMgr
	@Environment(LocationManager.self) private var locationMgr
	@Environment(\.modelContext) private var modelContext

	@State private var allowDismissalGesture:
		AllowedNavigationDismissalGestures = .none

	@State private var cameraPosition: MapCameraPosition
	@State private var showMap: Bool = false
	@State private var nearbyFacilities: [ParkingFacility]

	init(namespace: Namespace.ID, facility: ParkingFacility) {
		self.namespace = namespace
		self.facility = facility
		_cameraPosition = State(
			initialValue: .camera(
				MapCamera(
					centerCoordinate: facility.location.coordinate,
					distance: 500,
					heading: 0,
					pitch: 60
				)
			)
		)
		_nearbyFacilities = State(initialValue: [])
	}

}

/// Body
extension FacilityDetailView {

	var body: some View {
		ScrollView(.vertical) {
			MapHeader(
				facility: facility,
				showMap: $showMap,
				cameraPosition: $cameraPosition
			)
			.zIndex(0)

			DetailSections(
				namespace: namespace,
				selectedFacility: facility,
				nearbyFacilities: nearbyFacilities
			)
			//			.scrollTargetLayout()
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
		.scrollBounceBehavior(.always)
		.ignoresSafeArea(edges: .top)
		.toolbarRole(.browser)
		.toolbar {
			TopBarActions()
		}
		.toolbar {
			BottomBarActions()
		}
		.navigationTitle(facility.displayName.full)
		.backport.navigationSubtitle(
			Text(facility.location.address)
		)
		.toolbarTitleDisplayMode(.inline)
		.toolbarBackgroundVisibility(.visible, for: .navigationBar)
		.id(facility.facilityId)  // Ensure view resets when switching facilities
		.task(id: facility.facilityId, priority: .high) {
			try? await Task.sleep(for: .seconds(0.3))			// Defer the tasks after transition
			await performInitialTasks()
		}
		.task(id: facility.facilityId) {
			await loadNearbyFacilities(limit: 3)
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
}

/// Helpers
extension FacilityDetailView {

	private func loadNearbyFacilities(limit: Int) async {
		let descriptor = FetchDescriptor<ParkingFacility>()
		let allFacilities = (try? modelContext.fetch(descriptor)) ?? []

		nearbyFacilities = Array(
			allFacilities
				.filter { $0.facilityId != facility.facilityId }
				.sorted { a, b in
					DistanceHelper.distance(
						from: facility.location.coordinate,
						to: a.location.coordinate
					)
						< DistanceHelper.distance(
							from: facility.location.coordinate,
							to: b.location.coordinate
						)
				}
				.prefix(limit)
		)
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
				scope: .single(facility)
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
				Label {
					Text(
						facility.isFavourite
							? .actionButtonUnpin : .actionButtonPin
					)
				} icon: {
					Image(
						systemName: facility.isFavourite
							? "star.slash.fill" : "star"
					)
					.contentTransition(
						.symbolEffect(.replace.magic(fallback: .downUp))
					)
				}
			}
			.sensoryFeedback(.success, trigger: facility.isFavourite)
		}

		/// Future (v0.5.0+): Live Activity toolbar button for real-time parking monitoring
	}
}

/// Map Header
struct MapHeader: View {
	/// MapKit bug with Metal https://support.revealapp.com/article/34-ios-application-crash-when-inspecting-views-with-mapkit-overlays

	let facility: ParkingFacility

	// Fixed camera position to prevent zoom issues
	@Binding var showMap: Bool
	@Binding var cameraPosition: MapCameraPosition

	var body: some View {
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
					.tint(Color.red)
				}
			}
			.animation(.snappy, value: showMap)
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
	@Environment(\.dismiss) private var dismiss

	@State private var nearbyRoutes:
		[String: (distance: CLLocationDistance, travelTime: TimeInterval)] = [:]

	var body: some View {
		VStack {

			VacancyView(
				selectedFacility: selectedFacility,
				isRefreshing: facilityDataMgr.isRefreshing
			)

			TrafficView(
				selectedFacility: selectedFacility
			)

			NearbyParkingView(
				nearbyFacilities: nearbyFacilities,
				namespace: namespace,
				nearbyRoutes: $nearbyRoutes
			)
			LookAroundView()

		}
		.padding()
		.task(id: selectedFacility.facilityId) {
			try? await Task.sleep(for: .seconds(0.3))

			nearbyRoutes = [:]

			await withTaskGroup(
				of: (String, (CLLocationDistance, TimeInterval)?).self
			) { group in
				for nearby in nearbyFacilities {
					group.addTask { @MainActor in
						let result = await etaMgr.calculateDistanceBetweenFacilities(
							from: selectedFacility,
							to: nearby
						)
						return (nearby.facilityId, result)
					}
				}

				for await (id, result) in group {
					if let result { nearbyRoutes[id] = result }
				}
			}
		}
	}
}

extension DetailSections {

	struct DetailCard<Content: View, TrailingTopContent: View>: View {
		let labelHeading: String
		let labelIcon: String
		let labelColor: Color
		let content: Content
		let trailingTopContent: TrailingTopContent

		init(
			labelHeading: String,
			labelIcon: String,
			labelColor: Color = .accentColor,
			content: Content,
			trailingTopContent: TrailingTopContent
		) {
			self.labelHeading = labelHeading
			self.labelIcon = labelIcon
			self.labelColor = labelColor
			self.content = content
			self.trailingTopContent = trailingTopContent
		}

		var body: some View {
			VStack(alignment: .leading, spacing: 16) {

				HStack(alignment: .center) {
					Label(labelHeading, systemImage: labelIcon)
						.foregroundStyle(Color(labelColor))
						.font(.subheadline)
						.fontWeight(.semibold)
						.backport.labelIconToTitle(4)

					Spacer()

					trailingTopContent
				}

				content
					.frame(
						maxWidth: .infinity,
						alignment: .leading
					)
			}
			.padding(.horizontal, 20)
			.padding(.vertical, 16)
			.glassEffect(.regular, in: .rect(corners: .concentric(minimum: 24)))
			.clipShape(.containerRelative)
		}
	}
}

extension DetailSections {

	struct VacancyView: View {
		let selectedFacility: ParkingFacility
		@State var isRefreshing: Bool

		struct content: View {
			let selectedFacility: ParkingFacility
			@Binding var isRefreshing: Bool

			var body: some View {
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
										.numericText(
											value: Double(vacancy.available)
										)
									)
								Text("/\(vacancy.total)")
									.foregroundStyle(.secondary)
									.contentTransition(
										.numericText(
											value: Double(vacancy.total)
										)
									)
							}
							.font(.title)
							.fontWeight(.semibold)
							.opacity(
								selectedFacility.refreshStatus.staleness
									.displayOpacity
							)
							.breathingAnimation(
								selectedFacility.refreshStatus.staleness
									== .stale
									&& isRefreshing
							)

							Text(.facilityDetailLabelSpaces)
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
					.opacity(
						selectedFacility.refreshStatus.staleness.displayOpacity
					)
				}
				.animation(
					.smooth,
					value: selectedFacility.refreshStatus.staleness
				)
			}
		}

		struct trailingView: View {
			let selectedFacility: ParkingFacility

			var body: some View {
				TimelineView(.periodic(from: .now, by: 60)) { context in
					let timeInterval = context.date.timeIntervalSince(
						selectedFacility.refreshStatus.lastUpdated
					)

					if timeInterval < 60 {
						Text(.dateLabelJustNow)
					} else {
						Text(
							.dateFormatUpdated(
								selectedFacility.refreshStatus.lastUpdated
									.formatted(
										.relative(
											presentation: .named,
											unitsStyle: .narrow
										)
									)
							)
						)
					}
				}
				.monospacedDigit()
				.font(.footnote)
			}
		}

		var body: some View {
			DetailCard(
				labelHeading: String(localized: .facilityDetailSectionVacancy),
				labelIcon: "checkmark.circle.fill",
				content: content(
					selectedFacility: selectedFacility,
					isRefreshing: $isRefreshing
				),
				trailingTopContent: trailingView(
					selectedFacility: selectedFacility
				),
			)
		}
	}

}

extension DetailSections {
	struct TrafficView: View {

		let selectedFacility: ParkingFacility

		@Environment(LocationManager.self) private var locationMgr

		var body: some View {
			DetailCard(
				labelHeading: String(localized: .facilityDetailSectionTravels),
				labelIcon: "location.circle.fill",
				content: Group {
					if locationMgr.isLocationAvailable {
						TravelInfoContent(
							selectedFacility: selectedFacility
						)
					} else {
						LocationPromptContent()
					}
				}
				.animation(
					.smooth,
					value: locationMgr.isLocationAvailable
				),
				trailingTopContent: EmptyView()
			)
		}

		// MARK: - Location Prompt (no route/etaMgr dependency)

		struct LocationPromptContent: View {
			@Environment(LocationManager.self) private var locationMgr
			@State private var showLocationPermissionAlert: Bool = false

			var body: some View {
				HStack(alignment: .firstTextBaseline) {
					Text(.locationAlertTitle)
						.font(.headline)
						.foregroundStyle(.secondary)

					Spacer()

					Button {
						if locationMgr.isLocationDenied {
							showLocationPermissionAlert = true
						} else {
							locationMgr.requestLocationPermission()
						}
					} label: {
						Label(
							.actionButtonEnable,
							systemImage: "location"
						)
						.font(.subheadline)
						.fontWeight(.semibold)
					}
					.backport.glassButtonStyle(fallbackStyle: .bordered)
					.buttonBorderShape(.capsule)
					.controlSize(.regular)
					.alert(
						.locationAlertHeadline,
						isPresented: $showLocationPermissionAlert,
						actions: {
							Button(.locationButtonTurnOnInSettings) {
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
								.locationButtonKeepOff,
								role: .cancel
							) {

							}
						},
						message: {
							Text(.locationAlertDescription)
						}
					)
				}
				.transition(.blurReplace)
			}
		}

		// MARK: - Travel Info (no locationMgr dependency)

		struct TravelInfoContent: View {
			let selectedFacility: ParkingFacility
			@Environment(ETAManager.self) private var etaMgr

			var body: some View {
				HStack(alignment: .center) {
					TravelDataDisplay(
						displayTravelTime: selectedFacility.route.map {
							etaMgr.formatETA($0.travelTime)
						} ?? "",
						displayDistance: selectedFacility.route.map {
							etaMgr.formatDistance($0.distance)
						} ?? "",
						etaValue: etaMgr.currentETA ?? 0
					)

					Spacer()

					NavigationMenuView(
						selectedFacility: selectedFacility
					)
				}
				.animation(
					.smooth,
					value: selectedFacility.route?.travelTime
				)
			}
		}

		// MARK: - Travel Data (POD view — String/Double only, memcmp diffing)

		struct TravelDataDisplay: View {
			let displayTravelTime: String
			let displayDistance: String
			let etaValue: Double

			var body: some View {
				VStack(alignment: .leading, spacing: 4) {
					if displayTravelTime.isEmpty {
						Text(.facilityDetailLabelNoData)
							.font(.headline)
							.foregroundStyle(.secondary)
					} else {
						Text(displayTravelTime)
							.foregroundStyle(.primary)
							.font(.title)
							.fontWeight(.semibold)
							.contentTransition(
								.numericText(
									value: etaValue
								)
							)
					}

					if !displayDistance.isEmpty {
						HStack(
							alignment: .firstTextBaseline,
							spacing: 4
						) {
							Text(displayDistance)
								.font(.headline)
							Text(.facilityDetailLabelAway)
								.foregroundStyle(.secondary)
								.font(.callout)
						}
						.foregroundStyle(.primary)
					}
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				.transition(.blurReplace)
			}
		}

		// MARK: - Navigation Menu (static — no route/etaMgr dependency)

		struct NavigationMenuView: View {
			let selectedFacility: ParkingFacility

			var body: some View {
				Menu {
					Button(
						.navigationOptionAppleMaps,
						systemImage: "map.fill"
					) {
						Task {
							let mapItem =
								await selectedFacility.getMapItem()
							openInMapsWithDirections(mapItem)
						}
					}
					Button(
						.navigationOptionGoogleMaps,
						systemImage: "g.circle.fill"
					) {
						openInGoogleMaps(
							coordinate: selectedFacility.location
								.coordinate,
							destinationName: selectedFacility.name
						)
					}
				} label: {
					Label(
						.actionButtonGo,
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
		}
	}
}

extension DetailSections {

	struct LookAroundView: View {
		@Environment(LookAroundManager.self) private var lookAroundMgr

		@ViewBuilder
		func loadingView() -> some View {
			VStack(spacing: 12) {
				ProgressView()
					.controlSize(.large)
			}
			.frame(maxWidth: .infinity)
		}

		@ViewBuilder
		func errorView(errorMsg: String) -> some View {
			Text(errorMsg)
				.font(.headline)
				.foregroundStyle(.secondary)
		}

		@ViewBuilder
		func lookAroundView(_ scene: MKLookAroundScene) -> some View {
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

		let labelHeading: String = "Look Around"
		let labelIcon: String = "binoculars.circle.fill"

		var body: some View {
			ZStack {
				// Loading state
				if lookAroundMgr.isLoading {
					DetailCard(
						labelHeading: labelHeading,
						labelIcon: labelIcon,
						content: loadingView(),
						trailingTopContent: EmptyView()
					)
					.transition(.blurReplace)
					.zIndex(1)

				} else if let errorMsg = lookAroundMgr.errorMessage {
					DetailCard(
						labelHeading: labelHeading,
						labelIcon: labelIcon,
						content: errorView(errorMsg: errorMsg),
						trailingTopContent: EmptyView()
					)
				} else if let scene = lookAroundMgr.lookAroundScene {
					lookAroundView(scene)
				}
			}
			.clipShape(.containerRelative)
			.animation(.smooth, value: lookAroundMgr.isLoading)
		}
	}
}

extension DetailSections {

	struct NearbyParkingView: View {
		let nearbyFacilities: [ParkingFacility]
		let namespace: Namespace.ID

		@Binding var nearbyRoutes:
			[String: (distance: CLLocationDistance, travelTime: TimeInterval)]

		var sortedNearbyFacilities: [ParkingFacility] {
			nearbyFacilities.sorted { a, b in
				let distA = nearbyRoutes[a.facilityId]?.distance ?? .infinity
				let distB = nearbyRoutes[b.facilityId]?.distance ?? .infinity
				return distA < distB
			}
		}

		struct rowContent: View {
			@Environment(ETAManager.self) private var etaMgr

			let nearbyRoutes:
				[String: (
					distance: CLLocationDistance, travelTime: TimeInterval
				)]
			let facility: ParkingFacility

			var body: some View {
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
						.foregroundStyle(.tertiary)
				}
				.padding(.vertical, 4)
				.contentShape(.rect)

			}
		}

		@ViewBuilder
		func content() -> some View {
			VStack(alignment: .leading, spacing: 12) {

				ForEach(
					sortedNearbyFacilities,
					id: \.facilityId
				) { facility in

					NavigationLink {
						FacilityDetailView(
							namespace: namespace,
							facility: facility
						)
					} label: {
						rowContent(
							nearbyRoutes: nearbyRoutes,
							facility: facility
						)
					}
					.buttonStyle(.plain)
					.foregroundStyle(.primary)

					if facility.facilityId != nearbyFacilities.last?.facilityId
					{
						Divider()
					}
				}
			}
		}

		var body: some View {
			DetailCard(
				labelHeading: String(
					localized: .facilityDetailSectionNearbyParking
				),
				labelIcon: "parkingsign.circle.fill",
				content: content(),
				trailingTopContent: EmptyView()
			)
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
