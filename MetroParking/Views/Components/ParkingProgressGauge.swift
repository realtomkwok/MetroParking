//
//  ParkingProgressGauge.swift
//  MetroParking
//
//  Created by Tom Kwok on 29/6/2025.
//

import SwiftUI

struct ParkingProgressGauge: View {
  let availableSpaces: Int
  let displayAvailableSpots: String
  let totalSpaces: Int
  let availabilityStatus: AvailabilityStatus

  private var occupancyProgress: Double {
    guard totalSpaces > 0 else { return 0 }

    let clampedAvailableSpaces = max(0, min(availableSpaces, totalSpaces))

    let currentOccupancy = totalSpaces - clampedAvailableSpaces

    let progress = Double(currentOccupancy) / Double(totalSpaces)

    // Clamp the final result to 0...1 range
    return max(0.0, min(1.0, progress))
  }

  var body: some View {
    Gauge(value: occupancyProgress, in: 0...1) {
    } currentValueLabel: {
      Text("\(displayAvailableSpots)")
        .contentTransition(.numericText(value: Double(availableSpaces)))
    } minimumValueLabel: {
      EmptyView()
    } maximumValueLabel: {
      EmptyView()
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
        availableSpaces: Int(facility.currentAvailableSpots),
        displayAvailableSpots: facility.displayAvailableSpots,
        totalSpaces: facility.totalSpaces,
        availabilityStatus: facility.availabilityStatus,
      )
    }
  }

}
