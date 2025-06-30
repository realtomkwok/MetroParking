//
//  ContentView.swift
//  MetroParking
//
//  Created by Tom Kwok on 18/5/2025.
//

import MapKit
import SwiftData
import SwiftUI

enum ScreenView: String, CaseIterable, Identifiable {
  case pinned
  case all

  var id: String { self.rawValue }

  var displayName: String {
    switch self {
    case .pinned: "Pinned & Recents"
    case .all: "All Parking"
    }
  }

  var iconName: String {
    switch self {
    case .pinned: "star"
    case .all: "parkingsign.square"
    }
  }

  @ViewBuilder
  func destinationView(
    all: [ParkingFacility],
    pinned: [ParkingFacility],
    recents: [ParkingFacility],
    mapState: MapStateManager,
    sheetState: SheetStateManager
  ) -> some View {
    switch self {
    case .pinned:
      MainView(
        pinnedFacilities: pinned,
        recentFacilities: recents,
        mapState: mapState,
        sheetState: sheetState
      )
    case .all:
      AllFacilitiesView(
        facilities: all,
        mapState: mapState,
        sheetState: sheetState
      )
    }
  }
}

struct ContentView: View {
  @Namespace var namespace

  /// Load SwiftData environment
  @Environment(\.modelContext) private var modelContext

  /// Data manager
  @StateObject private var dataManager = FacilityDataManager()
  /// Refresh manager
  @ObservedObject private var refreshManager = FacilityRefreshManager.shared
  /// Map State manager
  @StateObject private var mapStateManager = MapStateManager()
  @StateObject private var sheetStateManager = SheetStateManager()

  /// UI State
  @State private var presentSheet = true
  @State private var hasInitialised = false

  var body: some View {
    ZStack {
      BackgroundView(
        mapState: mapStateManager,
        sheetState: sheetStateManager
      )
      .sheet(isPresented: $presentSheet) {

        ForegroundView(
          mapState: mapStateManager,
          sheetState: sheetStateManager
        )
        .presentationCornerRadius(24)
        .presentationBackground(.thinMaterial)
        .presentationDetents(
          [.fraction(0.3), .medium, .large],
          selection: $sheetStateManager.currentDentent
        )
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled)
        .presentationContentInteraction(.resizes)
        .interactiveDismissDisabled()
      }
      .task {
        guard !hasInitialised else { return }
        hasInitialised = true
        await initialisedApp()
      }
      .onDisappear {
        refreshManager.stopAutoRefresh()
      }
      .fontDesign(.rounded)
    }
  }

  private func initialisedApp() async {
    /// Connect the data manager to SwiftData
    dataManager.setModelContext(modelContext)
    /// Connect the refresh manager to SwiftData
    refreshManager.setModelContext(modelContext)

    /// Load static facilities
    await dataManager.loadStaticFacilitiesIfNeeded()

    /// Start loading occupancy data
    await refreshManager.performInitialOccupancyLoad()

    refreshManager.startAutoRefresh()
  }
}

struct ForegroundView: View {
  @ObservedObject var mapState: MapStateManager
  @ObservedObject var sheetState: SheetStateManager

  @State private var selectedScreen: ScreenView = .pinned
  @State private var showMoreMenu: Bool = false

  /// Refresh manager
  @ObservedObject private var refreshManager = FacilityRefreshManager.shared

  /// SwiftData Queries
  @Query private var allFacilities: [ParkingFacility]
  // For pinned facilities
  @Query(
    filter: #Predicate<ParkingFacility> { $0.isFavourite == true },
    animation: .snappy
  )
  private var pinnedFacilities: [ParkingFacility]
  // For recently visited facilities
  @Query(
    filter: #Predicate<ParkingFacility> { $0.lastVisited != nil },
    sort: [SortDescriptor(\ParkingFacility.lastVisited, order: .reverse)],
    animation: .snappy
  )
  private var recentlyVisitedFacilities: [ParkingFacility]

  var body: some View {
    VStack(alignment: .leading) {
      Topbar()
      selectedScreen.destinationView(
        all: allFacilities,
        pinned: pinnedFacilities,
        recents: recentlyVisitedFacilities,
        mapState: mapState,
        sheetState: sheetState
      )
    }
    .padding(.horizontal)
    .sheet(
      isPresented: $sheetState.showingFacilityDetail,
      onDismiss: {
        mapState.showAllFacilities()
      },
      content: {
        if let facility = sheetState.selectedFacilityForDetail {
          FacilityDetailView(
            facility: facility,
            onDismiss: {
              sheetState.hideFacilityDetail()
              mapState.showAllFacilities()
            }
          )
          .presentationDetents(
            [.fraction(0.2), .medium, .large], selection: $sheetState.currentDentent
          )
          .presentationBackground(.regularMaterial)
          .presentationDragIndicator(.visible)
          //					.presentationCornerRadius(24)
          .presentationBackgroundInteraction(.enabled)
        }
      }
    )
  }

  @ViewBuilder
  func Topbar() -> some View {
    HStack(alignment: .center) {
      Menu {
        ForEach(ScreenView.allCases) { screen in
          Button(action: {
            selectedScreen = screen
          }) {
            HStack {
              Text(screen.displayName)
              Image(systemName: screen.iconName)
            }
          }
        }
      } label: {
        HStack {
          Text(selectedScreen.displayName)
            .font(.title)
            .fontWeight(.medium)
            .tracking(-0.4)
          Image(systemName: "chevron.down")
            .font(.callout)
            .fontWeight(.medium)
        }
      }

      Spacer()

      HStack(alignment: .center, spacing: 8) {
        Button {
          Task {
            await refreshManager.performInitialOccupancyLoad()
          }
        } label: {
          Label("Refresh", systemImage: "arrow.clockwise")
            .fontWeight(.semibold)
            .symbolEffect(
              .rotate.clockwise.byLayer,
              options: .repeat(.continuous),
              isActive: refreshManager.isRefreshing
            )
            .frame(minWidth: 20, minHeight: 20)
            .foregroundStyle(.secondary)
        }
        .disabled(refreshManager.isRefreshing)
        .buttonBorderShape(.circle)
        .buttonStyle(.bordered)
        .foregroundStyle(.primary)

        Button {
          // TODO: Show menu for more info
          /*@START_MENU_TOKEN@*//*@PLACEHOLDER=Action@*/
          /*@END_MENU_TOKEN@*/
        } label: {
          Label("More", systemImage: "ellipsis")
            .fontWeight(.semibold)
            .symbolEffect(
              .wiggle.byLayer,
              options: .nonRepeating,
              isActive: showMoreMenu
            )
            .frame(minWidth: 20, minHeight: 20)
        }
        .buttonBorderShape(.circle)
        .buttonStyle(.bordered)
        .foregroundStyle(.primary)
      }
      // To align with other components
      .offset(x: 4)
    }
    .frame(height: 56)
    .padding(.top)
    .foregroundStyle(.foreground)
  }
}

struct BackgroundView: View {
  @ObservedObject var mapState: MapStateManager
  @ObservedObject var sheetState: SheetStateManager
  @Query var allFacilities: [ParkingFacility]

  var body: some View {
    VStack {
      Map(
        position: $mapState.cameraPosition
      ) {
        ForEach(allFacilities, id: \.facilityId) { facility in

          Annotation(
            facility.displayName,
            coordinate: CLLocationCoordinate2D(
              latitude: facility.latitude,
              longitude: facility.longitude
            )
          ) {
            ParkingMapAnnotation(
              facility: facility,
              isSelected: mapState.selectedFacility?.facilityId
                == facility.facilityId
            )
            .onTapGesture {
              mapState.focusOnFacility(facility)
              sheetState.showFacilityDetail(facility)
            }
          }

        }

      }
      .mapStyle(
        .standard(
          elevation: .realistic,
          emphasis: .muted,
          pointsOfInterest: [.publicTransport],
          showsTraffic: false
        )
      )
      .mapControls {
        MapScaleView()
        MapUserLocationButton()
        MapCompass()
      }
    }
  }
}

struct MainView: View {
  let pinnedFacilities: [ParkingFacility]
  let recentFacilities: [ParkingFacility]
  let mapState: MapStateManager
  let sheetState: SheetStateManager

  var body: some View {
    ScrollView(.vertical, showsIndicators: false) {
      VStack(alignment: .leading, spacing: 24) {
        PinnedFacility()
        RecentFacility()
      }
      .foregroundStyle(.foreground)
    }
  }

  @ViewBuilder
  func PinnedFacility() -> some View {

    Text("Pinned")
      .font(.headline)
      .foregroundStyle(.primary)

    HStack(alignment: .center) {
      if pinnedFacilities.isEmpty {
        // TODO: Reword
        Text("No pinned parking yet")
      } else {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(alignment: .center, spacing: 0) {
            ForEach(pinnedFacilities, id: \.facilityId) {
              facility in
              ParkingGauge(
                facility: facility,
                mapState: mapState,
                sheetState: sheetState
              )
            }
            .padding(.horizontal, 8)
          }
        }
      }
    }
    .frame(maxWidth: .infinity, minHeight: 64)
  }

  @ViewBuilder
  func RecentFacility() -> some View {
    Text("Recents")
      .font(.headline)
      .foregroundStyle(.primary)

    LazyVStack(alignment: .leading) {
      ForEach(recentFacilities, id: \.facilityId) { facility in
        ParkingListCardView(
          facility: facility,
          mapState: mapState,
          sheetState: sheetState
        )
      }
    }
  }
}

struct AllFacilitiesView: View {
  let facilities: [ParkingFacility]
  let mapState: MapStateManager
  let sheetState: SheetStateManager

  var body: some View {
    ScrollView(.vertical, showsIndicators: false) {
      LazyVStack(alignment: .listRowSeparatorLeading) {
        ForEach(facilities, id: \.facilityId) { facility in
          ParkingListCardView(
            facility: facility,
            mapState: mapState,
            sheetState: sheetState
          )
        }
      }
    }
  }
}

#Preview("Normal App State") {
  ContentView()
    .modelContainer(PreviewHelper.previewContainer(withSamplePins: true))
}
