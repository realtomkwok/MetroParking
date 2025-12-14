//
//  ParkingProgressGauge.swift
//  MetroParking
//
//  Created by Tom Kwok on 29/6/2025.
//

import SwiftUI

struct ParkingProgressGauge: View {
	let occupancy: Double
	let available: Int
	let displayVacancy: String
	let total: Int
	let availabilityStatus: AvailabilityStatus

	var body: some View {
		Gauge(value: occupancy, in: 0...1) {
		} currentValueLabel: {
			Text("\(displayVacancy)")
				.font(.title2)
				.fontWeight(.semibold)
		} minimumValueLabel: {
			Text("\(total)")
				.font(.system(size: 8))
				.fontWidth(.init(0.1))
				.foregroundStyle(.secondary)
		} maximumValueLabel: {
			Text("")
		}
		.gaugeStyle(.accessoryCircular)
		.tint(
			Gradient(colors: [
				AvailabilityStatus.available.fill,
				AvailabilityStatus.almostFull.fill,
				AvailabilityStatus.full.fill,
			])
		)
		.contentTransition(.numericText(value: Double(available)))
	}
}

#Preview {
	let availableFacility = ParkingFacility.sample(status: .available)
	let almostFullFacility = ParkingFacility.sample(status: .almostFull)
	let FullFacility = ParkingFacility.sample(status: .full)
	let noDataFacility = ParkingFacility.sample(status : .noData)

	HStack(spacing: 24) {
		ForEach(
			[
				availableFacility, almostFullFacility, FullFacility,
				noDataFacility,
			],
			id: \.facilityId
		) { facility in
			ParkingProgressGauge(
				occupancy: facility.vacancy.occupancy,
				available: facility.vacancy.available,
				displayVacancy: facility.vacancy.displayText,
				total: facility.vacancy.total,
				availabilityStatus: facility.availabilityStatus
			)
		}
	}

}
