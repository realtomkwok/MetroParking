//
//  ParkingListCardView.swift
//  MetroParking
//
//  Created by Tom Kwok on 26/6/2025.
//

import SwiftUI

struct ParkingListCardView: View {

  @Environment(\.modelContext) private var modelContext
  @ObservedObject private var locationManager = LocationManager.shared

  let facility: ParkingFacility
  let mapState: MapStateManager
  let sheetState: SheetStateManager

  private var actualDistance: Measurement<UnitLength> {
    let distance = locationManager.distanceToFacility(facility)
    return Measurement(value: distance, unit: UnitLength.kilometers)
  }

  // TODO: Update indicator

  var body: some View {
    Button {
      mapState.focusOnFacility(facility)
      sheetState.showFacilityDetail(facility)
    } label: {

      VStack(alignment: .center) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
              /// Facility name
              Text("\(facility.displayName)")
                .font(.title2)
                .fontDesign(.rounded)
                .multilineTextAlignment(.leading)
                .lineLimit(1)
                .foregroundStyle(.primary)

              /// is Pinned
              if facility.isFavourite {
                Label("pinned", systemImage: "star.fill")
                  .labelStyle(.iconOnly)
                  .font(.callout)
                  .foregroundStyle(.tertiary)
              }
            }

            HStack(alignment: .center) {
              Text("\(actualDistance.formatted()) away")
            }
            .font(.callout)
            .foregroundStyle(Color(.secondaryLabel))
          }

          Spacer(minLength: 32)

          /// Availability Status
          Text("\(facility.availabilityStatus.text)")
            .font(.subheadline)
            .fontWeight(.bold)
            .fontDesign(.rounded)
            .textCase(.uppercase)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(.white)
            .blendMode(.hardLight)
            .foregroundStyle(
              facility.availabilityStatus.color.adaptedTextColor()
            )
            .background(facility.availabilityStatus.color)
            .clipShape(RoundedRectangle(cornerRadius: .infinity))

        }

        Spacer(minLength: 32)

        /// Row #2
        HStack(alignment: .lastTextBaseline) {
          /// Updated time

          HStack(alignment: .center) {
            Text(
              "updated \(facility.lastUpdated.formatted(.relative(presentation: .numeric, unitsStyle: .narrow)))"
            )
          }
          .font(.callout)
          .foregroundStyle(.secondary)

          Spacer()

          /// Current available spaces
          VStack(alignment: .center, spacing: 0) {
            Text("\(facility.currentAvailableSpots)")
              .font(.largeTitle)
              .fontDesign(.rounded)
              .foregroundStyle(Color(.label))
              .contentTransition(
                .numericText(
                  value: Double(
                    facility.currentAvailableSpots
                  )
                )
              )
            Text("spaces")
              .foregroundStyle(.secondary)
          }
        }
      }
      .frame(minHeight: 64, maxHeight: 160)
      .padding(20)
      .background(.thickMaterial)
      .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
    .buttonStyle(.plain)
  }
}

#Preview(traits: .sizeThatFitsLayout) {
  ParkingListCardView(
    facility: PreviewHelper.pinnedFacilities().first!,
    mapState: MapStateManager(),
    sheetState: SheetStateManager()
  )
}
