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
	var nameSpace: Namespace.ID
	let groupedFacilities: [(title: String?, facilities: [ParkingFacility])]

	@Binding var selectedFacility: ParkingFacility?

	@Environment(\.modelContext) private var modelContext
	@Environment(FacilityManager.self) private var facilityDataMgr

	// MARK: - Identifiable Section

	private struct FacilitySection: Identifiable {
		let id: String
		let title: String?
		let facilities: [ParkingFacility]

		init(title: String?, facilities: [ParkingFacility]) {
			self.title = title
			self.facilities = facilities
			self.id = title ?? "untitled"
		}
	}

	private var sections: [FacilitySection] {
		groupedFacilities
			.filter { !$0.facilities.isEmpty }
			.map { FacilitySection(title: $0.title, facilities: $0.facilities) }
	}

	private var sectionStructureHash: Int {
		var hasher = Hasher()
		for (title, facilities) in groupedFacilities {
			hasher.combine(title)
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
						ListRow(for: facility)
					}
				} header: {
					SectionHeader(title: section.title)
				}
			}
		}
		.accessibilityIdentifier("facility-list")
		.listStyle(.plain)
		// Animate when section structure changes OR when facilities move between sections
		.animation(
			.smooth(),
			value: sectionStructureHash
		)
		.navigationDestination(item: $selectedFacility) { facility in
			FacilityDetailView(namespace: nameSpace, facility: facility)
				.navigationTransition(
					.zoom(sourceID: facility.facilityId, in: nameSpace)
				)
		}
	}
}

// MARK: - View Components
extension FacilityList {

	@ViewBuilder
	private func ListRow(for facility: ParkingFacility) -> some View {
		Button {
			selectedFacility = facility
		} label: {
			FacilityRowView(
				facility: facility,
				isRefreshing: facilityDataMgr
					.isRefreshing
			)
		}
		.buttonStyle(.glass)
		.accessibilityIdentifier("facility-row-\(facility.facilityId)")
		// TODO: add AccessibilityHint and AccessibilityLabel
		.listRowInsets(
			EdgeInsets(top: 8, leading: 8, bottom: 4, trailing: 8)
		)
		.listRowBackground(Color.clear)
		.listRowSeparator(.hidden)
		.matchedTransitionSource(id: facility.facilityId, in: nameSpace)
		.swipeActions(edge: .leading) {
			leadingSwipeAction(for: facility)
		}
	}

	@ViewBuilder
	func FacilityRowView(facility: ParkingFacility, isRefreshing: Bool)
		-> some View
	{

		let staleness = facility.refreshStatus.staleness

		HStack(alignment: .center, spacing: 12) {
			VStack(alignment: .center) {
				ParkingProgressGauge(
					occupancy: facility.vacancy.occupancy,
					available: facility.vacancy.available,
					total: facility.totalSpaces,
					availabilityStatus: facility.availabilityStatus,
					isRefreshing: isRefreshing
					&& staleness == .stale
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
							.transition(.scale.combined(with: .opacity))
					}
					Spacer()
				}
				Text(facility.displayName.subtitle)
					.font(.subheadline)
					.contentTransition(.identity)

				Spacer()

				HStack(alignment: .firstTextBaseline, spacing: 4) {
					Text(facility.availabilityStatus.text)
						.font(.subheadline)
						.fontWeight(.semibold)
						.foregroundStyle(.secondary)
				}
			}
			.padding(.vertical, 4)

			Spacer()
		}
		.padding(.vertical, 4)
		.opacity(facility.refreshStatus.staleness.displayOpacity)
		.animation(.smooth, value: facility.isFavourite)
		.animation(.smooth, value: staleness)
	}

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
				facility.isFavourite ? "Unpin" : "Pin",
				systemImage: facility.isFavourite ? "star.slash" : "star.fill"
			)
			.labelStyle(.iconOnly)
		}
		.tint(facility.isFavourite ? .red : .yellow)
	}

	@ViewBuilder
	private func SectionHeader(title: String?) -> some View {
		if let title = title, !title.isEmpty {
			Text(title)
				.font(.headline)
				.foregroundStyle(.primary)
				.transition(.blurReplace.combined(with: .move(edge: .top)))
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
			nameSpace: namespace,
			groupedFacilities: [
				(title: "Pinned", facilities: favourites),
				(title: "Nearby", facilities: others)
			],
			selectedFacility: $selectedFacility
		)
		.navigationTitle("Facilities")
	}
	.environment(FacilityManager.shared)
	.modelContainer(.preview())
}

#Preview("Single Section") {
	@Previewable @Namespace var namespace
	@Previewable @State var selectedFacility: ParkingFacility?

	NavigationStack {
		FacilityList(
			nameSpace: namespace,
			groupedFacilities: [
				(title: nil, facilities: ParkingFacility.samples(count: 8))
			],
			selectedFacility: $selectedFacility
		)
		.navigationTitle("All Facilities")
	}
	.environment(FacilityManager.shared)
	.modelContainer(.preview())
}

#Preview("Empty State") {
	@Previewable @Namespace var namespace
	@Previewable @State var selectedFacility: ParkingFacility?

	NavigationStack {
		FacilityList(
			nameSpace: namespace,
			groupedFacilities: [],
			selectedFacility: $selectedFacility
		)
		.navigationTitle("No Facilities")
	}
	.environment(FacilityManager.shared)
	.modelContainer(.emptyPreview())
}
