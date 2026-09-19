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

struct FacilityDetailView: View {
	var facility: ParkingFacility

	@Environment(FacilityManager.self) private var facilityDataMgr
	@Environment(ETAManager.self) private var etaMgr
	@Environment(LocationManager.self) private var locationMgr
	@Environment(\.modelContext) private var modelContext

	@State private var nearbyFacilities: [ParkingFacility] = []
	@State private var lookAround = LookAroundLoader()

	/// Keeps cards readable when the sheet or panel is wide.
	private let readableWidth: CGFloat = 640

	var body: some View {
		ScrollView(.vertical) {
			DetailSections(
				selectedFacility: facility,
				nearbyFacilities: nearbyFacilities,
				lookAround: lookAround
			)
			.frame(maxWidth: readableWidth)
			.frame(maxWidth: .infinity)
			.accessibilityIdentifier("detail-sections")
		}
		.accessibilityElement(children: .contain)
		.accessibilityIdentifier("detail-view")
		.containerShape(.rect(cornerRadius: 32))
		.scrollIndicators(.hidden)
		.toolbar {
			TopBarActions()
		}
		.navigationTitle(facility.displayName.full)
		.navigationSubtitle(Text(facility.location.address))
		.toolbarTitleDisplayMode(.inline)
		.id(facility.facilityId)  // Ensure view resets when switching facilities
		.task(id: "\(facility.facilityId) - initial tasks") {
			try? await Task.sleep(for: .seconds(0.3))  // Defer the tasks after transition
			await performInitialTasks()
		}
		.task(id: "\(facility.facilityId) - load nearby facilities") {
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
		.onChange(of: locationMgr.currentLocation) {
			oldLocation,
			newLocation in
			guard let newLoc = newLocation,
				let oldLoc = oldLocation
			else {
				return
			}
			// recalculate when moved significantly -> respect locationMgr's distanceFilter
			if newLoc.distance(from: oldLoc) > locationMgr.distanceFilter {
				etaMgr.clearCachedRoute(for: facility.facilityId)
				Task {
					await calculateETAIfLocationAvailable()
				}
			}
		}
	}
}

/// Helpers
extension FacilityDetailView {

	private func loadNearbyFacilities(limit: Int) async {
		let descriptor = FetchDescriptor<ParkingFacility>()
		let allFacilities = (try? modelContext.fetch(descriptor)) ?? []

		let origin = CLLocation(
			latitude: facility.location.latitude,
			longitude: facility.location.longitude
		)

		// Compute each distance once, then sort by it.
		let ranked: [(facility: ParkingFacility, distance: CLLocationDistance)] =
			allFacilities
			.filter { $0.facilityId != facility.facilityId }
			.map { candidate in
				let location = CLLocation(
					latitude: candidate.location.latitude,
					longitude: candidate.location.longitude
				)
				return (candidate, origin.distance(from: location))
			}
		nearbyFacilities = ranked
			.sorted { $0.distance < $1.distance }
			.prefix(limit)
			.map(\.facility)
	}

	private func performInitialTasks() async {
		// Mark facility as visited for refresh tier tracking
		facility.markAsVisited()
		try? modelContext.save()

		// Run tasks concurrently without waiting for all to complete
		let coordinate = facility.location.coordinate
		async let lookAroundTask: Void = lookAround.load(at: coordinate)
		async let etaTask: Void = calculateETAIfLocationAvailable()

		// These two are independent and can start immediately
		_ = await (lookAroundTask, etaTask)
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

		ToolbarItem(placement: .topBarTrailing) {
			Button {
				withAnimation(.smooth) {
					facility.isFavourite.toggle()
					try? modelContext.save()
				}
			} label: {
				Image(
					systemName: facility.isFavourite
						? "star.slash.fill" : "star"
				)
				.contentTransition(
					.symbolEffect(.replace)
				)
				.accessibilityLabel(
					Text(
						facility.isFavourite
							? "action.button.pin" : "action.button.unpin"
					)
				)
			}
			.sensoryFeedback(.success, trigger: facility.isFavourite)
		}

		/// Future (v0.5.0+): Live Activity toolbar button for real-time parking monitoring
	}
}

/// Preview wrapper that inserts a sample facility into the model context
private struct FacilityDetailPreviewContainer: View {
	var status: AvailabilityStatus
	@Environment(\.modelContext) private var modelContext
	@State private var facility: ParkingFacility?

	var body: some View {
		Group {
			if let facility {
				NavigationStack {
					FacilityDetailView(facility: facility)
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
		.previewEnvironment()
		.modelContainer(.preview(includeSampleData: true))
}

#Preview("No Data") {
	FacilityDetailPreviewContainer(status: .noData)
		.previewEnvironment()
		.modelContainer(.preview(includeSampleData: true))
}
