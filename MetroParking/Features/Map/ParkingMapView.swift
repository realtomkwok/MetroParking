//
//  ParkingMapView.swift
//  MetroParking
//
//  Created by Tom Kwok on 13/9/2026.
//

import MapKit
import SwiftData
import SwiftUI

/// Full-screen map of all car parks. Selecting a pin opens its detail in the sheet.
struct ParkingMapView: View {
	@Bindable var model: MapSheetModel

	/// Lets `MapControlCluster` place this map's controls outside it.
	let scope: Namespace.ID

	// Sorted so annotation order is stable across store updates; otherwise
	// MapKit re-adds annotation views on every refresh write.
	@Query(sort: \ParkingFacility.facilityId)
	private var facilities: [ParkingFacility]

	/// Whether the camera is close enough in to read the vacancy counts.
	@State private var showsCounts = false

	var body: some View {
		let selectedId = model.selectedFacilityId

		Map(
			position: $model.camera,
			selection: $model.selectedFacilityId,
			scope: scope
		) {
			UserAnnotation()

			ForEach(facilities, id: \.facilityId) { facility in
				Annotation(
					facility.displayName.title,
					coordinate: facility.location.coordinate,
					anchor: .center
				) {
					FacilityAnnotation(
						status: facility.availabilityStatus,
						available: facility.vacancy.available,
						isSelected: facility.facilityId == selectedId,
						showsCount: showsCounts
					)
				}
				.tag(facility.facilityId)
			}
		}
		.mapStyle(
			.standard(
				elevation: .realistic,
				emphasis: .muted,
				pointsOfInterest: [.publicTransport]
			)
		)
		// Emptied deliberately: the controls are placed by `MapControlCluster`,
		// which can reach them through `scope`.
		.mapControls {}
		// Continuous so the counts appear mid-pinch rather than after it, but
		// only written on a threshold crossing: the annotations all rebuild.
		.onMapCameraChange(frequency: .continuous) { context in
			let shows = MapSheetModel.showsCounts(at: context.region)
			if shows != showsCounts { showsCounts = shows }
		}
		.accessibilityIdentifier("parking-map")
	}
}

/// Status-coloured map pin that expands to show the vacancy count, either
/// because it is selected or because the camera is close enough to read them all.
struct FacilityAnnotation: View {
	let status: AvailabilityStatus
	let available: Int
	let isSelected: Bool
	let showsCount: Bool

	/// Selection widens the border; the count alone doesn't, so a selected pin
	/// still reads as selected among a mapful of expanded ones.
	private var isExpanded: Bool { isSelected || showsCount }

	private var countColor: Color {
		switch status {
		case .almostFull: .black
		case .noData: .primary
		case .available, .full: .white
		}
	}

	var body: some View {
		ZStack {
			Circle()
				.fill(status.fill.gradient)
				.overlay {
					Circle()
						.strokeBorder(.background, lineWidth: isSelected ? 3 : 2)
				}
				.shadow(color: .black.opacity(0.25), radius: 2, y: 1)

			if isExpanded {
				Text(status == .noData ? "–" : "\(available)")
					.font(.subheadline)
					.fontWeight(.bold)
					.monospacedDigit()
					.foregroundStyle(countColor)
					.contentTransition(.numericText(value: Double(available)))
					.transition(.scale.combined(with: .opacity))
			}
		}
		.frame(width: isExpanded ? 44 : 18, height: isExpanded ? 44 : 18)
		// Enlarge the tap target without changing the drawn size.
		.padding(8)
		.contentShape(.circle)
		.animation(.spring(duration: 0.3), value: isExpanded)
		.animation(.smooth, value: available)
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(Text(status.text))
		.accessibilityValue(Text(verbatim: "\(available)"))
		.accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
	}
}

// MARK: - Previews

#Preview("Annotations") {
	HStack(spacing: 16) {
		ForEach(AvailabilityStatus.allCases, id: \.self) { status in
			VStack {
				FacilityAnnotation(
					status: status,
					available: 42,
					isSelected: true,
					showsCount: true
				)
				FacilityAnnotation(
					status: status,
					available: 42,
					isSelected: false,
					showsCount: true
				)
				FacilityAnnotation(
					status: status,
					available: 42,
					isSelected: false,
					showsCount: false
				)
			}
		}
	}
	.padding()
	.background(.gray.opacity(0.3))
}
#Preview {
	@Previewable @Namespace var scope

	ParkingMapView(model: MapSheetModel(), scope: scope)
		.modelContainer(.preview())
}
