//
//  AllFacilitiesView.swift
//  MetroParking
//
//  Created by Tom Kwok on 5/7/2025.
//

import SwiftData
import SwiftUI

enum FacilitySortOption: String, CaseIterable, Identifiable {
  case distance = "distance"
  case availability = "availability"
  case name = "name"
  case suburb = "suburb"
  case totalSpaces = "totalSpaces"

  var id: String { self.rawValue }

  var displayName: String {
    switch self {
    case .distance: return "Distance"
    case .availability: return "Availability"
    case .name: return "Name"
    case .suburb: return "Suburb"
    case .totalSpaces: return "Total Spaces"
    }
  }

  var systemImage: String {
    switch self {
    case .distance: return "location"
    case .availability: return "gauge.with.needle"
    case .name: return "textformat.abc"
    case .suburb: return "map"
    case .totalSpaces: return "square.grid.2x2"
    }
  }
}

struct AllFacilitiesView: View {
  let mapState: MapStateManager
  let sheetState: SheetStateManager

  @ObservedObject private var locationManager = LocationManager.shared

  // Sorting state
  @State private var selectedSortOption: FacilitySortOption = .distance
  @State private var sortAscending: Bool = true

  @Query private var allFacilities: [ParkingFacility]

  // Animation namespace
  @Namespace private var sortTransition

  var body: some View {

    LazyVStack(
      alignment: .leading,
      spacing: 16,
      pinnedViews: .sectionHeaders
    ) {
      Section {
        /// Single dynamic facility list
        QuerySortedFacilities(
          sortOption: selectedSortOption,
          ascending: sortAscending,
          mapState: mapState,
          sheetState: sheetState,
          sortTransition: sortTransition
        )
        .padding(.horizontal)
        .animation(
          .spring(response: 0.6, dampingFraction: 0.8),
          value: selectedSortOption
        )
        .animation(
          .spring(response: 0.6, dampingFraction: 0.8),
          value: sortAscending
        )
      } header: {
        sortingToolbar
      }

    }

  }

  /// Sorting toolbar
  private var sortingToolbar: some View {
    ScrollView(.horizontal) {
      LazyHStack(alignment: .center, spacing: 8) {
        ForEach(FacilitySortOption.allCases, id: \.id) { option in
          Button {
            withAnimation(.snappy) {
              if selectedSortOption == option {
                sortAscending.toggle()
              } else {
                selectedSortOption = option
                sortAscending = true
              }
            }
          } label: {
            Label(
              option.displayName,
              systemImage: option.systemImage
            )

            /// Show sort direction
            if selectedSortOption == option {
              Image(
                systemName: sortAscending
                  ? "chevron.up" : "chevron.down"
              )
              .font(.caption)
              .foregroundStyle(.secondary)
            }
          }
          .font(.body)
          .fontWeight(.medium)
          .buttonBorderShape(.capsule)
          .buttonStyle(.bordered)
          .controlSize(.regular)
          .foregroundStyle(
            selectedSortOption == option ? .blue : .secondary
          )
          .tint(selectedSortOption == option ? .accentColor : .none)
        }
      }
    }
    .scrollIndicators(.hidden)
    .safeAreaPadding(.horizontal)
  }
}

struct QuerySortedFacilities: View {
  let sortOption: FacilitySortOption
  let ascending: Bool
  let mapState: MapStateManager
  let sheetState: SheetStateManager
  let sortTransition: Namespace.ID

  var body: some View {
    Group {
      switch sortOption {
      case .distance, .availability:
        ComputedSortedFacilities(
          sortOption: sortOption,
          ascending: ascending,
          mapState: mapState,
          sheetState: sheetState,
          sortTransition: sortTransition
        )
      case .name:
        FacilityQueryView(
          sort: [
            SortDescriptor(
              \ParkingFacility.name,
              order: ascending ? .forward : .reverse
            )
          ],
          mapState: mapState,
          sheetState: sheetState,
          sortTransition: sortTransition
        )
      case .suburb:
        FacilityQueryView(
          sort: [
            SortDescriptor(
              \ParkingFacility.name,
              order: ascending ? .forward : .reverse
            ),
            SortDescriptor(
              \ParkingFacility.suburb,
              order: ascending ? .forward : .reverse
            ),
          ],
          mapState: mapState,
          sheetState: sheetState,
          sortTransition: sortTransition
        )
      case .totalSpaces:
        FacilityQueryView(
          sort: [
            SortDescriptor(
              \ParkingFacility.totalSpaces,
              order: ascending ? .forward : .reverse
            ),
            SortDescriptor(\ParkingFacility.name, order: .forward),
          ],
          mapState: mapState,
          sheetState: sheetState,
          sortTransition: sortTransition
        )
      }
    }
  }
}

struct FacilityQueryView: View {
  let mapState: MapStateManager
  let sheetState: SheetStateManager
  let sortTransition: Namespace.ID

  @Query private var facilities: [ParkingFacility]

  /// Sort only
  init(
    sort: [SortDescriptor<ParkingFacility>],
    mapState: MapStateManager,
    sheetState: SheetStateManager,
    sortTransition: Namespace.ID
  ) {
    self.mapState = mapState
    self.sheetState = sheetState
    self.sortTransition = sortTransition

    self._facilities = Query(sort: sort)
  }

  /// Sort and filter
  init(
    filter: Predicate<ParkingFacility>,
    sort: [SortDescriptor<ParkingFacility>],
    mapState: MapStateManager,
    sheetState: SheetStateManager,
    sortTransition: Namespace.ID
  ) {
    self.mapState = mapState
    self.sheetState = sheetState
    self.sortTransition = sortTransition
    self._facilities = Query(filter: filter, sort: sort)
  }

  var body: some View {
    ForEach(facilities, id: \.facilityId) { facility in
      ParkingListCardView(
        facility: facility,
        mapState: mapState,
        sheetState: sheetState
      )
      .matchedGeometryEffect(id: facility.facilityId, in: sortTransition)
    }
  }
}

/// Computed sorting list for dynamic data
struct ComputedSortedFacilities: View {
  let sortOption: FacilitySortOption
  let ascending: Bool
  let mapState: MapStateManager
  let sheetState: SheetStateManager
  let sortTransition: Namespace.ID

  @Query private var allFacilities: [ParkingFacility]
  @ObservedObject private var locationManager = LocationManager.shared

  var body: some View {
    ForEach(sortedFacilities, id: \.facilityId) { facility in
      ParkingListCardView(
        facility: facility,
        mapState: mapState,
        sheetState: sheetState
      )
      .matchedGeometryEffect(id: facility.facilityId, in: sortTransition)
    }
  }

  private var sortedFacilities: [ParkingFacility] {
    let sorted = allFacilities.sorted { facility1, facility2 in
      switch sortOption {
      case .distance:
        return compareDistance(facility1, facility2)
      case .availability:
        return compareAvailability(facility1, facility2)
      default:
        return facility1.name < facility2.name
      }
    }

    return ascending ? sorted : sorted.reversed()
  }

  private func compareDistance(
    _ facility1: ParkingFacility,
    _ facility2: ParkingFacility
  ) -> Bool {
    let distance1 = locationManager.distanceToFacility(facility1)
    let distance2 = locationManager.distanceToFacility(facility2)

    return distance1 < distance2
  }

  private func compareAvailability(
    _ facility1: ParkingFacility,
    _ facility2: ParkingFacility
  ) -> Bool {
    let percentage1 = facility1.availabilityPercentage
    let percentage2 = facility2.availabilityPercentage

    // Handle invalid data (-1 values) - put them at the end
    if percentage1 < 0 && percentage2 < 0 {
      return facility1.name < facility2.name  // Fallback to name sorting
    }
    if percentage1 < 0 { return false }  // facility1 goes to end
    if percentage2 < 0 { return true }  // facility2 goes to end

    // Sort by available spots - MORE available spots first
    return percentage1 > percentage2
  }
}
