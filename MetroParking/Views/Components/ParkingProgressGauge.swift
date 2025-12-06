//
//  ParkingProgressGauge.swift
//  MetroParking
//
//  Created by Tom Kwok on 29/6/2025.
//

import SwiftUI

struct ParkingProgressGauge: View {
	let vacancy: Int
	let displayVacancy: String
	let totalSpaces: Int
	let availabilityStatus: AvailabilityStatus

	private var occupancyProgress: Double {
		guard totalSpaces > 0 else { return 0 }

		let clampedVacancy = max(0, min(vacancy, totalSpaces))

		let currentOccupancy = totalSpaces - clampedVacancy

		let progress = Double(currentOccupancy) / Double(totalSpaces)

		// Clamp the final result to 0...1 range
		return max(0.0, min(1.0, progress))
	}

	var body: some View {
		Gauge(value: occupancyProgress, in: 0...1) {
		} currentValueLabel: {
			Text("\(displayVacancy)")
//				.frame(maxWidth: .infinity)
				.font(.title2)
				.fontWeight(.semibold)
				.contentTransition(.numericText(value: Double(vacancy)))
		} minimumValueLabel: {
			Text("\(totalSpaces)")
				.font(.system(size: 8))
				.fontWidth(.init(0.1))
				.foregroundStyle(.secondary)
		} maximumValueLabel: {
			Text("")
		}
		.gaugeStyle(.accessoryCircular)
		.tint(
			Gradient(colors: [
				AvailabilityStatus.available.color,
				AvailabilityStatus.almostFull.color,
				AvailabilityStatus.full.color,
			])
		)
	}
}

#Preview {
	let availableFacility = PreviewHelper.availableFacility()
	let almostFullFacility = PreviewHelper.almostFullFacility()
	let FullFacility = PreviewHelper.fullFacility()
	let noDataFacility = PreviewHelper.noDataFacility()

	HStack(spacing: 24) {
		ForEach(
			[
				availableFacility, almostFullFacility, FullFacility,
				noDataFacility,
			],
			id: \.facilityId
		) { facility in
			ParkingProgressGauge(
				vacancy: facility.currentVacancy,
				displayVacancy: facility.displayVacancy,
				totalSpaces: facility.totalSpaces,
				availabilityStatus: facility.availabilityStatus
			)
		}
	}

}
