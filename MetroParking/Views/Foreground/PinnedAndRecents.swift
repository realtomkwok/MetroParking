//
//  PinnedAndRecents.swift
//  MetroParking
//
//  Created by Tom Kwok on 5/7/2025.
//

import SwiftData
import SwiftUI

struct PinnedAndRecents: View {
  let mapState: MapStateManager
  let sheetState: SheetStateManager

  /// For pinned facilities
  @Query(
    filter: #Predicate<ParkingFacility> { $0.isFavourite == true },
    animation: .snappy
  )
  private var pinnedFacilities: [ParkingFacility]
  /// For recently visited facilities
  @Query(
    filter: #Predicate<ParkingFacility> { $0.lastVisited != nil },
    sort: [SortDescriptor(\ParkingFacility.lastVisited, order: .reverse)],
    animation: .snappy
  )
  private var recentlyVisitedFacilities: [ParkingFacility]

  var body: some View {
    ScrollView(.vertical, showsIndicators: false) {
      VStack(alignment: .leading, spacing: 24) {
        PinnedFacility()
        RecentFacility()
      }
    }
  }

  @ViewBuilder
  func PinnedFacility() -> some View {

    VStack(alignment: .leading) {
      Text("Pinned")
        .font(.headline)
        .foregroundStyle(.primary)
        .padding(.horizontal)

      VStack {
        if pinnedFacilities.isEmpty {
          VStack(alignment: .center, spacing: 8) {
            Image(systemName: "questionmark.circle")
              .font(.largeTitle)
            Text("No pinned parking yet")
          }
          .font(.body)
          .foregroundStyle(.secondary)
          .frame(maxHeight: .infinity)
        } else {
          // TODO: Resize each gauge to match the one with the widest text
          // https://developer.apple.com/videos/play/wwdc2022/10056/
          ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .center, spacing: 0) {
              ForEach(pinnedFacilities, id: \.facilityId) {
                facility in
                ParkingGauge(
                  facility: facility,
                  mapState: mapState,
                  sheetState: sheetState
                )
              }
              .safeAreaPadding(.leading)
            }
          }
        }
      }
      .frame(maxWidth: .infinity, minHeight: 120)

    }
    .frame(maxWidth: .infinity)
  }

  @ViewBuilder
  func RecentFacility() -> some View {
    VStack(alignment: .leading) {
      Text("Recents")
        .font(.headline)
        .padding(.horizontal)

      LazyVStack(alignment: .leading) {
        ForEach(recentlyVisitedFacilities, id: \.facilityId) {
          facility in
          ParkingListCardView(
            facility: facility,
            mapState: mapState,
            sheetState: sheetState
          )
        }
      }
      .padding(.horizontal)

    }
  }
}

#Preview {
  PinnedAndRecents(mapState: MapStateManager(), sheetState: SheetStateManager())
    .modelContainer(PreviewHelper.previewContainer(withSamplePins: false))
}
