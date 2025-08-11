//
//  ContentView.swift
//  MetroParking
//
//  Created by Tom Kwok on 18/5/2025.
//

import MapKit
import SwiftData
import SwiftUI

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
          sheetState: sheetStateManager,
          locationState: locationManager
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

enum ScreenView: String, CaseIterable, Identifiable {
  case pinned
  case all

  var id: String { self.rawValue }

  var displayName: String {
    switch self {
    case .pinned: "Pins & Recents"
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
    mapState: MapStateManager,
    sheetState: SheetStateManager,
  ) -> some View {
    VStack(spacing: 8) {
      Spacer()
      switch self {
      case .pinned:

        PinnedAndRecents(
          mapState: mapState,
          sheetState: sheetState
        )

      case .all:
        AllFacilitiesView(
          mapState: mapState,
          sheetState: sheetState
        )
      }
    }
  }
}

struct ForegroundView: View {
  @ObservedObject var mapState: MapStateManager
  @ObservedObject var sheetState: SheetStateManager
  @ObservedObject var locationState: LocationManager

  @State private var selectedScreen: ScreenView = .pinned
  @State private var showSettingsSheet: Bool = false

  /// Tracking scroll position and dynamically change the background of Topbar
  @State private var isScrolled = false
  @State private var initialPosition: CGFloat?

  /// Refresh manager
  @ObservedObject private var refreshManager = FacilityRefreshManager.shared

  /// SwiftData Queries
  @Query private var allFacilities: [ParkingFacility]

  var body: some View {
    ScrollView {
      /// Track scroll position with GeometryReader
      GeometryReader { proxy in
        Color.clear
          .onChange(of: proxy.frame(in: .named("scroll")).minY) {
            _,
            newValue in
            // Store initial position on first read
            if initialPosition == nil {
              initialPosition = newValue
            }

            // Show background after scrolling 30 points from initial position
            if let initial = initialPosition {
              isScrolled = newValue < (initial)
            }
          }
      }
      .frame(height: 0)

      LazyVStack(alignment: .leading, pinnedViews: .sectionHeaders) {
        Section {
          selectedScreen.destinationView(
            mapState: mapState,
            sheetState: sheetState,
          )
        } header: {
          TopBar(showBackground: isScrolled) {
            /// Menu (select views)
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
                HStack(alignment: .center) {
                  Text(selectedScreen.displayName)
                    .font(.title)
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)
                    .tracking(-0.4)
                  Image(systemName: "chevron.down")
                    .font(.callout)
                  Spacer()
                }
                .foregroundStyle(.primary)
              }

            }
          } trailingContent: {
            /// Topbar trailing buttons
            HStack(spacing: 16) {

              Button {
                Task {
                  await refreshManager
                    .performInitialOccupancyLoad()
                }
              } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                  .fontWeight(.semibold)
                  .symbolEffect(
                    .rotate.clockwise.byLayer,
                    options: .repeat(.continuous),
                    isActive: refreshManager.isRefreshing
                  )
                  .frame(width: 24, height: 24)
                  .foregroundStyle(.secondary)
              }
              .frame(width: 36, height: 36)
              .disabled(refreshManager.isRefreshing)
              .buttonBorderShape(.circle)
              .buttonStyle(.bordered)
              .foregroundStyle(.primary)
              .controlSize(.regular)

              Button {
                showSettingsSheet = true
              } label: {
                Label("More", systemImage: "ellipsis")
                  .fontWeight(.semibold)
                  .symbolEffect(
                    .wiggle.byLayer,
                    options: .nonRepeating,
                    isActive: showSettingsSheet
                  )
                  .frame(width: 24, height: 24)
                  .foregroundStyle(.secondary)
              }
              .frame(width: 36, height: 36)
              .buttonBorderShape(.circle)
              .buttonStyle(.bordered)
              .foregroundStyle(.primary)
              .controlSize(.regular)
            }
          }
        }
      }
      .sheet(
        isPresented: $sheetState.showingFacilityDetail,
        onDismiss: {
          mapState.showAllFacilities()
        },
        content: {
          if let facility = sheetState.selectedFacilityForDetail {
            ParkingDetailView(
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
	.fontDesign(.rounded)
    .coordinateSpace(name: "scroll")
    .sheet(isPresented: $showSettingsSheet) {
      SettingsView()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.thickMaterial)
    }
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
          case .notDetermined, .restricted, .denied:
            showLocationPermissionAlert = true
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
            showLocationPermissionAlert = true
          }
        } label: {
          VStack(alignment: .center, spacing: 8) {
            if locationState.isRefreshing {
              ProgressView()
            } else {
              Label(
                "Current Location",
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
        .sheet(isPresented: $showLocationPermissionAlert) {
          PermissionView()
            .presentationDetents([.medium])
            .presentationBackgroundInteraction(.disabled)

        }
        Spacer()
      }
    }
  }
}

#Preview("Normal App State") {
  ContentView()
    .modelContainer(PreviewHelper.previewContainer(withSamplePins: false))
}

#Preview("Foreground Sheet") {
  ForegroundView(
    mapState: MapStateManager(),
    sheetState: SheetStateManager(),
    locationState: LocationManager()
  )
  .modelContainer(PreviewHelper.previewContainer(withSamplePins: false))
}
