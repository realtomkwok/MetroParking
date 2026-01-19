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
	@Namespace private var navigationNamespace
	@Namespace private var filterToggleNamespace

	// Access managers from environment
	@Environment(FacilityManager.self) private var facilityDataMgr
	@Environment(OnboardingManager.self) private var onboardingMgr
	@Environment(DeepLinkManager.self) private var deepLinkMgr
	@Environment(SearchManager.self) private var searchMgr
	@Environment(\.dismiss) private var dismiss

	@State private var filterIsOn: Bool = false
	@State private var selectedSorting: SortingOption = .distance
	@State private var selectedSortingOrder: SortingOrder = .ascending
	@State private var selectedFilter: FilterOption = .available
	@State private var selectedFacility: ParkingFacility?
	@State private var isFilterMenuPresented: Bool = false
	@State private var deepLinkedFacility: ParkingFacility?

	// Single query for all facilities - let SwiftData handle animations smoothly
	@Query(animation: .smooth)
	private var allFacilities: [ParkingFacility]

	/// Grouped facilities with pinned items at the top
	private var groupedFacilities:
		[(title: String?, facilities: [ParkingFacility])]
	{
		// Filter and sort all facilities once
		let filteredFacilities =
			allFacilities
			.filtered(by: filterIsOn ? selectedFilter : .all)
			.searchFiltered(by: searchMgr.searchText)
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

	@ViewBuilder
	private var navigationSubtitleView: some View {
		ZStack {
			if facilityDataMgr.isRefreshing {
				Text(facilityDataMgr.loadProgress.description)
					.zIndex(1)
			} else {
				Text("Pull down to refresh")
					.zIndex(0)
			}
		}
		.transition(.blurReplace)
	}

	var body: some View {
		@Bindable var onboarding = onboardingMgr
		@Bindable var search = searchMgr

		NavigationStack {
			ZStack {
				BackgroundGradient(isAnimating: false)
				FacilityList(
					nameSpace: navigationNamespace,
					groupedFacilities: groupedFacilities,
					selectedFacility: $selectedFacility,
					isInteractionDisabled: isFilterMenuPresented
				)
				.navigationTitle("MetroParking")
				.refreshable {
					await facilityDataMgr.performLoad(forced: true)
				}
				.toolbar {
					TopBar()
					BottomBarActions()
				}
				.toolbarTitleDisplayMode(.inlineLarge)
				.searchable(
					text: $search.searchText,
					isPresented: $search.isSearchFieldFocused,
					placement: .automatic,
					prompt: "Station name or suburb"
				)
				.scrollEdgeEffectStyle(.soft, for: .vertical)
				.scrollContentBackground(.hidden)
			}
		}
		.backport.concentricClipShape()
		.ignoresSafeArea()
		.containerShape(.rect(cornerRadius: 24))
		.sheet(isPresented: $onboarding.isShowingOnboarding) {
			OnboardingView()
				.environment(OnboardingManager.shared)
		}
		.sheet(item: $deepLinkedFacility) { facility in
			DetailSheet(selectedFacility: facility)
				.presentationDragIndicator(.visible)
			//			.presentationCornerRadius(24)
		}
		.onChange(of: deepLinkMgr.selectedFacilityId) { oldValue, newValue in
			guard let facilityId = newValue else { return }
			handleDeepLink(facilityId: facilityId)
		}
	}
}

// MARK: - Private views
extension ContentView {

	@ViewBuilder
	func DetailSheet(selectedFacility: ParkingFacility) -> some View {
		NavigationStack {
			FacilityDetailView(
				namespace: navigationNamespace,
				facility: selectedFacility
			)
			.toolbar {
				ToolbarItem(placement: .topBarLeading) {
					Button {
						deepLinkedFacility = nil
					} label: {
						Image(systemName: "xmark")
					}
				}
			}
		}
	}
}

// MARK: - Helper functions
extension ContentView {

	private func handleDeepLink(facilityId: String) {

		guard
			let facility = allFacilities.first(where: {
				$0.facilityId == facilityId
			})
		else {
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

		// Present as sheet with animation
		withAnimation(.smooth) {
			deepLinkedFacility = facility
		}

		// Clear the deep link handler after navigation is initiated
		deepLinkMgr.clearSelection()

	}
}

// MARK: - Toolbar
extension ContentView {

	@ToolbarContentBuilder
	func TopBar() -> some ToolbarContent {

		ToolbarItem(placement: .topBarTrailing) {
			Button {
				Task {
					await facilityDataMgr.performLoad()
				}
			} label: {
				Image(systemName: "arrow.clockwise")
					.symbolEffect(
						.rotate,
						isActive: facilityDataMgr.isRefreshing
					)
			}
			.accessibilityLabel("Refresh")
			.disabled(facilityDataMgr.isRefreshing)
		}

		ToolbarItem(placement: .topBarTrailing) {
			SettingsView()
		}

		ToolbarItem(placement: .largeSubtitle) {
			navigationSubtitleView
				.font(.footnote)
				.foregroundStyle(.secondary)
				.animation(.smooth, value: facilityDataMgr.isRefreshing)
		}

		ToolbarItem(
			placement: .subtitle,
		) {
			navigationSubtitleView
				.font(.footnote)
				.foregroundStyle(.secondary)
				.animation(.smooth, value: facilityDataMgr.isRefreshing)
		}

	}

	@ToolbarContentBuilder
	func BottomBarActions() -> some ToolbarContent {
		DefaultToolbarItem(kind: .search, placement: .bottomBar)

		ToolbarSpacer(.flexible, placement: .bottomBar)

		ToolbarItemGroup(placement: .bottomBar) {

			Toggle(isOn: $filterIsOn.animation(.snappy)) {
				Label(
					"Filter",
					systemImage: "line.3.horizontal.decrease"
				)
				.labelStyle(.iconOnly)

			}
			.glassEffectID("filterToggle", in: filterToggleNamespace)

			if filterIsOn {
				Menu {
					LabeledPickerSection(
						title: "Show only",
						icon: "line.3.horizontal.decrease",
						selection: $selectedFilter,
						options: FilterOption.allCases
					)

					LabeledPickerSection(
						title: "Sort by",
						icon: "arrow.up.arrow.down",
						selection: $selectedSorting,
						options: SortingOption.allCases
					)

					LabeledPickerSection(
						title: "Order",
						icon: "",
						selection: $selectedSortingOrder,
						options: SortingOrder.allCases
					)
				} label: {
					VStack(alignment: .leading, spacing: 2) {
						Text("Show only")
							.font(.caption2)
							.foregroundStyle(.secondary)
						HStack(alignment: .center) {
							Text(selectedFilter.display.title)
								.font(.caption)
								.fontWeight(.semibold)
							Image(
								systemName: "chevron.down"
							)
							.font(.system(size: 8))
							.fontWeight(.semibold)
						}
						.foregroundStyle(Color.accentColor)
					}
				}
				.menuStyle(.button)
				.glassEffectID("filterMenu", in: filterToggleNamespace)
			}
		}
	}

			/// A reusable picker section for options with display properties
		struct LabeledPickerSection<T>: View
		where
		T: CaseIterable & Hashable & PickerOptionDisplayable,
		T.DisplayType: BasicDisplayable
		{
			let title: String
			let icon: String
			@Binding var selection: T
			let options: [T]

			var body: some View {
					// Use Picker directly in menu instead of nesting Menu within Menu
					// This avoids UIPreviewTarget crashes with nested menus
				Picker(selection: $selection) {
					ForEach(Array(options), id: \.self) { option in
						Label(
							option.display.title,
							systemImage: option.display.systemImage
						)
						.tag(option)
					}
				} label: {
					Label(title, systemImage: icon)
					Text(selection.display.title)
				}
				.pickerStyle(.menu)
			}
		}
}

#Preview("With Pinned Facilities") {

	ContentView()
		.modelContainer(.preview(includeSampleData: true, favoriteCount: 3))
		.environment(FacilityManager.shared)
		.environment(LookAroundManager.shared)
		.environment(OnboardingManager.shared)
		.environment(DeepLinkManager.shared)
		.environment(SearchManager.shared)
}

#Preview("Empty State") {
	ContentView()
		.modelContainer(.emptyPreview())
		.environment(FacilityManager.shared)
		.environment(LookAroundManager.shared)
		.environment(OnboardingManager.shared)
		.environment(DeepLinkManager.shared)
		.environment(SearchManager.shared)
}
