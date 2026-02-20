//
//  FacilityList.swift
//  MetroParking
//
//  Created by Tom Kwok on 6/12/2025.
//

import Foundation
import SwiftData
import SwiftUI
import SwiftUIBackports

/// Future features: Live Activity/notification swipe actions (v0.5.0+)
struct FacilityList: View {
	var namespace: Namespace.ID
	let groupedFacilities:
		[(title: LocalizedStringResource?, facilities: [ParkingFacility])]

	@Binding var selectedFacility: ParkingFacility?
	@Environment(FacilityManager.self) private var facilityDataMgr

	// MARK: - Identifiable Section

	private struct FacilitySection: Identifiable {
		let id: String
		let title: LocalizedStringResource?
		let facilities: [ParkingFacility]

		init(title: LocalizedStringResource, facilities: [ParkingFacility]) {
			self.title = title
			self.facilities = facilities
			self.id = String(localized: title)
		}
	}

	private var sections: [FacilitySection] {
		groupedFacilities
			.filter { !$0.facilities.isEmpty }
			.map {
				FacilitySection(
					title: $0.title ?? "",
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
						ListRow(
							facility: facility,
							namespace: namespace,
							selectedFacility: $selectedFacility
						)
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
		.navigationDestination(item: $selectedFacility) { facility in
			FacilityDetailView(namespace: namespace, facility: facility)
				.navigationTransition(
					.zoom(sourceID: facility.facilityId, in: namespace)
				)
		}
	}
}

// MARK: - View Components
extension FacilityList {

	struct ListRow: View {
		let facility: ParkingFacility
		let namespace: Namespace.ID

		@Environment(\.modelContext) private var modelContext

		@Binding var selectedFacility: ParkingFacility?

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
			Button {
				selectedFacility = facility
			} label: {
				rowContent(facility: facility)
			}
			.buttonStyle(.glass)
			.accessibilityIdentifier("facility-row-\(facility.facilityId)")
			// TODO: add AccessibilityHint and AccessibilityLabel
			.listRowInsets(
				EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16)
			)
			.listRowBackground(Color.clear)
			.listRowSeparator(.hidden)
			.matchedTransitionSource(id: facility.facilityId, in: namespace)
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
	@Previewable @Namespace var namespace
	@Previewable @State var selectedFacility: ParkingFacility?

	let favourites = ParkingFacility.sampleFavorites()
	let others = ParkingFacility.samples(count: 5)

	NavigationStack {
		FacilityList(
			namespace: namespace,
			groupedFacilities: [
				(title: "Pinned", facilities: favourites),
				(title: "Nearby", facilities: others),
			],
			selectedFacility: $selectedFacility
		)
		.navigationTitle("Metro Parking")
	}
	.environment(FacilityManager.shared)
	.environment(LocationManager.shared)
	.environment(ETAManager.shared)
	.modelContainer(.preview())
}

#Preview("Single Section") {
	@Previewable @Namespace var namespace
	@Previewable @State var selectedFacility: ParkingFacility?

	NavigationStack {
		FacilityList(
			namespace: namespace,
			groupedFacilities: [
				(title: nil, facilities: ParkingFacility.samples(count: 8))
			],
			selectedFacility: $selectedFacility
		)
		.navigationTitle("All Facilities")
	}
	.environment(FacilityManager.shared)
	.environment(LocationManager.shared)
	.environment(ETAManager.shared)
	.modelContainer(.preview())
}

#Preview("Empty State") {
	@Previewable @Namespace var namespace
	@Previewable @State var selectedFacility: ParkingFacility?

	NavigationStack {
		FacilityList(
			namespace: namespace,
			groupedFacilities: [],
			selectedFacility: $selectedFacility
		)
		.navigationTitle("No Facilities")
	}
	.environment(FacilityManager.shared)
	.environment(LocationManager.shared)
	.environment(ETAManager.shared)
	.modelContainer(.emptyPreview())
}
