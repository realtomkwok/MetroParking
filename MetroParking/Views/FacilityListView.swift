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

struct FacilityList: View {
	var nameSpace: Namespace.ID
	let groupedFacilities: [(title: String?, facilities: [ParkingFacility])]

	@State private var selectedFacility: ParkingFacility?

	@Environment(\.modelContext) private var modelContext

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

	private func enableLiveActivity(for facility: ParkingFacility) {
		// TODO: Implement live activity
		print("Enable live activity for \(facility.displayName)")
	}

	var body: some View {
		List {
			ForEach(sections) { section in
				Section {
					ForEach(section.facilities, id: \.persistentModelID) {
						facility in
						facilityRow(for: facility)
					}
				} header: {
					sectionHeader(title: section.title)
				}
				.containerShape(.rect(cornerRadius: 24, style: .circular))
			}
		}
		.listStyle(.plain)
		// Animate when section structure changes OR when facilities move between sections
		.animation(
			.smooth,
			value: sections.map { $0.facilities.map(\.persistentModelID) }
		)
		.navigationDestination(item: $selectedFacility) { facility in
			FacilityDetailView(namespace: nameSpace, facility: facility)
				.navigationTransition(
					.zoom(sourceID: facility.facilityId, in: nameSpace)
				)
		}
	}

	// MARK: - View Components

	@ViewBuilder
	func FacilityRowView(facility: ParkingFacility) -> some View {


			HStack(alignment: .center) {
				VStack(alignment: .leading) {
					HStack(alignment: .center, spacing: 4) {
						Text(facility.displayName.title)
							.font(.title3)
							.fontWeight(.bold)

						if facility.isFavourite {
							Image(systemName: "star.fill")
								.font(.caption2)
								.foregroundStyle(.tertiary)
						}
					}
					Text(facility.displayName.subtitle)
						.font(.headline)

					Spacer()

					Text(facility.availabilityStatus.text)
						.font(.subheadline)
						.fontWeight(.semibold)
						.foregroundStyle(.secondary)
				}

				Spacer()
				VStack(alignment: .center) {
					ParkingProgressGauge(
						occupancy: facility.vacancy.occupancy,
						available: facility.vacancy.available,
						displayVacancy: facility.vacancy.displayText,
						total: facility.totalSpaces,
						availabilityStatus: facility.availabilityStatus
					)
					.scaleEffect(1.2)
				}
				.padding(12)
				.background(Circle().fill(.thinMaterial).opacity(0.4))
			}
			.contentShape(.rect(cornerRadius: 24, style: .circular))
			.opacity(facility.availabilityStatus == .noData ? 0.6 : 1)
			.padding()

	}

	@ViewBuilder
	private func facilityRow(for facility: ParkingFacility) -> some View {
		if #available(iOS 26.0, *) {
			Button {
				selectedFacility = facility
			} label: {
				FacilityRowView(facility: facility)
			}
			.glassEffect(
				.clear
					.interactive(),
				in: .rect(corners: .concentric, isUniform: true)
			)
			.listRowInsets(
				EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16)
			)
			.listRowBackground(Color.clear)
			.listRowSeparator(.hidden)
			.id(facility.facilityId)
			.matchedTransitionSource(id: facility.facilityId, in: nameSpace)
			.buttonStyle(.plain)
			.swipeActions(edge: .leading) {
				favouriteSwipeAction(for: facility)
			}
			.swipeActions(edge: .trailing) {
				trailingSwipeActions(for: facility)
			}
		} else {
			// Fallback on earlier versions
		}
	}

	@ViewBuilder
	private func favouriteSwipeAction(for facility: ParkingFacility)
		-> some View
	{
		Button {
			withAnimation(.snappy) {
				facility.isFavourite.toggle()
				// Save the context to persist the change
				try? modelContext.save()
			}
		} label: {
			Label(
				facility.isFavourite ? "Unpin" : "Pin",
				systemImage: facility.isFavourite ? "star.fill" : "star"
			)
		}
		.tint(.yellow)
	}

	@ViewBuilder
	private func trailingSwipeActions(for facility: ParkingFacility)
		-> some View
	{
		Button {
			// TODO: Enable live activity/notifications
			enableLiveActivity(for: facility)
		} label: {
			Label("Live", systemImage: "bell.badge")
		}
		.tint(.orange)

		Button {
			// TODO: Open in Maps app
			//			openInMaps(facility: facility)
		} label: {
			Label("Go", systemImage: "arrow.trianglehead.turn.up.right.diamond")
		}
		.tint(.blue)
	}

	@ViewBuilder
	private func sectionHeader(title: String?) -> some View {
		if let title = title, !title.isEmpty {
			Text(title)
				.font(.headline)
				.foregroundStyle(.primary)
				.transition(.blurReplace.combined(with: .move(edge: .top)))
		}
	}
}

#Preview {
	@Previewable @Namespace var namespace

	let allFacilities = ParkingFacility.samples()

	// Create grouped facilities: Pinned and All Others
	let pinnedFacilities = allFacilities.filter { $0.isFavourite }
	let unpinnedFacilities = allFacilities.filter { !$0.isFavourite }

	let groupedFacilities: [(title: String?, facilities: [ParkingFacility])] = [
		(title: "Pinned", facilities: pinnedFacilities),
		(title: "More Parking", facilities: unpinnedFacilities),
	]

	return NavigationStack {
		if #available(iOS 26.0, *) {
			FacilityList(
				nameSpace: namespace,
				groupedFacilities: groupedFacilities
			)
			.navigationTitle("Parking Facilities")
			.navigationBarTitleDisplayMode(.inline)
		} else {
			// Fallback on earlier versions
		}
	}
	.modelContainer(.preview())
}
