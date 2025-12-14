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

	// Access FacilityManager from environment
	@Environment(FacilityManager.self) private var facilityManager

	@State private var searchText: String = ""
	@State private var selectedSorting: SortingOption = .name
	@State private var selectedSortingOrder: SortingOrder = .ascending
	@State private var filterIsOn: Bool = false
	@State private var selectedFilter: FilterOption = .pinned
	@State private var isSearchFieldFocused: Bool = false
	@State private var selectedFacility: ParkingFacility?

	// Two separate queries - SwiftData handles animations natively
	@Query(filter: #Predicate<ParkingFacility> { $0.isFavourite == true })
	private var pinnedFacilities: [ParkingFacility]

	@Query(filter: #Predicate<ParkingFacility> { $0.isFavourite == false })
	private var unpinnedFacilities: [ParkingFacility]

	private var filteredPinnedFacilities: [ParkingFacility] {
		return
			pinnedFacilities
			.filtered(by: filterIsOn ? selectedFilter : .all)
			.searchFiltered(by: searchText)
			.sorted(by: selectedSorting, order: selectedSortingOrder)
	}

	private var filteredUnpinnedFacilities: [ParkingFacility] {
		return
			unpinnedFacilities
			.filtered(by: filterIsOn ? selectedFilter : .all)
			.searchFiltered(by: searchText)
			.sorted(by: selectedSorting, order: selectedSortingOrder)
	}

	/// Grouped facilities with pinned items at the top
	private var groupedFacilities:
		[(title: String?, facilities: [ParkingFacility])]
	{

		Logger.facilityData.info(
			"\(pinnedFacilities.count) pinned, \(unpinnedFacilities.count) unpinned"
		)

		var sections: [(title: String?, facilities: [ParkingFacility])] = []

		if !filteredPinnedFacilities.isEmpty {
			sections.append(
				(title: "Pinned", facilities: filteredPinnedFacilities)
			)
		}

		if !filteredUnpinnedFacilities.isEmpty {
			sections
				.append(
					(
						title: filteredPinnedFacilities.isEmpty
							? nil : "More Parking",
						facilities: filteredUnpinnedFacilities
					)
				)
		}

		return sections
	}

	private var navigationSubtitleText: String {
		if facilityManager.isRefreshing {
			return facilityManager.loadProgress.description
		} else if let lastRefresh = facilityManager.lastRefreshTime {
			return
				"Updated \(lastRefresh.formatted(.relative(presentation: .named)))"
		} else {
			return "Pull down to refresh"
		}
	}

	var body: some View {
		NavigationStack {
			ZStack {
				BackgroundGradient()
				if #available(iOS 26.0, *) {
					FacilityList(
						nameSpace: navigationNamespace,
						groupedFacilities: groupedFacilities
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
				}
			}
		}
		.containerShape(.rect(cornerRadius: 24))
	}

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
				Section("Developer") {
					NavigationLink(destination: APIUsageDebugView()) {
						Label("API Debug", systemImage: "hammer")
					}
				}
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
				.animation(.snappy(duration: 0.35), value: filterIsOn)
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
}

#Preview("Empty State") {
	ContentView()
		.modelContainer(.emptyPreview())
		.environment(FacilityManager.shared)
		.environment(LookAroundManager.shared)
}
