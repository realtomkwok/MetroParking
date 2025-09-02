//
//  ParkingGauge.swift
//  MetroParking
//
//  Created by Tom Kwok on 24/6/2025.
//

import SwiftUI

struct ParkingGauge: View {
	let facility: ParkingFacility
	let appState = AppStateManager.shared

	private var occupancyProgress: Double {
		guard facility.totalSpaces > 0 else { return 0 }
		return max(0, facility.occupancy)
	}

	var body: some View {
		Button {
			appState.selectFacility(facility)
		} label: {
			VStack {
				VStack(spacing: -12) {
					ParkingProgressGauge(
						availableSpaces: facility.currentAvailableSpots,
						displayAvailableSpots: facility.displayAvailableSpots,
						totalSpaces: facility.totalSpaces,
						availabilityStatus: facility.availabilityStatus,
					)
					.scaleEffect(1.5)

					if facility.availabilityStatus == .full {
						Text("full")
							.textCase(.uppercase)
							.font(.caption)
							.offset(y: 8)
					} else {
						Text("spaces")
							.textCase(.uppercase)
							.font(.caption2)
							.offset(y: 8)
					}
				}
				.padding(24)
				.background(.thinMaterial)
				.clipShape(Circle())

				VStack(alignment: .center, spacing: 0) {
					Text(facility.displayName)
						.font(.callout)
						.multilineTextAlignment(.center)
				}
				.frame(maxWidth: .infinity, maxHeight: 48)
			}
			.simultaneousGesture(
				TapGesture().onEnded { _ in
					let impact = UIImpactFeedbackGenerator(style: .medium)
					impact.impactOccurred()
				}
			)
		}
		.buttonStyle(.plain)
		.frame(maxWidth: 112)
	}

}

#Preview("Medium Facility - 🟢 Available", traits: .sizeThatFitsLayout) {
	ParkingGauge(
		facility: PreviewHelper.availableFacility(),
	)
}

#Preview("Small Facility - 🟡 Almost-full", traits: .sizeThatFitsLayout) {
	ParkingGauge(
		facility: PreviewHelper.almostFullFacility(),
	)
}

#Preview("Large Facility - 🔴 Full", traits: .sizeThatFitsLayout) {
	ParkingGauge(
		facility: PreviewHelper.fullFacility(),
	)
}
