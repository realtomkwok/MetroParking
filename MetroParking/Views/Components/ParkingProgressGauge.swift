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
	var isRefreshing: Bool = false

	private var isAvailable: Bool

	init(
		occupancy: Double,
		available: Int,
		total: Int,
		availabilityStatus: AvailabilityStatus,
		isRefreshing: Bool = false
	) {
		self.occupancy = occupancy
		self.available = available
		self.displayVacancy = String(self.available)
		self.total = total
		self.availabilityStatus = availabilityStatus
		self.isAvailable = availabilityStatus != .noData
		self.isRefreshing = isRefreshing
	}

	var body: some View {
		Gauge(value: occupancy, in: 0...1) {
		} currentValueLabel: {
			Text("\(displayVacancy)")
				.font(.title2)
				.fontWeight(.semibold)
				.foregroundStyle(isAvailable ? .primary : .tertiary)
		} minimumValueLabel: {
			Text("\(total)")
				.font(.caption2)
				.fontWidth(.init(0.1))
				.foregroundStyle(.secondary)
		} maximumValueLabel: {
			Text("")
		}
		.gaugeStyle(.accessoryCircular)
		.tint(AvailabilityStatus.gradient)
		.contentTransition(.numericText(value: Double(available)))
		.breathingAnimation(isRefreshing, minOpacity: 0.5, duration: 0.8)
	}
}

#Preview {
	let availableFacility = ParkingFacility.sample(status: .available)
	let almostFullFacility = ParkingFacility.sample(status: .almostFull)
	let fullFacility = ParkingFacility.sample(status: .full)
	let noDataFacility = ParkingFacility.sample(status: .noData)

	HStack(spacing: 24) {
		ParkingProgressGauge(
			occupancy: availableFacility.vacancy.occupancy,
			available: availableFacility.vacancy.available,
			total: availableFacility.vacancy.total,
			availabilityStatus: availableFacility.availabilityStatus
		)

		ParkingProgressGauge(
			occupancy: almostFullFacility.vacancy.occupancy,
			available: almostFullFacility.vacancy.available,
			total: almostFullFacility.vacancy.total,
			availabilityStatus: almostFullFacility.availabilityStatus
		)

		ParkingProgressGauge(
			occupancy: fullFacility.vacancy.occupancy,
			available: fullFacility.vacancy.available,
			total: fullFacility.vacancy.total,
			availabilityStatus: fullFacility.availabilityStatus
		)

		ParkingProgressGauge(
			occupancy: noDataFacility.vacancy.occupancy,
			available: noDataFacility.vacancy.available,
			total: noDataFacility.vacancy.total,
			availabilityStatus: noDataFacility.availabilityStatus
		)
	}
}
