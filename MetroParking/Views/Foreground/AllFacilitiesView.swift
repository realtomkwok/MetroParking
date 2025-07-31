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

  /// Sorting state
  @State private var selectedSortOption: FacilitySortOption = .distance
  @State private var sortAscending: Bool = true

  /// Search
  @State private var searchText: String = ""

  private var searchPredicate: Predicate<ParkingFacility>? {
    guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
      return nil
    }

    let trimmedSearch = searchText.trimmingCharacters(in: .whitespaces)
    return #Predicate<ParkingFacility> { facility in
      facility.name.localizedStandardContains(trimmedSearch)
        || facility.suburb.localizedStandardContains(trimmedSearch)
    }
  }

  @Query private var allFacilities: [ParkingFacility]

  /// Animation namespace
  @Namespace private var sortTransition

  var body: some View {

    LazyVStack(
      alignment: .leading,
      spacing: 16,
      //			pinnedViews: .sectionHeaders
    ) {
      Section {
        /// Single dynamic facility list
        FacilityListView(
          sortOption: selectedSortOption,
          ascending: sortAscending,
          searchPredicate: searchPredicate,
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
        VStack {
          SortingToolbar
          SearchBar(text: $searchText)
            .frame(maxWidth: .infinity)
        }
        .safeAreaPadding(.horizontal)
      }
    }

  }

  /// Sorting toolbar
  private var SortingToolbar: some View {
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
  }

  /// Search bar
  struct SearchBar: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = "Search facilities or suburbs..."

    func makeUIView(context: Context) -> UISearchBar {
      let searchBar = UISearchBar()
      searchBar.delegate = context.coordinator
      searchBar.placeholder = placeholder
      searchBar.searchBarStyle = .minimal
      searchBar.enablesReturnKeyAutomatically = false
      searchBar.isTranslucent = true
      return searchBar
    }

    func updateUIView(_ uiView: UISearchBar, context: Context) {
      uiView.text = text
    }

    func makeCoordinator() -> Coordinator {
      Coordinator(self)
    }

    class Coordinator: NSObject, UISearchBarDelegate {
      let parent: SearchBar

      init(_ parent: SearchBar) {
        self.parent = parent
      }

      func searchBar(
        _ searchBar: UISearchBar,
        textDidChange searchText: String
      ) {
        parent.text = searchText
      }

      func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
      }
    }
  }
}

struct FacilityListView: View {
  let sortOption: FacilitySortOption
  let ascending: Bool
  let searchPredicate: Predicate<ParkingFacility>?
  let mapState: MapStateManager
  let sheetState: SheetStateManager
  let sortTransition: Namespace.ID

  var body: some View {
    if usesComputedSorting {
      ComputedSortedFacilities(
        sortOption: sortOption,
        ascending: ascending,
        searchPredicate: searchPredicate,
        mapState: mapState,
        sheetState: sheetState,
        sortTransition: sortTransition
      )
    } else {
      DatabaseSortedFacilities(
        filter: searchPredicate,
        sort: sortDescriptors,
        mapState: mapState,
        sheetState: sheetState,
        sortTransition: sortTransition
      )
    }
  }

  private var usesComputedSorting: Bool {
    sortOption == .distance || sortOption == .availability
  }

  private var sortDescriptors: [SortDescriptor<ParkingFacility>] {
    let order: SortOrder = ascending ? .forward : .reverse

    switch sortOption {
    case .name:
      return [SortDescriptor(\.name, order: order)]
    case .suburb:
      return [
        SortDescriptor(\.suburb, order: order),
        SortDescriptor(\.name, order: .forward),
      ]
    case .totalSpaces:
      return [
        SortDescriptor(\.totalSpaces, order: order),
        SortDescriptor(\.name, order: .forward),
      ]
    default:
      return [SortDescriptor(\.name, order: .forward)]
    }
  }
}

struct DatabaseSortedFacilities: View {
  let mapState: MapStateManager
  let sheetState: SheetStateManager
  let sortTransition: Namespace.ID

  @Query private var facilities: [ParkingFacility]

  init(
    filter: Predicate<ParkingFacility>? = nil,
    sort: [SortDescriptor<ParkingFacility>],
    mapState: MapStateManager,
    sheetState: SheetStateManager,
    sortTransition: Namespace.ID
  ) {
    self.mapState = mapState
    self.sheetState = sheetState
    self.sortTransition = sortTransition

    /// Sort descriptors
    if let filter = filter {
      self._facilities = Query(
        filter: filter,
        sort: sort,
        animation: .snappy
      )
    } else {
      self._facilities = Query(sort: sort, animation: .snappy)
    }
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
  let searchPredicate: Predicate<ParkingFacility>?
  let mapState: MapStateManager
  let sheetState: SheetStateManager
  let sortTransition: Namespace.ID

  @Query private var allFacilities: [ParkingFacility]
  @ObservedObject private var locationManager = LocationManager.shared

  init(
    sortOption: FacilitySortOption,
    ascending: Bool,
    searchPredicate: Predicate<ParkingFacility>?,
    mapState: MapStateManager,
    sheetState: SheetStateManager,
    sortTransition: Namespace.ID
  ) {
    self.sortOption = sortOption
    self.ascending = ascending
    self.searchPredicate = searchPredicate
    self.mapState = mapState
    self.sheetState = sheetState
    self.sortTransition = sortTransition

    if let predicate = searchPredicate {
      self._allFacilities = Query(filter: predicate, animation: .snappy)
    } else {
      self._allFacilities = Query()
    }
  }

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
