//
//  ParkingProgressGauge.swift
//  MetroParking
//
//  Created by Tom Kwok on 29/6/2025.
//

import SwiftUI

struct ParkingProgressGauge: View {
	let availableSpaces: Int
	let totalSpaces: Int
	let availablityStatus: AvailabilityStatus
	
	let showLabel: Bool
	
	private var occupancyProgress: Double {
		guard totalSpaces > 0 else { return 0 }
		return Double(availableSpaces) / Double(totalSpaces)
	}
	
	var body: some View {
		Gauge(value: occupancyProgress, in: 0...1) {
		} currentValueLabel: {
			Text("\(availableSpaces)")
				.contentTransition(.numericText(value: Double(availableSpaces)))
		} minimumValueLabel: {
			EmptyView()
		} maximumValueLabel: {
			EmptyView()
		}
		.gaugeStyle(.accessoryCircular)
		.tint(Gradient(colors: [
			AvailabilityStatus.available.color,
			AvailabilityStatus.almostFull.color,
			AvailabilityStatus.full.color
		]))
	}
}




