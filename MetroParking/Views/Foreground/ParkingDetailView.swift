//
//  ParkingDetailView.swift
//  MetroParking
//
//  Created by Tom Kwok on 26/6/2025.
//

import MapKit
import OSLog
import SwiftData
import SwiftUI

struct ParkingDetailView: View {

	@Environment(\.modelContext) private var modelContext
	@Environment(\.dismiss) private var dismiss

	let facility: ParkingFacility

	/// ETA Services
	@ObservedObject private var facilityManager = FacilityManager.shared
	@ObservedObject private var etaService = ETAService.shared
	@ObservedObject private var locationManager = LocationManager.shared
	@StateObject private var mapCamera = MapCameraManager.shared

	private var isDirectionAvailable: Bool {
		locationManager.isLocationAvailable
			&& (etaService.etaError == nil
				|| etaService.etaError?.isEmpty == true)
	}

	private var occupancyProgress: Double {
		guard facility.totalSpaces > 0 else { return 0 }
		return facility.occupancy
	}

	var body: some View {
		NavigationView {
			ScrollView {
				LazyVStack(
					alignment: .leading,
					spacing: 0,
					pinnedViews: .sectionHeaders
				) {
					Section {
						// Grid
						Grid(verticalSpacing: 16) {
							GridRow {
								/// Drive  there
								Button {
									openInMaps()
								} label: {
									HStack {
										Image(
											systemName: (etaService.etaError
												== nil)
												? "car.fill"
												: "exclamationmark.triangle.fill"
										)
										.contentTransition(
											.symbolEffect(
												.replace.magic(
													fallback: .offUp.byLayer
												),
												options: .nonRepeating
											)
										)

										if etaService.isCalculatingETA {
											ProgressView()
												.font(.footnote)
												.foregroundStyle(.secondary)
										} else if let eta = etaService
											.formattedETA
										{
											Text("\(eta)")
										} else if let error = etaService
											.etaError
										{

											if error
												== "Unable to calculate ETA"
											{
												Text("ETA Unavailable")
											}

										} else {
											Text("Direction")
										}
									}
									.frame(maxWidth: .infinity)

								}
								.font(.headline)
								.buttonStyle(.borderedProminent)
								.buttonBorderShape(.capsule)
								.labelStyle(.titleAndIcon)
								.controlSize(.extraLarge)
								.animation(
									.snappy(duration: 0.4),
									value: etaService.isCalculatingETA
								)
								.animation(
									.snappy(duration: 0.4),
									value: etaService.formattedETA
								)

							}
							.gridCellColumns(2)

							GridRow {
								InfoCard(
									headingIcon: "gauge.with.needle",
									headingText: "Availability"
								) {
									/// Current availability status
									VStack(alignment: .leading, spacing: 8) {
										VStack(alignment: .leading) {
											Text(
												"\(facility.availabilityStatus.text)"

											)
											.font(.largeTitle)
											.fontDesign(.rounded)
											.foregroundStyle(.primary)
											.contentTransition(
												.numericText(
													value: Double(
														facility
															.currentAvailableSpots
													)
												)
											)
										}

										Gauge(
											value: min(
												max(occupancyProgress, 0),
												1
											)
										) {
											Label("Value", systemImage: "car")
										}
										.gaugeStyle(.accessoryLinear)
										.tint(
											Gradient(colors: [
												AvailabilityStatus.available
													.color,
												AvailabilityStatus.almostFull
													.color,
												AvailabilityStatus.full.color,
											])
										)
									}
									.padding()
								}
								InfoCard(
									headingIcon: "circle.grid.cross",
									headingText: "Capacity"
								) {
									/// Current available spaces
									// TODO: Dynamic position of the number
									HStack(alignment: .bottom) {
										VStack(alignment: .leading, spacing: 0)
										{
											HStack(
												alignment: .firstTextBaseline,
												spacing: 2
											) {
												Text(
													"\(facility.displayAvailableSpots)"
												)
												.font(.largeTitle)
												.fontDesign(.rounded)
												.foregroundStyle(.primary)
												.multilineTextAlignment(
													.leading
												)
												.contentTransition(
													.numericText(
														value: Double(
															facility
																.currentAvailableSpots
														)
													)
												)

												Text(
													"/ \(facility.totalSpaces)"
												)
												.font(.headline)
												.foregroundStyle(.secondary)
											}
											Text("spaces")
												.font(.subheadline)
												.foregroundStyle(.secondary)
												.multilineTextAlignment(
													.leading
												)
										}
										Spacer()
									}
									.padding()
								}

							}

							/// Street view
							GridRow {
								/// LookAround Preview
								FacilityLookAroundView(facility: facility)
									.gridCellColumns(2)
							}

							GridRow {
								/// Historical trend view
								InfoCard(
									headingIcon: "chart.bar.xaxis",
									headingText: "Popular Times"
								) {
									ParkingTrendChart(
										facilityId: facility.facilityId
									)
									.padding(.horizontal)
									.padding(.bottom)
								}
								.gridCellColumns(2)
							}

						}
						.padding()

						StatList(facility: facility)
						Spacer()

					} header: {
						TopBar {
							VStack(alignment: .leading) {
								Text(
									"\(facility.displayName)"
										.localizedCapitalized
								)
								.font(.title2)
								.lineLimit(1)
								Text(
									facility.formattedLastUpdated
								)
								.font(.subheadline)
								.fontWeight(.regular)
								.foregroundStyle(.secondary)
							}
						} trailingContent: {
							HStack(spacing: 16) {
								Button {
									facility.isFavourite = !facility.isFavourite
								} label: {
									Label(
										facility.isFavourite ? "Pinned" : "Pin",
										systemImage: facility.isFavourite
											? "star.fill" : "star"
									)
									.frame(width: 24, height: 24)
									.labelStyle(.iconOnly)
									.contentTransition(
										.symbolEffect(
											.replace.magic(
												fallback: .downUp.wholeSymbol
											),
											options: .nonRepeating
										)
									)
								}
								.frame(width: 36, height: 36)

								Button {
									dismiss()
								} label: {
									Label("Close", systemImage: "xmark")
										.frame(width: 24, height: 24)
								}
								.frame(width: 36, height: 36)

							}
							.buttonStyle(.bordered)
							.buttonBorderShape(.circle)
							.foregroundStyle(.secondary)
						}
					}
				}
			}
		}
		.onAppear {
			facility.markAsVisited()
			try? modelContext.save()

			/// Refresh and Calculate ETA when view appears
			Task {
				await facilityManager.loadFacility(facility)
				await calculateETAIfNeeded()
			}
		}
		.onDisappear {
			etaService.cancelETA()
		}
	}

	private func calculateETAIfNeeded() async {
		guard locationManager.isLocationAvailable else {
			Logger.maps.error("📍 Location not available for ETA calculation")
			return
		}

		let userLocation = locationManager.userLocation
		await etaService.calculateETA(from: userLocation, to: facility)
	}

	private func openInMaps() {
		// TODO: Move the `mapItem` part out
		// Create placemark for the facility
		let placemark = MKPlacemark(
			coordinate: CLLocationCoordinate2D(
				latitude: facility.latitude,
				longitude: facility.longitude
			)
		)

		let mapItem = MKMapItem(placemark: placemark)
		mapItem.name = facility.displayName

		// Open in Maps with driving directions
		let launchOptions = [
			MKLaunchOptionsDirectionsModeKey:
				MKLaunchOptionsDirectionsModeDriving
		]

		mapItem.openInMaps(launchOptions: launchOptions)
	}
}

struct StatList: View {
	let facility: ParkingFacility

	private var stats:
		[(title: String, icon: String, items: [(label: String, value: String)])]
	{
		[
			(
				title: "Location Details",
				icon: "mappin.and.ellipse",
				items: [
					("Address", facility.address),
					("Suburb", facility.suburb),
					(
						"Coordinates",
						"\(facility.latitude), \(facility.longitude)"
					),
				]
			),
			(
				title: "System Information",
				icon: "info.circle",
				items: [
					("Facility ID", facility.facilityId),
					("TSN", facility.tsn),
					("TfNSW Facility ID", facility.tfnswFacilityId),
				]
			),
		]
	}

	var body: some View {
		LazyVStack(alignment: .leading, spacing: 12) {
			ForEach(Array(stats.enumerated()), id: \.offset) { index, section in
				VStack(alignment: .leading, spacing: 16) {
					// Section Header
					Label(section.title, systemImage: section.icon)
						.font(.subheadline)
						.fontWeight(.semibold)
						.tracking(0.4)
						.textCase(.uppercase)
						.foregroundStyle(.secondary)
						.padding(.horizontal)

					// Section Items
					ForEach(Array(section.items.enumerated()), id: \.offset) {
						itemIndex,
						item in
						VStack {
							HStack {
								Text(item.label)
								Spacer()
								Text(item.value)
									.foregroundStyle(.secondary)
							}
							.padding(.vertical, 4)

							Divider()
						}
						.padding(.horizontal)
					}
				}
				.padding(.vertical)
				.background(.background)
				.clipShape(
					RoundedRectangle(
						cornerRadius: 24,
						style: .continuous
					)
				)
			}
		}
		.padding(.horizontal)

	}
}

struct FacilityLookAroundView: View {

	let facility: ParkingFacility

	@State private var scene: MKLookAroundScene?
	@State private var presentFullScreen = false

	var body: some View {
		VStack {
			if scene != nil {
				LookAroundPreview(scene: $scene)
					.onTapGesture { presentFullScreen = true }
					.sheet(isPresented: $presentFullScreen) {
						LookAroundPreview(scene: $scene)
							.edgesIgnoringSafeArea(.all)
					}
			} else {
				ProgressView("Loading Street View")
					.foregroundStyle(.secondary)
					// TODO: If loading time over 30(15?) seconds, error msg should appear
					.task { await loadScene() }  // runs only once
			}
		}
		.frame(maxWidth: .infinity, minHeight: 184)
		.background(.thickMaterial)
		.clipShape(
			RoundedRectangle(
				cornerRadius: 24,
				style: .continuous
			)
		)
	}

	@MainActor
	private func loadScene() async {
		let coordinate = CLLocationCoordinate2D(
			latitude: facility.latitude,
			longitude: facility.longitude
		)

		let request = MKLookAroundSceneRequest(coordinate: coordinate)
		scene = try? await request.scene
	}
}

struct InfoCard<Content: View>: View {
	let headingIcon: String
	let headingText: String

	private let content: () -> Content

	init(
		headingIcon: String,
		headingText: String,
		@ViewBuilder content: @escaping () -> Content
	) {
		self.headingIcon = headingIcon
		self.headingText = headingText
		self.content = content
	}

	var body: some View {
		VStack(alignment: .leading) {
			HStack(alignment: .center) {
				Label(headingText, systemImage: headingIcon)
					.font(.subheadline)
					.fontWeight(.semibold)
					.tracking(0.4)
					.textCase(.uppercase)
					.foregroundStyle(.secondary)
			}
			.padding()

			Spacer()

			content()
				.frame(maxWidth: .infinity)

		}
		.frame(maxWidth: .infinity, minHeight: 184)
		.background(.background)
		.clipShape(
			RoundedRectangle(
				cornerRadius: 24,
				style: .continuous
			)
		)
	}
}

#Preview {
	ParkingDetailView(
		facility: PreviewHelper.availableFacility(),
	)
}
