//
//  FacilityList.swift
//  MetroParking
//
//  Created by Tom Kwok on 6/12/2025.
//

import Foundation
import SwiftData
import SwiftUI

@available(iOS 26.0, *)
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

	private func openInMaps(facility: ParkingFacility) {
		// TODO: Implement opening in Maps
		//		guard let coordinate = facility.coordinate else { return }
		//		let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
		//		mapItem.name = facility.displayName
		//		mapItem.openInMaps(launchOptions: [
		//			MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
		//		])
	}

	private func enableLiveActivity(for facility: ParkingFacility) {
		// TODO: Implement live activity
		print("Enable live activity for \(facility.displayName)")
	}

	var body: some View {
		List {
			ForEach(sections) { section in
				Section {
					ForEach(section.facilities, id: \.facilityId) { facility in
						facilityRow(for: facility)
					}
				} header: {
					sectionHeader(title: section.title)
				}
			}
		}
//		.contentTransition(.identity)
//		.animation(.smooth(duration: 0.4), value: sections.map { $0.id })
//		.animation(
//			.smooth(duration: 0.4),
//			value: sections.flatMap { $0.facilities.map(\.facilityId) }
//		)
		.listStyle(.plain)
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
						.fontWeight(.medium)
						.foregroundStyle(.foreground)

					if facility.isFavourite {
						Image(systemName: "star.fill")
							.font(.caption2)
							.foregroundStyle(.tertiary)
					}
				}
				Text(facility.displayName.subtitle)
					.font(.headline)
					.foregroundStyle(.secondary)

				Spacer()

				Text(facility.availabilityStatus.text)
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}

			Spacer()
			VStack(alignment: .center) {
				ParkingProgressGauge(
					vacancy: facility.currentVacancy,
					displayVacancy: facility.displayVacancy,
					totalSpaces: facility.totalSpaces,
					availabilityStatus: facility.availabilityStatus
				)
				.scaleEffect(1.2)
			}
			.padding(12)
			.background(Circle().fill(.thinMaterial).opacity(0.2))
		}
		.contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
		.padding()
	}

	@ViewBuilder
	private func facilityRow(for facility: ParkingFacility) -> some View {
		let statusColor = facility.availabilityStatus.color
		let cornerRadius: CGFloat = 24
		let borderOpacity: CGFloat = 0.1
		let tintOpacity: CGFloat = 0.04
		
		Button {
			selectedFacility = facility
		} label: {
			FacilityRowView(facility: facility)
		}
		.overlay(
			RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
				.stroke(statusColor.opacity(borderOpacity), lineWidth: 1)
		)
		.glassEffect(
			.clear
				.tint(statusColor.opacity(tintOpacity))
				.interactive(),
			in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
		)
		.listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
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
	}
	
	@ViewBuilder
	private func favouriteSwipeAction(for facility: ParkingFacility) -> some View {
		Button {
			withAnimation {
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
	private func trailingSwipeActions(for facility: ParkingFacility) -> some View {
		Button {
			// TODO: Enable live activity/notifications
			enableLiveActivity(for: facility)
		} label: {
			Label("Live", systemImage: "bell.badge")
		}
		.tint(.orange)
		
		Button {
			// TODO: Open in Maps app
			openInMaps(facility: facility)
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

	let container = PreviewHelper.previewContainer(withSamplePins: true)
	let context = container.mainContext

	// Fetch all facilities from the preview container
	let allFacilities =
		(try? context.fetch(FetchDescriptor<ParkingFacility>())) ?? []

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
	.modelContainer(container)
}
