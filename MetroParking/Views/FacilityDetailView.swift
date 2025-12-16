//
//  FacilityDetailView.swift
//  MetroParking
//
//  Created by Tom Kwok on 5/12/2025.
//

import Foundation
import MapKit
import SwiftUI
import SwiftUIBackports

struct FacilityDetailView: View {
	var namespace: Namespace.ID
	var facility: ParkingFacility
	var currentLocation: CLLocationCoordinate2D?
	var eta: TimeInterval?

	@Environment(FacilityManager.self) var facilityManager
	@Environment(LookAroundManager.self) var lookAroundManager
	@Environment(ETAManager.self) var etaManager
	@Environment(LocationManager.self) var locationMgr
	@Environment(\.modelContext) private var modelContext

	@State private var allowDismissalGesture:
		AllowedNavigationDismissalGestures = .none

	// Fixed camera position to prevent zoom issues
	@State private var cameraPosition: MapCameraPosition

	// Permission handling
	@State private var showPermissionSheet: Bool = false

	init(namespace: Namespace.ID, facility: ParkingFacility) {
		self.namespace = namespace
		self.facility = facility
		// Note: Environment objects (locationMgr, etaManager) are not available during init
		// currentLocation and eta will be nil here, but can be accessed in the body
		self.currentLocation = nil
		self.eta = nil
		_cameraPosition = State(
			initialValue: .camera(
				MapCamera(
					centerCoordinate: facility.coordinate,
					distance: 400,
					heading: 0,
					pitch: 60
				)
			)
		)
	}

	@ToolbarContentBuilder
	func TopBarActions() -> some ToolbarContent {
		ToolbarItem(placement: .topBarTrailing) {
			Button {
				Task {
					await facilityManager.loadFacility(facility)
				}
			} label: {
				Image(systemName: "arrow.clockwise")
					.symbolEffect(
						.rotate.clockwise,
						options: .repeat(.continuous),
						value: facilityManager.isRefreshing
					)
			}
			.accessibilityLabel("Refresh")
			.disabled(facilityManager.isRefreshing)
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

		ToolbarItem(placement: .bottomBar) {
			Button {

			} label: {
				Label(
					"Live Activity",
					systemImage: "app.badge"
				)
				.labelStyle(.titleAndIcon)
			}
			.contentTransition(
				.symbolEffect(.replace.magic(fallback: .downUp))
			)
		}
	}

	var body: some View {
		ScrollView(.vertical) {
			ScrollContent
		}
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
		.navigationTitle(
			facility.displayName.subtitle.isEmpty
				? facility.displayName.title
				: "\(facility.displayName.title) (\(facility.displayName.subtitle))"
		)
		.backport.navigationSubtitle(
			Text(facility.address)
		)
		.toolbarTitleDisplayMode(.inline)
		.toolbarBackgroundVisibility(.visible, for: .navigationBar)
		// Ensure view resets when switching facilities
		.id(facility.facilityId)
		.task(id: facility.facilityId) {
			// Update Look Around when facility changes
			lookAroundManager.coordinate = facility.coordinate
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
		.navigationAllowDismissalGestures(allowDismissalGesture)
		.sheet(isPresented: $showPermissionSheet) {
			PermissionView()
				.presentationDetents([.medium])
				.presentationDragIndicator(.visible)
		}
	}

	private var ScrollContent: some View {
		VStack(spacing: 0) {
			MapHeader
			// Detail Content with background that overlays the map
			VStack {
				DetailContent(facility: facility)
					.backport.concentricClipShape()
			}
			.padding()
			.zIndex(1)
		}
		.containerShape(.rect(cornerRadius: 48))
	}

	private var MapHeader: some View {
		// Sticky Map Header with fixed camera
		GeometryReader { geometry in
			let minY = geometry.frame(in: .scrollView).minY
			let size = geometry.size
			let height = size.height + max(-minY, minY)

			ZStack(alignment: .bottomTrailing) {
				Map(position: .constant(cameraPosition)) {
					Marker(
						facility.displayName.title,
						systemImage: "parkingsign.circle.fill",
						coordinate: facility.coordinate
					)
					.tint(Color.accentColor)
				}
				.safeAreaPadding(.leading, 26)
				.safeAreaPadding(.bottom, 16)
				.mapStyle(
					.standard(
						elevation: .realistic,
						emphasis: .muted,
						showsTraffic: true,
					)
				)
				.mapControlVisibility(.hidden)
				.frame(width: size.width, height: height)
				.backport.concentricClipShape()
				.allowsHitTesting(false)
				.offset(y: minY > 0 ? -minY : minY * 0.5)
			}
		}
		.frame(height: 400)
		.zIndex(0)
	}

	private func performInitialTasks() async {
		await withTaskGroup(of: Void.self) { group in
			// Load Look Around preview
			group.addTask {
				await lookAroundManager.loadPreview()
			}

			// Calculate ETA if location available
			group.addTask {
				await calculateETAIfLocationAvailable()
			}

			// Handle dismissal gesture with delay
			group.addTask {
				try? await Task.sleep(for: .seconds(1))
				await MainActor.run {
					allowDismissalGesture = .all
				}
			}
		}
	}

	/// Calculate ETA if location is available, otherwise show permission prompt if needed
	private func calculateETAIfLocationAvailable() async {
		guard let userLocation = locationMgr.currentLocation?.coordinate else {
			// No location available - check if we should prompt
			if locationMgr.shouldShowPermissionPrompt {
				showPermissionSheet = true
			}
			// If location is denied, respect user's choice and don't show anything
			return
		}

		// Location is available, calculate ETA
		await etaManager.calculateETA(
			from: userLocation,
			to: facility,
			transportType: .automobile
		)
	}
}

struct DetailContent: View {
	var facility: ParkingFacility

	@Environment(LookAroundManager.self) private var lookAroundMgr
	@Environment(ETAManager.self) private var etaMgr
	@Environment(LocationManager.self) private var locationMgr

	@State private var lookAroundSceneIsReady: Bool = false

	@ViewBuilder
	func DetailCard<Content: View>(
		label: (heading: String, icon: String, color: Color),
		@ViewBuilder content: () -> Content
	) -> some View {
		VStack(alignment: .leading, spacing: 16) {
			Label(label.heading, systemImage: label.icon)
				.foregroundStyle(Color(label.color))
				.font(.subheadline)
				.fontWeight(.semibold)
				.backport.labelIconToTitle(4)

			content()
				.frame(
					maxWidth: .infinity,
					alignment: .leading
				)
		}
		.padding(.horizontal, 20)
		.padding(.vertical, 18)
		.frame(maxWidth: .infinity, alignment: .leading)
		.backport.glassEffect(
			.regular,
			in: .rect(cornerRadius: 24, style: .circular)
			// NOTE: ConcentricRectangle() filled the shape doesn't work
		)
		.clipShape(.rect(cornerRadius: 24, style: .circular))
		.fontDesign(.rounded)
	}

	@ViewBuilder
	func vacancyView() -> some View {
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
					Text("spaces")
						.font(.callout)
						.foregroundStyle(.secondary)
						.contentTransition(.identity)
				}

				Text("\(facility.availabilityStatus.text)")
					.font(.headline)
					.foregroundStyle(.secondary)
					.transition(.blurReplace)
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
				Gradient(
					colors: AvailabilityStatus.gradientColors
				)
			)
		}
	}

	@ViewBuilder
	func trafficView() -> some View {
		@Bindable var locationMgr = locationMgr
		@Bindable var etaMgr = etaMgr

		// Get ETA from facility's cached route data
		let travelTime: String = {

			if let travelTime = facility.route?.travelTime {
				return etaMgr.formatETA(travelTime)
			}
			return "--"
		}()

		let distance: String = {
			if let distance = facility.route?.distance {
				return etaMgr.formatDistance(distance)
			}
			return ""
		}()

		HStack {
			VStack(alignment: .leading, spacing: 8) {
				if locationMgr.isLocationAvailable {
					// Show ETA when location is available
					HStack(
						alignment: .firstTextBaseline,
						spacing: 0
					) {
						if etaMgr.isCalculatingETA {
							ProgressView()
								.frame(
									maxWidth: .infinity,
									maxHeight: .infinity
								)
								.transition(.blurReplace)
						} else {
							VStack(alignment: .leading, spacing: 4) {
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

								if !distance.isEmpty {
									HStack(
										alignment: .firstTextBaseline,
										spacing: 4
									) {
										Text(distance)
											.foregroundStyle(.primary)
											.font(.headline)
										Text("from")
											.foregroundStyle(.secondary)
											.font(.caption2)
										Label(
											"My Location",
											systemImage: "location.fill"
										)
										.foregroundStyle(.secondary)
										.font(.caption2)
										.backport.labelIconToTitle(2)
									}
									.transition(
										.move(edge: .leading).combined(
											with: .opacity
										)
									)
								}
							}
							.transition(.blurReplace)
						}
					}

				} else {
					// Location not available
					VStack(alignment: .leading, spacing: 6) {
						HStack(alignment: .firstTextBaseline, spacing: 4) {
							Text("--")
								.font(.title)
								.fontWeight(.semibold)
								.foregroundStyle(.tertiary)
						}

						if locationMgr.isLocationDenied {
							Text("Location access denied")
								.font(.subheadline)
								.foregroundStyle(.secondary)
						} else {
							Text("Location required for ETA")
								.font(.subheadline)
								.foregroundStyle(.secondary)
						}
					}
					.transition(.blurReplace)
				}
			}
			.animation(.snappy, value: locationMgr.isLocationAvailable)
			.animation(.snappy, value: etaMgr.isCalculatingETA)
			.animation(.snappy, value: facility.route?.travelTime)

			Spacer()

			if etaMgr.isDirectionAvailable && !etaMgr.isCalculatingETA {
				Menu {
					Button("Apple Maps", systemImage: "map.fill") {
						Task {
							let mapItem = await facility.getMapItem()
							openInMapsWithDirections(mapItem)
						}
					}
					Button("Google Maps") {

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

			//	Show enable button only if permission not granted
			if !locationMgr.isLocationAvailable && !locationMgr.isLocationDenied
			{
				Button {
					locationMgr.requestLocationPermission()
				} label: {
					Text("Enable")
						.font(.subheadline)
						.fontWeight(.semibold)
				}
				.buttonStyle(.borderedProminent)
				.buttonBorderShape(.capsule)
				.controlSize(.small)
				.transition(.blurReplace)
			}
		}
	}

	@ViewBuilder
	func nearbyFacilitiesView() -> some View {
		LazyHStack(alignment: .center) {

		}
	}

	var body: some View {
		DetailCard(
			label: (
				"Vacancy",
				"parkingsign.circle.fill",
				.blue
			),
			content: vacancyView
		)

		DetailCard(
			label: ("Traffics", "location.north.circle.fill", .accentColor),
			content: trafficView
		)

		HStack {
			if let scene = lookAroundMgr.lookAroundScene {
				if #available(iOS 26.0, *) {
					LookAroundPreview(initialScene: scene)
						.frame(height: 200)
						.clipShape(.containerRelative)
						.transition(.opacity)
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
				} else {
					// Fallback on earlier versions
					LookAroundPreview(initialScene: scene)
						.frame(height: 200)
						.clipShape(.containerRelative)
						.transition(.blurReplace)
				}
			} else {
				DetailCard(
					label: ("Look Around", "binoculars.fill", .accentColor)
				) {
					ProgressView()
						.frame(maxWidth: .infinity)
						.padding()
				}
				.transition(.blurReplace)
			}
		}
		.clipShape(.containerRelative)
		.animation(
			.snappy,
			value: lookAroundMgr.lookAroundScene
		)
	}
}

#Preview("Available Facility") {
	@Previewable @Namespace var namespace

	NavigationStack {
		if #available(iOS 26.0, *) {
			FacilityDetailView(
				namespace: namespace,
				facility: ParkingFacility.sample(status: .available)
			)
			.environment(FacilityManager.shared)
			.environment(LookAroundManager.shared)
			.environment(ETAManager.shared)
			.environment(LocationManager.shared)

		} else {
			// Fallback on earlier versions
			Text("Preview unavailable")
		}
	}
	.modelContainer(.preview())
}

#Preview("No Data") {
	@Previewable @Namespace var namespace

	NavigationStack {
		if #available(iOS 26.0, *) {
			FacilityDetailView(
				namespace: namespace,
				facility: ParkingFacility.sample(status: .noData)
			)
			.environment(FacilityManager.shared)
			.environment(LookAroundManager.shared)
			.environment(ETAManager.shared)
			.environment(LocationManager.shared)
		} else {
			// Fallback on earlier versions
			Text("Preview unavailable")
		}
	}
	.modelContainer(.preview())
}
