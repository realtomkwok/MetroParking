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

	// Sorted so annotation order is stable across store updates; otherwise
	// MapKit re-adds annotation views on every refresh write.
	@Query(sort: \ParkingFacility.facilityId)
	private var facilities: [ParkingFacility]

	private var selection: Binding<String?> {
		Binding(
			get: { model.selectedFacilityId },
			set: { model.handleMapSelection($0) }
		)
	}

	var body: some View {
		let selectedId = model.selectedFacilityId

		Map(position: $model.camera, selection: selection) {
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
						isSelected: facility.facilityId == selectedId
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
		.mapControls {
			MapUserLocationButton()
			MapCompass()
			MapScaleView()
		}
		.accessibilityIdentifier("parking-map")
	}
}

/// Status-coloured map pin that expands to show the vacancy count when selected.
struct FacilityAnnotation: View {
	let status: AvailabilityStatus
	let available: Int
	let isSelected: Bool

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

			if isSelected {
				Text(status == .noData ? "–" : "\(available)")
					.font(.subheadline)
					.fontWeight(.bold)
					.monospacedDigit()
					.foregroundStyle(countColor)
					.contentTransition(.numericText(value: Double(available)))
					.transition(.scale.combined(with: .opacity))
			}
		}
		.frame(width: isSelected ? 44 : 18, height: isSelected ? 44 : 18)
		// Enlarge the tap target without changing the drawn size.
		.padding(8)
		.contentShape(.circle)
		.animation(.spring(duration: 0.3), value: isSelected)
		.animation(.smooth, value: available)
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(Text(status.text))
		.accessibilityValue(Text(verbatim: "\(available)"))
		.accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
	}
}

#Preview("Annotations") {
	HStack(spacing: 16) {
		ForEach(AvailabilityStatus.allCases, id: \.self) { status in
			VStack {
				FacilityAnnotation(status: status, available: 42, isSelected: true)
				FacilityAnnotation(status: status, available: 42, isSelected: false)
			}
		}
	}
	.padding()
	.background(.gray.opacity(0.3))
}
