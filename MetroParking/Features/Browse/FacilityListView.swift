//
//  FacilityList.swift
//  MetroParking
//
//  Created by Tom Kwok on 6/12/2025.
//

import Foundation
import SwiftData
import SwiftUI

/// Future features: Live Activity/notification swipe actions (v0.5.0+)
struct FacilityList: View {
	let groupedFacilities:
		[(title: LocalizedStringResource?, facilities: [ParkingFacility])]

	@Environment(FacilityManager.self) private var facilityDataMgr

	// MARK: - Identifiable Section

	private struct FacilitySection: Identifiable {
		let id: String
		let title: LocalizedStringResource?
		let facilities: [ParkingFacility]

		init(title: LocalizedStringResource?, facilities: [ParkingFacility]) {
			self.title = title
			self.facilities = facilities
			self.id = title.map { String(localized: $0) } ?? "untitled"
		}
	}

	private var sections: [FacilitySection] {
		groupedFacilities
			.filter { !$0.facilities.isEmpty }
			.map {
				FacilitySection(
					title: $0.title,
					facilities: $0.facilities
				)
			}
	}

	private var sectionStructureHash: Int {
		var hasher = Hasher()
		for (title, facilities) in groupedFacilities {
			let sectionTitle: String = String(localized: title ?? "")

			hasher.combine(sectionTitle)
			for facility in facilities {
				hasher.combine(facility.persistentModelID)
			}
		}

		return hasher.finalize()
	}

	var body: some View {
		let currentSections = sections

		List {
			ForEach(currentSections) { section in
				Section {
					ForEach(section.facilities, id: \.persistentModelID) {
						facility in
						ListRow(facility: facility)
					}
				} header: {
					if let title = section.title {
						Text(title)
					}
				}
			}
		}
		.refreshable {
			await facilityDataMgr.performLoad(forced: true)
		}
		.accessibilityIdentifier("facility-list")
		.listStyle(.plain)
		// Animate when section structure changes OR when facilities move between sections
		.animation(
			.smooth(),
			value: sectionStructureHash
		)
	}
}

// MARK: - View Components
extension FacilityList {

	struct ListRow: View {
		let facility: ParkingFacility

		@Environment(\.modelContext) private var modelContext

		@ViewBuilder
		private func leadingSwipeAction(for facility: ParkingFacility)
			-> some View
		{
			Button(role: facility.isFavourite ? .destructive : nil) {
				withAnimation(.smooth) {
					facility.isFavourite.toggle()
					// Save the context to persist the change
					try? modelContext.save()
				}
			} label: {
				Label(
					facility.isFavourite
						? .actionButtonUnpin : .actionButtonPin,
					systemImage: facility.isFavourite
						? "star.slash" : "star.fill"
				)
				.labelStyle(.iconOnly)
			}
			.tint(facility.isFavourite ? .red : .yellow)
		}

		var body: some View {
			NavigationLink(value: MapSheetModel.Route.facility(id: facility.facilityId)) {
				rowContent(facility: facility)
			}
			.accessibilityIdentifier("facility-row-\(facility.facilityId)")
			// TODO: add AccessibilityHint and AccessibilityLabel
			.listRowInsets(
				EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16)
			)
			.listRowBackground(Color.clear)
			.swipeActions(edge: .leading) {
				leadingSwipeAction(for: facility)
			}
		}
	}

	struct rowContent: View {
		let facility: ParkingFacility

		@Environment(LocationManager.self) private var locationMgr
		@Environment(ETAManager.self) private var etaMgr
		@Environment(FacilityManager.self) private var facilityDataMgr

		var body: some View {
			HStack(alignment: .center, spacing: 12) {
				VStack(alignment: .center) {
					ParkingProgressGauge(
						occupancy: facility.vacancy.occupancy,
						available: facility.vacancy.available,
						total: facility.totalSpaces,
						availabilityStatus: facility.availabilityStatus,
						isRefreshing: facilityDataMgr.isRefreshing
							&& facility.refreshStatus.staleness == .stale
					)
				}
				.padding(8)
				.background(
					.ultraThinMaterial,
					in: .circle
				)

				VStack(alignment: .leading) {
					HStack(alignment: .center, spacing: 4) {
						Text(facility.displayName.title)
							.multilineTextAlignment(.leading)
							.font(.headline)
							.fontWeight(.bold)
							.contentTransition(.identity)

						if facility.isFavourite {
							Image(systemName: "star.fill")
								.font(.caption2)
								.foregroundStyle(.tertiary)
								.contentTransition(.symbolEffect(.automatic))
						}
						Spacer()
					}
					Text(facility.displayName.subtitle)
						.font(.subheadline)
						.contentTransition(.identity)

					Spacer()

					HStack(alignment: .center, spacing: 4) {
						Text(facility.availabilityStatus.text)
							.font(.subheadline)
							.fontWeight(.semibold)
							.foregroundStyle(.secondary)

						Spacer()

						routeInfoLabel
					}
				}
				.padding(.vertical, 4)

				Spacer()
			}
			.onChange(of: facility.refreshStatus.staleness) {
				if facility.refreshStatus.staleness == .stale {
					Task {
						await facilityDataMgr.loadFacility(facility)
					}
				}
			}
			.padding(.vertical, 4)
			.opacity(facility.refreshStatus.staleness.displayOpacity)
			.animation(.smooth, value: facility.isFavourite)
			.animation(.smooth, value: facility.refreshStatus.staleness)
			.animation(.smooth, value: facility.route?.travelTime)
		}

		@ViewBuilder
		private var routeInfoLabel: some View {
			if locationMgr.isLocationAvailable {
				if let route = facility.route,
					route.isValid(
						from: locationMgr.currentLocation?.coordinate
					)
				{
					// Fresh route data
					routeDataView(route: route)
				} else if let route = facility.route,
					etaMgr.isCalculatingBatchETA
				{
					// Stale route while recalculating — show old values dimmed
					routeDataView(route: route)
						.opacity(0.6)
				} else if etaMgr.isCalculatingBatchETA {
					// No route data at all yet — first load
					ProgressView()
						.controlSize(.mini)
						.transition(.blurReplace)
				}
			}
		}

		@ViewBuilder
		private func routeDataView(route: ParkingFacility.RouteInfo)
			-> some View
		{
			HStack(spacing: 4) {
				Image(systemName: "car.fill")
					.font(.caption2)
				Text(etaMgr.formatETA(route.travelTime))
					.font(.caption)
					.fontWeight(.medium)
					.contentTransition(
						.numericText(value: route.travelTime)
					)
				Text("·")
					.font(.caption)
				Text(etaMgr.formatDistance(route.distance))
					.font(.caption)
					.contentTransition(
						.numericText(value: route.distance)
					)
			}
			.foregroundStyle(.secondary)
			.transition(.blurReplace)
		}
	}

}

// MARK: - Previews

#Preview("Grouped Facilities") {

	let favourites = ParkingFacility.sampleFavorites()
	let others = ParkingFacility.samples(count: 5)

	NavigationStack {
		FacilityList(
			groupedFacilities: [
				(title: "Pinned", facilities: favourites),
				(title: "Nearby", facilities: others),
			]
		)
		.navigationTitle("Metro Parking")
	}
	.previewEnvironment()
	.modelContainer(.preview())
}

#Preview("Single Section") {

	NavigationStack {
		FacilityList(
			groupedFacilities: [
				(title: nil, facilities: ParkingFacility.samples(count: 8))
			]
		)
		.navigationTitle("All Facilities")
	}
	.previewEnvironment()
	.modelContainer(.preview())
}

#Preview("Empty State") {

	NavigationStack {
		FacilityList(
			groupedFacilities: []
		)
		.navigationTitle("No Facilities")
	}
	.previewEnvironment()
	.modelContainer(.emptyPreview())
}
