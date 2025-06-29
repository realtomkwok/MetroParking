//
//  ParkingListCardView.swift
//  MetroParking
//
//  Created by Tom Kwok on 26/6/2025.
//

import SwiftUI

struct ParkingListCardView: View {

  @Environment(\.modelContext) private var modelContext

  let facility: ParkingFacility
  let mapState: MapStateManager
  let sheetState: SheetStateManager

  // TODO: Replace value with real distance
  let distance = Measurement(value: 5.2, unit: UnitLength.kilometers)

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
              Text("\(facility.displayName)")
                .font(.title2)
                .fontDesign(.rounded)
                .multilineTextAlignment(.leading)
                .lineLimit(1)
                .foregroundStyle(.primary)

              if facility.isFavourite {
                Label("Pinned", systemImage: "pin.circle")
                  .labelStyle(.iconOnly)
                  .font(.callout)
                  .foregroundStyle(.secondary)
              }
            }

            HStack(alignment: .center) {
              Text("\(distance.formatted()) away")
            }
            .font(.callout)
            .foregroundStyle(Color(.secondaryLabel))
          }

          Spacer(minLength: 32)

          Text("\(facility.availablityStatus.text)")
            .font(.subheadline)
            .fontWeight(.semibold)
            .fontDesign(.rounded)
            .textCase(.uppercase)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(.white)
            .blendMode(.hardLight)
            .foregroundStyle(.fill)
            .background(facility.availablityStatus.color)
            .clipShape(RoundedRectangle(cornerRadius: 999))

        }

        Spacer(minLength: 32)

        HStack(alignment: .lastTextBaseline) {
          HStack(alignment: .center) {
            Text(
              "updated \(facility.lastUpdated.formatted(.relative(presentation: .numeric, unitsStyle: .narrow)))"
            )
          }
          .font(.callout)
          .foregroundStyle(.secondary)

          Spacer()

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
      .foregroundStyle(.foreground)
      .background(.thickMaterial)
      .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
    .buttonStyle(.plain)
  }
}

#Preview(traits: .sizeThatFitsLayout) {
  ParkingListCardView(
    facility: PreviewHelper.almostFullFacility(),
    mapState: MapStateManager(),
    sheetState: SheetStateManager()
  )
}
