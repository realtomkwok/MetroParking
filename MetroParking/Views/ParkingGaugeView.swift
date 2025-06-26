//
//  ParkingGauge.swift
//  MetroParking
//
//  Created by Tom Kwok on 24/6/2025.
//

import SwiftUI

struct ParkingGauge: View {
	let facility: ParkingFacility
	
	private var occupancyProgress: Double {
		guard facility.totalSpaces > 0 else { return 0 }
		return Double(facility.currentOccupancy) / Double(facility.totalSpaces)
	}
	
	private var availablityStatus: AvailabilityStatus {
		let available = facility.currentAvailableSpots
		let total = facility.totalSpaces
		
		if available == 0 {
			return .full
		} else if available < total / 10 {
			return .almostFull
		} else {
			return .available
		}
	}
	
    var body: some View {
		VStack(spacing: 24) {
			VStack(spacing: -8) {
				Gauge(value: occupancyProgress, in: 0...1) {
				} currentValueLabel: {
					if availablityStatus == .full {
						Text("Full")
							.textCase(.uppercase)
					} else {
						Text("\(facility.currentOccupancy)")
					}
					
				} minimumValueLabel: {
					EmptyView()
				} maximumValueLabel: {
					EmptyView()
				}
				.gaugeStyle(.accessoryCircular)
				.tint(Gradient(colors: [AvailabilityStatus.available.color, AvailabilityStatus.almostFull.color, AvailabilityStatus.full.color]))
//				.scaleEffect(1.6)
				Text("spaces")
					.textCase(.uppercase)
					.font(.caption2)
			}
			.padding(16)
			.background(.ultraThinMaterial)
			.clipShape(Circle())
			.scaleEffect(1.2)
			
			Text(facility.displayName)
				.font(.callout)
				.multilineTextAlignment(.center)
				.lineLimit(2)
		}
		.padding(16)
		.frame(maxWidth: 160, maxHeight: 192)
    }
}

#Preview("Medium Facility - 🟢 Available", traits: .sizeThatFitsLayout) {
	ParkingGauge(facility: PreviewHelper.availableFacility())
}

#Preview("Small Facility - 🟡 Almost-full", traits: .sizeThatFitsLayout) {
	ParkingGauge(facility: PreviewHelper.almostFullFacility())
}

#Preview("Large Facility - 🔴 Full", traits: .sizeThatFitsLayout) {
	ParkingGauge(facility: PreviewHelper.fullFacility())
}
