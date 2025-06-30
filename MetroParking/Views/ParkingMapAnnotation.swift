//
//  ParkingMapAnnotation.swift
//  MetroParking
//
//  Created by Tom Kwok on 27/6/2025.
//

import SwiftUI

struct ParkingMapAnnotation: View {
  let facility: ParkingFacility
  let isSelected: Bool

  var body: some View {
    VStack(spacing: 4) {
      ZStack {
        RoundedRectangle(cornerRadius: .infinity)
          .fill(facility.availabilityStatus.color.gradient)
          .frame(
            width: isSelected ? 56 : 16,
            height: isSelected ? 56 : 16
          )
          .overlay(
            Circle()
              .stroke(.regularMaterial, lineWidth: isSelected ? 4 : 3)
          )

        if isSelected {
          VStack(alignment: .center) {
            Text("\(facility.currentAvailableSpots)")
              .font(.subheadline)
              .multilineTextAlignment(.center)
              .foregroundStyle(
                facility.availablityStatus.color
                  .adpatedTextColor()
              )
              .fontWeight(.semibold)
              .contentTransition(
                .numericText(
                  value: Double(
                    facility.currentAvailableSpots
                  )
                )
              )

          }

        }
      }
    }
    .scaleEffect(isSelected ? 1.2 : 1)
    .animation(.spring(response: 0.3), value: isSelected)
    .padding(.bottom, isSelected ? 8 : 0)
  }
}

#Preview {

  VStack(alignment: .center, spacing: 24) {
    ParkingMapAnnotation(
      facility: PreviewHelper.fullFacility(),
      isSelected: true
    )
    ParkingMapAnnotation(
      facility: PreviewHelper.fullFacility(),
      isSelected: false
    )

    ParkingMapAnnotation(
      facility: PreviewHelper.almostFullFacility(),
      isSelected: true
    )
    ParkingMapAnnotation(
      facility: PreviewHelper.almostFullFacility(),
      isSelected: false
    )

    ParkingMapAnnotation(
      facility: PreviewHelper.availableFacility(),
      isSelected: true
    )
    ParkingMapAnnotation(
      facility: PreviewHelper.availableFacility(),
      isSelected: false
    )

    ParkingMapAnnotation(
      facility: PreviewHelper.noDataFacility(),
      isSelected: true
    )
  }
}
