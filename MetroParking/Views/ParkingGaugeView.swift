//
//  ParkingGauge.swift
//  MetroParking
//
//  Created by Tom Kwok on 24/6/2025.
//

import SwiftUI

struct ParkingGauge: View {
  let facility: ParkingFacility
  let mapState: MapStateManager
  let sheetState: SheetStateManager

  private var occupancyProgress: Double {
    guard facility.totalSpaces > 0 else { return 0 }
    return Double(facility.currentOccupancy) / Double(facility.totalSpaces)
  }

  var body: some View {
    Button {
      mapState.focusOnFacility(facility)
      sheetState.showFacilityDetail(facility)
    } label: {
      VStack {
        VStack(spacing: -12) {
          ParkingProgressGauge(
            availableSpaces: Int(facility.currentAvailableSpots),
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
              .font(.caption)
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
            .lineLimit(2)
            .frame(maxWidth: .infinity)
          Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: 48)
      }
      .simultaneousGesture(
        TapGesture().onEnded { _ in
          mapState.focusOnFacility(facility)

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
    mapState: MapStateManager(),
    sheetState: SheetStateManager()
  )
}

#Preview("Small Facility - 🟡 Almost-full", traits: .sizeThatFitsLayout) {
  ParkingGauge(
    facility: PreviewHelper.almostFullFacility(),
    mapState: MapStateManager(),
    sheetState: SheetStateManager()
  )
}

#Preview("Large Facility - 🔴 Full", traits: .sizeThatFitsLayout) {
  ParkingGauge(
    facility: PreviewHelper.fullFacility(),
    mapState: MapStateManager(),
    sheetState: SheetStateManager()
  )
}
