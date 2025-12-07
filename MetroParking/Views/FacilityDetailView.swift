//
//  FacilityDetailView.swift
//  MetroParking
//
//  Created by Tom Kwok on 5/12/2025.
//

import Foundation
import MapKit
import SwiftUI

@available(iOS 26.0, *)
struct FacilityDetailView: View {
	var namespace: Namespace.ID
	var facility: ParkingFacility
	@Environment(FacilityManager.self) private var facilityManager
	@Environment(\.dismiss) private var dismiss

	// Fixed camera position to prevent zoom issues
	@State private var cameraPosition: MapCameraPosition

	init(namespace: Namespace.ID, facility: ParkingFacility) {
		self.namespace = namespace
		self.facility = facility
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
					await facilityManager.performLoad(
						forced: true
					)
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

		ToolbarItem(placement: .topBarTrailing) {
			Button {

			} label: {
				Label(
					"Go",
					systemImage: "arrow.trianglehead.turn.up.right.diamond.fill"
				)
				.labelStyle(.titleAndIcon)
			}
			.contentTransition(
				.symbolEffect(.replace.magic(fallback: .downUp))
			)
		}
	}

	@ToolbarContentBuilder
	func BottomBarActions() -> some ToolbarContent {
		ToolbarItem(placement: .bottomBar) {
			Button {
				facility.isFavourite.toggle()
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
			VStack(spacing: 0) {
				// Sticky Map Header with fixed camera
				GeometryReader { geometry in
					let minY = geometry.frame(in: .scrollView).minY
					let size = geometry.size
					let height = size.height + max(minY, 0)

					Map(position: .constant(cameraPosition)) {
						Marker(
							facility.displayName.title,
							coordinate: facility.coordinate
						)
						.tint(.blue)
					}
					.safeAreaPadding(.leading, 26)
					.safeAreaPadding(.bottom, 16)
					.mapStyle(.standard())
					.mapControlVisibility(.hidden)
					.frame(width: size.width, height: height)
					.clipShape(
						ConcentricRectangle(
							corners: .concentric,
							isUniform: true
						)
					)
					.allowsHitTesting(false)
					.offset(y: minY > 0 ? -minY : 0)  // Offset the map upward when pulled down
				}
				.frame(height: 400)
				.zIndex(0)

				// Detail Content with background that overlays the map
				DetailContent(facility: facility)
					.background(Color(.systemGroupedBackground))
					.containerShape(.rect(cornerRadius: 48))
					.zIndex(1)
			}
		}
		.scrollTargetBehavior(.paging)
		.scrollIndicators(.hidden)
		.scrollBounceBehavior(.basedOnSize)
		.ignoresSafeArea(edges: .top)  // Allow map to extend to top
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
		.navigationSubtitle(
			facility.address
		)
		.toolbarTitleDisplayMode(.inline)
		.toolbarBackgroundVisibility(.visible, for: .navigationBar)
		.id(facility.facilityId)  // Ensure view resets when switching facilities
	}
}

@available(iOS 26.0, *)
struct DetailContent: View {
	var facility: ParkingFacility

	@ViewBuilder
	func DetailCard<Content: View>(
		label: (heading: String, icon: String, color: Color),
		@ViewBuilder content: () -> Content
	) -> some View {
		GroupBox {
			Spacer(minLength: 24)
			content()
				.padding(2)
				.frame(
					maxWidth: .infinity,
					alignment: .leading
				)
		} label: {
			Label(label.heading, systemImage: label.icon)
				.foregroundStyle(Color(label.color))
				.font(.subheadline)
				.fontWeight(.semibold)
				.textCase(.uppercase)
				.padding(.top, 2)
		}
//		.labelIconToTitleSpacing(4)
		.fontDesign(.rounded)
		.backgroundStyle(Color(.secondarySystemGroupedBackground))
		.clipShape(
			.rect(corners: .concentric, isUniform: true)
		)
	}

	@ViewBuilder
	func vacancyView() -> some View {
		HStack(alignment: .center) {
			VStack(alignment: .leading) {
				HStack(alignment: .firstTextBaseline) {
					if let vacancy = facility.vacancy {
						HStack(
							alignment: .firstTextBaseline,
							spacing: 0
						) {
							Text("\(vacancy.available)")
								.foregroundStyle(.primary)
							Text("/\(vacancy.total)")
								.foregroundStyle(.secondary)
						}
						.font(.title)
						.fontWeight(.semibold)
						Text("spaces")
							.font(.callout)
							.foregroundStyle(.secondary)
					}
				}

				Text("\(facility.availabilityStatus.text)")
					.font(.headline)
			}

			Spacer()

			if let vacancy = facility.vacancy {
				Gauge(
					value: Double(vacancy.occupied),
					in:
						0...Double(
							vacancy.total
						)
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
	}

//	@ViewBuilder
//	func

	var body: some View {
		VStack(spacing: 16) {
			DetailCard(
				label: (
					"Vacancy",
					"parkingsign.circle.fill",
					.blue
				),
				content: vacancyView
			)
//			DetailCard(label: ("", "", .pink), content: <#T##() -> View#>)

			Spacer(minLength: 400)
		}
		.padding()
	}
}

#Preview("Available Facility") {
	@Previewable @Namespace var namespace
	@Previewable @State var container = PreviewHelper.previewContainer(
		withSamplePins: true
	)

	let facilityManager = PreviewHelper.previewFacilityManager(for: container)

	NavigationStack {
		if #available(iOS 26.0, *) {
			let facility = PreviewHelper.availableFacility()
			FacilityDetailView(
				namespace: namespace,
				facility: facility
			)
			.modelContainer(container)
			.environment(facilityManager)
		} else {
			// Fallback on earlier versions
			Text("Preview unavailable")
		}
	}
}

#Preview("No Data") {
	@Previewable @Namespace var namespace
	@Previewable @State var container = PreviewHelper.previewContainer(
		withSamplePins: true
	)

	let facilityManager = PreviewHelper.previewFacilityManager(for: container)

	NavigationStack {
		if #available(iOS 26.0, *) {
			let facility = PreviewHelper.noDataFacility()
			FacilityDetailView(
				namespace: namespace,
				facility: facility
			)
			.modelContainer(container)
			.environment(facilityManager)
		} else {
			// Fallback on earlier versions
			Text("Preview unavailable")
		}
	}
}
