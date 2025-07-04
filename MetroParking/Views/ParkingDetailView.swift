//
//  ParkingDetailView.swift
//  MetroParking
//
//  Created by Tom Kwok on 26/6/2025.
//

import MapKit
import SwiftData
import SwiftUI

struct FacilityDetailView: View {

	@Environment(\.modelContext) private var modelContext
	@Environment(\.dismiss) private var dismiss

	let facility: ParkingFacility
	let onDismiss: () -> Void

	private var occupancyProgress: Double {
		guard facility.totalSpaces > 0 else { return 0 }
		return Double(facility.currentOccupancy) / Double(facility.totalSpaces)
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
									// TODO: Direction Button with ETA
									// TODO: Calling user's navigation app
								} label: {
									HStack(alignment: .center, spacing: 8) {
										Spacer()
										Label(
											"Drive there",
											systemImage: "car.fill"
										)
										// TODO: Connect ETA from location service
										Spacer()
									}
								}
								.font(.headline)
								.buttonStyle(.borderedProminent)
								.buttonBorderShape(.capsule)
								.labelStyle(.titleAndIcon)
								.controlSize(.extraLarge)

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

										Gauge(value: occupancyProgress) {
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
											HStack(alignment: .firstTextBaseline, spacing: 2) {
												Text("\(facility.displayAvailableSpots)")
												.font(.largeTitle)
												.fontDesign(.rounded)
												.foregroundStyle(.primary)
												.multilineTextAlignment(.leading)
												.contentTransition(
													.numericText(
														value: Double(
															facility
																.currentAvailableSpots
														)
													)
												)
												
												Text("/ \(facility.totalSpaces)")
													.font(.headline)
													.foregroundStyle(.secondary)
											}
											//								.frame(maxWidth: .infinity)

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
								// TODO: Forecast and trend
							}

							GridRow {
								// TODO: Stats for nerd (rest of information)
								StatList(facility: facility)
									.gridCellColumns(2)
							}
						}
						.padding()
						
						Spacer()
						
					} header: {
						TopBar {
							VStack(alignment: .leading) {
								Text("\(facility.displayName)".localizedCapitalized)
									.font(.title2)
									.lineLimit(1)
								Text(
									"updated \(facility.lastUpdated.formatted(.relative(presentation: .numeric, unitsStyle: .narrow)))"
								)
								.font(.subheadline)
								.fontWeight(.regular)
								.foregroundStyle(.secondary)
							}
						} trailingContent: {
							HStack(alignment: .center) {
								Button {
									facility.isFavourite = !facility.isFavourite
								} label: {
									Label(
										facility.isFavourite ? "Pinned" : "Pin",
										systemImage: facility.isFavourite
											? "star.fill" : "star"
									)
									.frame(width: 24, height: 24)
									.contentTransition(
										.symbolEffect(
											.replace.magic(
												fallback: .downUp.wholeSymbol
											),
											options: .nonRepeating
										)
									)
								}

								Button {
									onDismiss()
									dismiss()
								} label: {
									Label("Close", systemImage: "xmark")
										.frame(width: 24, height: 24)
								}
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
			// TODO: Should refresh when in view
			facility.markAsVisited()
			try? modelContext.save()
		}
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
					(
						"Last Visited",
						"\(facility.lastVisited?.formatted(.dateTime.month().day().hour().minute()) ?? "--")"
					),
				]
			),
		]
	}

	var body: some View {
		LazyVStack(alignment: .leading) {
			ForEach(Array(stats.enumerated()), id: \.offset) { index, section in
				StatsSection(title: section.title, icon: section.icon, stats: section.items)
			}
		}
	}
}

struct StatsSection: View {
	let title: String
	let icon: String
	let stats: [(label: String, value: String)]
	
	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
				// Section header
			HStack(alignment: .center) {
				Label(title, systemImage: icon)
					.font(.caption)
					.fontWeight(.semibold)
					.tracking(0.4)
					.textCase(.uppercase)
					.foregroundStyle(.secondary)
			}
			.padding()
			
				// Grid with proper alignment
			Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 0) {
				ForEach(Array(stats.enumerated()), id: \.offset) { index, stat in
					GridRow {
							// Label column
						Text(stat.label)
							.font(.body)
							.foregroundColor(.primary)
							.multilineTextAlignment(.leading)
							.gridColumnAlignment(.leading)
							.frame(maxWidth: .infinity, alignment: .leading)
						
							// Value column
						Text(stat.value)
							.font(.body)
							.foregroundColor(.secondary)
							.multilineTextAlignment(.trailing)
							.gridColumnAlignment(.trailing)
							.frame(maxWidth: .infinity, alignment: .trailing)
					}
					.padding(.vertical, 12)
					.overlay(
						// Add separator line except for last row
						Group {
							if index < stats.count - 1 {
								Rectangle()
									.frame(height: 0.5)
									.foregroundColor(Color(.separator))
									.padding(.leading, 16)
							}
						},
						alignment: .bottom
					)
				}
			}
			.padding(.horizontal, 16)

		}
		.background(.thickMaterial)
		.clipShape(
			RoundedRectangle(
				cornerRadius: 24,
				style: .continuous
			)
		)
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
				ProgressView("Loading street imagery…")
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
					.font(.caption)
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
		.background(.thickMaterial)
		.clipShape(
			RoundedRectangle(
				cornerRadius: 24,
				style: .continuous
			)
		)
	}
}

#Preview {
	FacilityDetailView(
		facility: PreviewHelper.availableFacility(),
		onDismiss: {
			print("Should close this view")
		}
	)
}
