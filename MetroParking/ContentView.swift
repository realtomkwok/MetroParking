//
//  ContentView.swift
//  MetroParking
//
//  Created by Tom Kwok on 18/5/2025.
//

import SwiftUI
import SwiftData


enum ScreenView: String, CaseIterable, Identifiable {
	case pinned
	case all
	
	var id: String { self.rawValue }
	
	var displayName: String {
		switch self {
			case .pinned: "Pinned & Recents"
			case .all: "All Parkings"
		}
	}
	
	var iconName: String {
		switch self {
			case .pinned: "star"
			case .all: "parkingsign.square"
		}
	}
	
	@ViewBuilder
	func destinationView(all: [ParkingFacility], pinned: [ParkingFacility], recents: [ParkingFacility]) -> some View {
		switch self {
			case .pinned: MainView(
				pinnedFacilities: pinned,
				recentFacilities: recents
			)
			case .all: AllFacilitiesView(facilities: all)
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
	
	/// UI State
	@State private var presentSheet = true
	@State private var hasInitialised = false
	
	var body: some View {
		BackgroundView()
			.sheet(isPresented: $presentSheet) {
				ForegroundView()
					.presentationDetents([.medium, .large])
					.presentationDragIndicator(.hidden)
					.presentationBackgroundInteraction(.enabled)
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
	}
	
	private func initialisedApp() async {
		/// Connect the data manager to SwiftData
		dataManager.setModelContext(modelContext)
		/// Connect the refresh manager to SwiftData
		refreshManager.setModelContext(modelContext)
		
		/// Load static facilities
		await dataManager.loadStaticFacilitiesIfNeeded()
		
		/// Startl loading occupancy data
		await refreshManager.performInitialOccupancyLoad()
		
		refreshManager.startAutoRefresh()
	}
}

struct ForegroundView: View {
	@State private var selectedScreen: ScreenView = .pinned
	@State private var showMoreMenu: Bool = false
	
	/// Refresh manager
	@ObservedObject private var refreshManager = FacilityRefreshManager.shared
	
	/// SwiftData Queries
	@Query private var allFacilities: [ParkingFacility]
	/// Pinned facilities
	@Query(filter: #Predicate<ParkingFacility> { $0.isFavourite == true }, animation: .snappy)
	private var pinnedFacilities: [ParkingFacility]
	/// Recently visited facilities
	@Query(
		filter: #Predicate<ParkingFacility> { $0.lastVisited != nil },
		sort: [SortDescriptor(\ParkingFacility.lastVisited, order: .reverse)],
		animation: .snappy
		)
	private var recentlyVisitedFacilities: [ParkingFacility]
	
	
	var body: some View {
		NavigationStack {
			VStack(alignment: .leading) {
				Topbar()
				selectedScreen.destinationView(
					all: allFacilities,
					pinned: pinnedFacilities,
					recents: recentlyVisitedFacilities
				)
				.ignoresSafeArea()

				Spacer()
			}
			.padding()
		}
		.background()
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
			
			HStack(alignment: .center) {
				Button {
					//TODO: Refresh

					Task {
						await refreshManager.performInitialOccupancyLoad()
					}
				} label: {
					ZStack() {
						Label("Refresh", systemImage: "arrow.clockwise")
							.fontWeight(.semibold)
							.disabled(refreshManager.isRefreshing)
							.symbolEffect(.rotate.clockwise.byLayer, options: .repeat(.continuous), isActive: refreshManager.isRefreshing)
					}
					.frame(minWidth: 20, minHeight: 20)

				}
				.buttonBorderShape(.circle)
				.buttonStyle(.bordered)
				.controlSize(.regular)
				
				Button {
					// TODO: Show menu for more info
					/*@START_MENU_TOKEN@*//*@PLACEHOLDER=Action@*/ /*@END_MENU_TOKEN@*/
				} label: {
					ZStack(alignment: .center) {
						Label("More", systemImage: "ellipsis")
							.fontWeight(.semibold)
							.symbolEffect(.wiggle.byLayer, options: .nonRepeating, isActive: showMoreMenu)
					}
					.frame(minWidth: 20, minHeight: 20)
				}
				.buttonBorderShape(.circle)
				.buttonStyle(.bordered)
				.controlSize(.regular)
				// To align with other components
				.offset(x: 4)
			}
		}
		.frame(maxWidth: .infinity, maxHeight: 48)
		.padding(.bottom, 16)
	}
}

struct BackgroundView: View {
	var body: some View {
		VStack {
			Rectangle()
				.foregroundStyle(.blue)
				.ignoresSafeArea()
		}
	}
}

struct MainView: View {
	let pinnedFacilities: [ParkingFacility]
	let recentFacilities: [ParkingFacility]
	
	var body: some View {
		ScrollView(.vertical, showsIndicators: false) {
			VStack(alignment: .leading, spacing: 24) {
				PinnedFacility()
				RecentFacility()
			}
			.frame(maxWidth: .infinity)
		}
	}
	
	@ViewBuilder
	func PinnedFacility() -> some View {
		
		Text("Pinned")
			.font(.headline)
		
		HStack(alignment: .center) {
			if pinnedFacilities.isEmpty {
				// TODO: Reword
				Text("No pinned parking yet")
			} else {
				ScrollView(.horizontal, showsIndicators: false) {
					HStack(alignment: .center, spacing: 0) {
						ForEach(pinnedFacilities, id: \.facilityId) { facility in
								ParkingGauge(facility: facility)
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
		
		LazyVStack(alignment: .leading) {
			ForEach(recentFacilities, id: \.facilityId) { facility in
				ParkingListCardView(facility: facility)
			}
		}
	}
}

struct AllFacilitiesView: View{
	let facilities: [ParkingFacility]
	
	var body: some View {
		ScrollView(.vertical, showsIndicators: false) {
			LazyVStack(alignment: .listRowSeparatorLeading) {
				ForEach(facilities, id: \.facilityId) { facility in
					ParkingListCardView(facility: facility)
				}
			}
		}
	}
}


#Preview("Normal App State") {
	ContentView()
		.modelContainer(PreviewHelper.previewContainer(withSamplePins: false))
}
