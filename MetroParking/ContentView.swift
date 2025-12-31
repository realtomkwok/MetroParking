//
//  ContentView.swift
//  MetroParking
//
//  Created by Tom Kwok on 18/5/2025.
//

import MapKit
import OSLog
import SwiftData
import SwiftUI

struct ContentView: View {
	@Namespace var navigationNamespace

	// Access managers from environment
	@Environment(FacilityManager.self) private var facilityManager
	@Environment(OnboardingManager.self) private var onboardingMgr
	@Environment(DeepLinkManager.self) private var deepLinkMgr

	@State private var searchText: String = ""
	@State private var selectedSorting: SortingOption = .name
	@State private var selectedSortingOrder: SortingOrder = .ascending
	@State private var filterIsOn: Bool = false
	@State private var selectedFilter: FilterOption = .pinned
	@State private var isSearchFieldFocused: Bool = false
	@State private var selectedFacility: ParkingFacility?

	// Single query for all facilities - let SwiftData handle animations smoothly
	@Query(animation: .snappy)
	private var allFacilities: [ParkingFacility]

	/// Grouped facilities with pinned items at the top
	private var groupedFacilities:
		[(title: String?, facilities: [ParkingFacility])]
	{
		// Filter and sort all facilities once
		let filteredFacilities =
			allFacilities
			.filtered(by: filterIsOn ? selectedFilter : .all)
			.searchFiltered(by: searchText)
			.sorted(by: selectedSorting, order: selectedSortingOrder)

		// Separate into pinned and unpinned after filtering/sorting
		let pinnedFacilities = filteredFacilities.filter { $0.isFavourite }
		let unpinnedFacilities = filteredFacilities.filter { !$0.isFavourite }

		var sections: [(title: String?, facilities: [ParkingFacility])] = []

		if !pinnedFacilities.isEmpty {
			sections.append(
				(title: "Pinned", facilities: pinnedFacilities)
			)
		}

		if !unpinnedFacilities.isEmpty {
			sections.append(
				(
					title: pinnedFacilities.isEmpty
						? nil : "More Parking",
					facilities: unpinnedFacilities
				)
			)
		}

		return sections
	}

	// TODO: Dynamically refresh the last updated time -> Doesn't work
	private var navigationSubtitleText: Text {
		if facilityManager.isRefreshing {
			return Text(facilityManager.loadProgress.description)
		} else if let lastRefresh = facilityManager.lastRefreshTime {
			return Text("Updated \(lastRefresh, style: .relative) ago")
		} else {
			return Text("Pull down to refresh")
		}
	}

	var body: some View {
		@Bindable var onboarding = onboardingMgr

		NavigationStack {
			ZStack {
				BackgroundGradient()
				if #available(iOS 26.0, *) {
					FacilityList(
						nameSpace: navigationNamespace,
						groupedFacilities: groupedFacilities,
						selectedFacility: $selectedFacility
					)
					.navigationTitle("MetroParking")
					.navigationSubtitle(navigationSubtitleText)
					.refreshable {
						await facilityManager.performLoad(forced: true)
					}
					.toolbar {
						TopBarActions()
					}
					.toolbarTitleDisplayMode(.inlineLarge)

					.toolbar {
						DefaultToolbarItem(kind: .search, placement: .bottomBar)
						ToolbarSpacer(.flexible, placement: .bottomBar)
						BottomBarActions()
							.matchedTransitionSource(
								id: "BottomBarActions",
								in: navigationNamespace
							)
					}
					.searchable(
						text: $searchText,
						isPresented: $isSearchFieldFocused,
						placement: .toolbar
					)
					.scrollEdgeEffectStyle(.soft, for: .vertical)
					.scrollContentBackground(.hidden)
				} else {
					// Fallback on earlier versions
					// TODO: main content for iOS versions under iOS 26
					FacilityList(
						nameSpace: navigationNamespace,
						groupedFacilities: groupedFacilities,
						selectedFacility: $selectedFacility
					)
					.navigationTitle("MetroParking")
					.refreshable {
						await facilityManager.performLoad(forced: true)
					}
					.toolbar {
						TopBarActions()
					}
					.toolbarTitleDisplayMode(.inlineLarge)

					//					.toolbar {
					//						DefaultToolbarItem(kind: .search, placement: .bottomBar)
					//						ToolbarSpacer(.flexible, placement: .bottomBar)
					//						BottomBarActions()
					//							.matchedTransitionSource(
					//								id: "BottomBarActions",
					//								in: navigationNamespace
					//							)
					//					}
					.searchable(
						text: $searchText,
						isPresented: $isSearchFieldFocused,
						placement: .toolbar
					)
				}
			}
		}
		.backport.concentricClipShape()
		.ignoresSafeArea()
		.containerShape(.rect(cornerRadius: 24))
		.sheet(isPresented: $onboarding.isShowingOnboarding) {
			if #available(iOS 26.0, *) {
				OnboardingView()
					.environment(OnboardingManager.shared)
			}
		}
		.onChange(of: deepLinkMgr.selectedFacilityId) { oldValue, newValue in
			guard let facilityId = newValue else { return }
			handleDeepLinkUrl(facilityId: facilityId)
		}
	}
}

// MARK: - Helper functions
extension ContentView {

	private func handleDeepLinkUrl(facilityId: String) {
		// Fetch the facility from SwiftData
		let descriptor = FetchDescriptor<ParkingFacility>(
			predicate: #Predicate { $0.facilityId == facilityId }
		)

		let facilities = allFacilities.filter { $0.facilityId == facilityId }
		guard let facility = facilities.first else {
			Logger
				.deeplink.error(
					"⚠️ Deep link: No facility found with ID: \(facilityId)"
				)
			deepLinkMgr.clearSelection()
			return
		}

		Logger.deeplink.info(
			"✅ Deep link: Navigating to facility '\(facility.displayName.title)'"
		)

		// Set the selected facility to trigger navigation
		selectedFacility = facility

		// Clear the deep link handler after navigation is initiated
		deepLinkMgr.clearSelection()

	}
}

extension ContentView {

	@ToolbarContentBuilder
	func TopBarActions() -> some ToolbarContent {
		ToolbarItem(placement: .topBarTrailing) {
			Button {
				Task {
					await facilityManager.performLoad(
						forced: true
					)
				}
			} label: {
				Image(systemName: "arrow.clockwise")
					.symbolEffect(
						.rotate,
						isActive: facilityManager.isRefreshing
					)
			}
			.accessibilityLabel("Refresh")
			.disabled(facilityManager.isRefreshing)
		}

		ToolbarItem(placement: .topBarTrailing) {

			Menu {
				// Settings section
				Section("Settings") {
					Button {
						// TODO: Navigate to settings
					} label: {
						Label("Notifications", systemImage: "bell.badge")
					}
				}
				#if DEBUG
					Section("Developer") {
						NavigationLink(destination: APIUsageDebugView()) {
							Label("API Debug", systemImage: "hammer")
						}

						NavigationLink(
							destination: BackgroundRefreshDebugView()
						) {
							Label(
								"Background Refresh",
								systemImage: "arrow.clockwise.circle"
							)
						}
					}
				#endif

			} label: {
				Label("Settings", systemImage: "ellipsis")
			}
		}
	}

	@available(iOS 26.0, *)
	@ToolbarContentBuilder
	func BottomBarActions() -> some ToolbarContent {
		ToolbarItem(placement: .bottomBar) {
			GlassEffectContainer(spacing: 2) {
				HStack(spacing: 4) {
					Toggle(
						isOn: $filterIsOn
					) {
						Label(
							"Filter",
							systemImage: "line.3.horizontal.decrease"
						)
						.labelStyle(.iconOnly)
					}

					if filterIsOn {
						FilterPicker(
							selectedFilter: $selectedFilter,
							selectedSorting: $selectedSorting,
							selectedSortingOrder: $selectedSortingOrder
						)
						.transition(.blurReplace)
					}
				}
				.animation(.snappy, value: filterIsOn)
			}
			.fixedSize()
		}
	}

	@available(iOS 26.0, *)
	struct FilterPicker: View {
		@Binding var selectedFilter: FilterOption
		@Binding var selectedSorting: SortingOption
		@Binding var selectedSortingOrder: SortingOrder

		var body: some View {
			Menu {
				LabeledPickerSection(
					title: "Filtered by",
					selection: $selectedFilter,
					options: FilterOption.allCases
				)

				LabeledPickerSection(
					title: "Sort by",
					selection: $selectedSorting,
					options: SortingOption.allCases
				)
				Picker(
					selectedSortingOrder.display.title,
					systemImage: "arrow.up.arrow.down",
					selection: $selectedSortingOrder
				) {
					ForEach(SortingOrder.allCases, id: \.self) { option in
						Label(
							option.display.title,
							systemImage: option.display.systemImage
						)
					}
				}
				.pickerStyle(.menu)
			} label: {
				VStack(alignment: .leading) {
					Text("Filtered by")
						.font(.footnote)
						.fontWeight(.semibold)
					HStack(alignment: .center, spacing: 2) {
						Text(selectedFilter.display.title)
							.font(.footnote)
						Image(systemName: "chevron.down")
							.font(.system(size: 8))
					}
					.fontWeight(.medium)
					.foregroundStyle(Color.accentColor)
				}
				.padding(.trailing)
			}
			.menuStyle(.button)
		}
	}

	/// A reusable picker section for options with display properties
	@available(iOS 26.0, *)
	struct LabeledPickerSection<T>: View
	where
		T: CaseIterable & Hashable & PickerOptionDisplayable,
		T.DisplayType: BasicDisplayable
	{
		let title: String
		@Binding var selection: T
		let options: [T]

		var body: some View {
			Section {
				Picker(title, selection: $selection) {
					ForEach(Array(options), id: \.self) { option in
						Label(
							option.display.title,
							systemImage: option.display.systemImage
						)
						.tag(option)
					}
				}
				.labelsVisibility(.visible)
				.pickerStyle(.inline)
			}
		}
	}
}

#Preview("With Pinned Facilities") {

	ContentView()
		.modelContainer(.preview(includeSampleData: true, favoriteCount: 3))
		.environment(FacilityManager.shared)
		.environment(LookAroundManager.shared)
		.environment(OnboardingManager.shared)
}

#Preview("Empty State") {
	ContentView()
		.modelContainer(.emptyPreview())
		.environment(FacilityManager.shared)
		.environment(LookAroundManager.shared)
		.environment(OnboardingManager.shared)
}
