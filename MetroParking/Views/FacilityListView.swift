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

	var body: some View {
		List {
			ForEach(sections) { section in
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
		.listStyle(.plain)
		// Animate when section structure changes OR when facilities move between sections
		.animation(
			.snappy(),
			value: sections.map { $0.facilities.map(\.persistentModelID) }
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
		if #available(iOS 26.0, *) {
			Button {
				selectedFacility = facility
			} label: {
				FacilityRowView(facility: facility)
			}
			.listRowInsets(
				EdgeInsets(top: 8, leading: 8, bottom: 4, trailing: 8)
			)
			.listRowBackground(Color.clear)
			.listRowSeparator(.hidden)
			.matchedTransitionSource(id: facility.facilityId, in: nameSpace)
			.buttonStyle(.glass)
			.buttonBorderShape(.capsule)
			.swipeActions(edge: .leading) {
				leadingSwipeAction(for: facility)
			}
			.swipeActions(edge: .trailing, allowsFullSwipe: false) {
				trailingSwipeActions(for: facility)
			}
		} else {
			// Fallback on earlier versions
		}
	}

	@ViewBuilder
	func FacilityRowView(facility: ParkingFacility) -> some View {
		HStack(alignment: .center, spacing: 12) {
			VStack(alignment: .center) {
				ParkingProgressGauge(
					occupancy: facility.vacancy.occupancy,
					available: facility.vacancy.available,
					displayVacancy: facility.vacancy.displayText,
					total: facility.totalSpaces,
					availabilityStatus: facility.availabilityStatus
				)
			}
			.padding(8)
			.background(
				.ultraThinMaterial, in: .circle
			)

			VStack(alignment: .leading) {
				HStack(alignment: .center, spacing: 4) {
					Text(facility.displayName.title)
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

				Text(facility.availabilityStatus.text)
					.font(.subheadline)
					.fontWeight(.semibold)
					.foregroundStyle(.secondary)
			}
			.padding(.vertical, 4)

			Spacer()
		}
		.opacity(facility.availabilityStatus == .noData ? 0.6 : 1)
	}

	@ViewBuilder
	private func leadingSwipeAction(for facility: ParkingFacility)
		-> some View
	{
		Button(role: facility.isFavourite ? .destructive : nil) {
			withAnimation(.snappy) {
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
	private func SectionHeader(title: String?) -> some View {
		if let title = title, !title.isEmpty {
			Text(title)
				.font(.headline)
				.foregroundStyle(.primary)
				.transition(.blurReplace.combined(with: .move(edge: .top)))
		}
	}
}

// MARK: - Helper functions

extension FacilityList {
	private func enableLiveActivity(for facility: ParkingFacility) {
		// TODO: Implement live activity
		print("Enable live activity for \(facility.displayName)")
	}
}
