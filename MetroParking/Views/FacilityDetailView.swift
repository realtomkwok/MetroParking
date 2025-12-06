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
	
	// Fixed camera position to prevent zoom issues
	@State private var cameraPosition: MapCameraPosition

	init(namespace: Namespace.ID, facility: ParkingFacility) {
		self.namespace = namespace
		self.facility = facility
		_cameraPosition = State(initialValue: .camera(
			MapCamera(
				centerCoordinate: facility.coordinate,
				distance: 400,
				heading: 0,
				pitch: 40
			)
		))
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
					"Go",
					systemImage: "arrow.trianglehead.turn.up.right.diamond.fill"
				)
				.labelStyle(.titleAndIcon)
			}
			.contentTransition(
				.symbolEffect(.replace.magic(fallback: .downUp))
			)
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

	struct DetailContent: View {
		var facility: ParkingFacility
		
		var body: some View {
			VStack(spacing: 16) {
				// Add your facility details here
				GroupBox {
					VStack(alignment: .leading, spacing: 8) {
						Text("Available Spaces")
							.font(.headline)
						if let vacancy = facility.vacancy {
							Text("\(vacancy.available) / \(vacancy.total)")
								.font(.title)
								.bold()
						} else {
							Text("No data available")
								.foregroundStyle(.secondary)
						}
					}
					.frame(maxWidth: .infinity, alignment: .leading)
				}
//				.padding(.horizontal)
				
				GroupBox {
					VStack(alignment: .leading, spacing: 8) {
						Text("Address")
							.font(.headline)
						Text(facility.address)
							.foregroundStyle(.secondary)
					}
					.frame(maxWidth: .infinity, alignment: .leading)
				}
//				.padding(.horizontal)
				
				// Add more content to enable scrolling
				Spacer(minLength: 400)
			}
			.padding(.top, 20)
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
					.mapStyle(.standard())
					.mapControlVisibility(.hidden)
					.frame(width: size.width, height: height)
					.clipShape(
						RoundedRectangle(cornerRadius: 24, style: .continuous)
					)
					.allowsHitTesting(false)
					.offset(y: minY > 0 ? -minY : 0) // Offset the map upward when pulled down
				}
				.frame(height: 400)
				.zIndex(0) // Ensure proper layering
				
				// Detail Content with background that overlays the map
				DetailContent(facility: facility)
					.background(Color(.systemGroupedBackground))
					.clipShape(
						RoundedRectangle(cornerRadius: 24, style: .continuous)
					)
					.zIndex(1) // Content appears above the map
			}
		}
		.scrollTargetBehavior(.paging)
		.scrollIndicators(.hidden)
		.ignoresSafeArea(edges: .top) // Allow map to extend to top
		.toolbarRole(.browser)
		.toolbar {
			TopBarActions()
		}
		.toolbar {
			BottomBarActions()
				.matchedTransitionSource(id: "BottomBarActions", in: namespace)
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
