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
  /// Location Manager
  @ObservedObject private var locationManager = LocationManager.shared

  /// Map State manager
  @StateObject private var mapStateManager = MapStateManager()
  /// Sheet manager
  @StateObject private var sheetStateManager = SheetStateManager()

  /// UI State
  @State private var presentSheet = true
  @State private var hasInitialised = false

  var body: some View {
    ZStack {
      BackgroundView(
        mapState: mapStateManager,
        sheetState: sheetStateManager,
        locationState: locationManager
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
          selection: $sheetStateManager.currentDetent
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
            [.fraction(0.2), .medium, .large],
            selection: $sheetState.currentDetent
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
      /// Menu (select views)
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

      /// Topbar trailing buttons
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
  @ObservedObject var locationState: LocationManager

  @Query var allFacilities: [ParkingFacility]
  @State private var showLocationPermissionAlert = false
  @State private var showLocationSettingsAlert = false

  var body: some View {
    VStack {
      Map(
        position: $mapState.cameraPosition
      ) {
        UserAnnotation()

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
        MapCompass()
      }
    }
    .overlay(alignment: .trailing) {
      VStack {
        Button {
          switch locationState.authorisationStatus {
          case .notDetermined:
            showLocationPermissionAlert = true
          case .restricted, .denied:
            showLocationSettingsAlert = true
          case .authorizedAlways, .authorizedWhenInUse:

            let newRegion =
              locationState.getNearestFacilitiesRegion(
                facilities: allFacilities,
                count: 5,
                paddingFactor: 1
              )

            withAnimation(.snappy(duration: 1.5)) {
              mapState.cameraPosition = .region(newRegion)
            }

          @unknown default:
            locationState.requestLocationPermission()
          }
        } label: {
          VStack(alignment: .center) {
            if locationState.isRefreshing {
              ProgressView()
            } else {
              Label(
                "Show my current location",
                systemImage: locationState.isLocationAvailable
                  ? "location.fill" : "location"
              )
              .font(.headline)
              .frame(width: 40, height: 40)
              .background(.regularMaterial, in: Circle())
              .padding(.trailing)
              .contentTransition(
                .symbolEffect(.replace, options: .default)
              )
              .labelStyle(.iconOnly)
            }
          }
        }

        Spacer()
      }

    }

    .alert(
      "Enable Location Access",
      isPresented: $showLocationPermissionAlert
    ) {
      Button("Allow Location") {
        LocationManager.shared.requestLocationPermission()
      }
      Button("Not Now", role: .cancel) {}
    } message: {
      Text(
        "MetroParking uses your location to find nearby parking facilities and show accurate distances. This helps you find the best parking options."
      )
    }
    .alert(
      "Location Access Needed",
      isPresented: $showLocationSettingsAlert
    ) {
      Button("Open Settings") {
        if let settingsURL = URL(
          string: UIApplication.openSettingsURLString
        ) {
          UIApplication.shared.open(settingsURL)
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "Location access was previously denied. To find nearby parking, please enable location access in Settings → MetroParking → Location."
      )
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
      VStack(alignment: .leading) {
        PinnedFacility()
        RecentFacility()
          .padding(.top)
      }
    }
  }

  @ViewBuilder
  func PinnedFacility() -> some View {

    VStack(alignment: .leading) {
      Text("Pinned")
        .font(.headline)
        .foregroundStyle(.primary)
    }

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
    VStack(alignment: .leading) {
      Text("Recents")
        .font(.headline)

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
