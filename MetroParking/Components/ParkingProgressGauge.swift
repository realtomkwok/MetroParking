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
  let availabilityStatus: AvailabilityStatus

  private var occupancyProgress: Double {

    guard totalSpaces > 0 else { return 0 }
    let currentOccupancy = totalSpaces - availableSpaces
    return Double(currentOccupancy) / Double(totalSpaces)
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
        totalSpaces: facility.totalSpaces,
        availabilityStatus: facility.availabilityStatus,
      )
    }
  }

}
