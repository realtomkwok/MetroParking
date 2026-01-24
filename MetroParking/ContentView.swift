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
	@Environment(\.modelContext) private var modelContext
	@Environment(\.dismiss) private var dismiss
	@Environment(\.isSearching) private var isSearching

	@Environment(FacilityManager.self) private var facilityDataMgr
	@Environment(OnboardingManager.self) private var onboardingMgr
	@Environment(DeepLinkManager.self) private var deepLinkMgr
	@Environment(SearchManager.self) private var searchMgr
	@Environment(UserPreferences.self) private var preferences

	@State private var selectedFacility: ParkingFacility?
	@State private var isFilterMenuPresented: Bool = false
	@State private var deepLinkedFacility: ParkingFacility?
	@State private var isSettingsPresented: Bool = false

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
			.filtered(
				by: preferences.filterIsOn
					? preferences.preferredFilterOption : nil
			)
			.searchFiltered(by: searchMgr.searchText)
			.sorted(
				by: preferences.preferredSortOption,
				order: preferences.preferredSortingOrder
			)

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

	private var navigationSubtitle: Text {

		if preferences.filterIsOn {
			switch preferences.preferredFilterOption {
			case .pinned:
				return Text("Showing pinned car parks only")
			case .available:
				return Text("Showing available car parks only")
			}
		}

		if facilityDataMgr.isRefreshing {
			return Text(facilityDataMgr.loadProgress.description)
		}

		return Text("All updated")

	}

	var body: some View {
		@Bindable var onboarding = onboardingMgr
		@Bindable var search = searchMgr
		@Bindable var preferences = preferences

		NavigationStack {
			ZStack {
				BackgroundGradient(isAnimating: false)
				FacilityList(
					nameSpace: navigationNamespace,
					groupedFacilities: groupedFacilities,
					selectedFacility: $selectedFacility,
					isInteractionDisabled: isFilterMenuPresented
				)
				.toolbar {
					TopBar()
				}
				.toolbar {
					BottomBar()

				}
				.searchable(
					text: $search.searchText,
					isPresented: $search.isSearchFieldFocused,
					placement: .toolbar,
					prompt: "Station or suburb"
				)
				.searchToolbarBehavior(preferences.filterIsOn ? .minimize : .automatic)
			}
			.navigationTitle("MetroParking")
			.navigationSubtitle(navigationSubtitle)
			.toolbarTitleDisplayMode(.inlineLarge)
			.refreshable {
				await facilityDataMgr.performLoad(forced: true)
			}
			.scrollEdgeEffectStyle(.soft, for: .vertical)
			.scrollContentBackground(.hidden)
		}
		.backport.concentricClipShape()
		.ignoresSafeArea()
		.containerShape(.rect(cornerRadius: 24))
		.sheet(isPresented: $isSettingsPresented) {
			SettingsView()
		}
		.sheet(isPresented: $onboarding.isShowingOnboarding) {
			OnboardingView()
				.environment(OnboardingManager.shared)
		}
		.sheet(item: $deepLinkedFacility) { facility in
			DetailSheet(selectedFacility: facility)
				.presentationDragIndicator(.visible)
				.navigationAllowDismissalGestures([.none])
		}
		.onChange(of: deepLinkMgr.selectedFacilityId) { _, newValue in
			guard let facilityId = newValue else { return }
			handleDeepLink(facilityId: facilityId)
		}
	}
}

// MARK: - Private views
extension ContentView {

	@ViewBuilder
	private func DetailSheet(selectedFacility: ParkingFacility) -> some View {
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
		// Use SwiftData predicate query for O(1) lookup instead of O(n) array scan
		// This also avoids creating a dependency on the entire allFacilities array
		let descriptor = FetchDescriptor<ParkingFacility>(
			predicate: #Predicate { $0.facilityId == facilityId }
		)

		guard let facility = try? modelContext.fetch(descriptor).first else {
			Logger.deeplink.error(
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
				Label("Refresh", systemImage: "arrow.clockwise")
					.labelStyle(.iconOnly)
					.symbolEffect(
						.rotate,
						isActive: facilityDataMgr.isRefreshing
					)
			}
			.accessibilityLabel("Refresh")
			.disabled(facilityDataMgr.isRefreshing)
		}

		ToolbarItem(placement: .topBarTrailing) {
			Button {
				isSettingsPresented.toggle()
			} label: {
				Label("Settings", systemImage: "ellipsis")
					.labelStyle(.iconOnly)
			}
			.accessibilityIdentifier("settings-button")
		}
	}

	@ToolbarContentBuilder
	func BottomBar() -> some ToolbarContent {
		@Bindable var preferences = preferences

		ToolbarItemGroup(placement: .bottomBar) {

			Toggle(isOn: $preferences.filterIsOn.animation(.snappy)) {
				Label(
					"Filter",
					systemImage: "line.3.horizontal.decrease"
				)
				.labelStyle(.iconOnly)
			}
			.accessibilityIdentifier("filter-toggle")
			.sensoryFeedback(.selection, trigger: preferences.filterIsOn)

			if preferences.filterIsOn {

				Picker(selection: $preferences.preferredFilterOption) {
					ForEach(FilterOption.allCases, id: \.self) { option in
						Label(
							option.display.title,
							systemImage: option.display.systemImage
						)
						.tag(option)
					}
				} label: {
					Text("Text")
				}
				.pickerStyle(.inline)
			}
		}

		ToolbarSpacer(.flexible, placement: .bottomBar)

		DefaultToolbarItem(kind: .search, placement: .bottomBar)

		ToolbarSpacer(.flexible, placement: .bottomBar)

		ToolbarItem(id: "Sorting", placement: .bottomBar) {

			Menu {
				let isAscending: Bool =
					preferences.preferredSortingOrder == .ascending

				Picker(selection: $preferences.preferredSortingOrder) {
					ForEach(SortingOrder.allCases, id: \.self) { order in
						Label(
							preferences.preferredSortOption.display.subtitle(
								ascending: order == .ascending
							),
							systemImage: order.display.systemImage
						)
						.tag(order)
					}
				} label: {
					Label(
						"Order",
						systemImage: isAscending
							? "text.line.first.and.arrowtriangle.forward"
							: "text.line.last.and.arrowtriangle.forward"
					)
					Text(
						preferences.preferredSortOption.display.subtitle(
							ascending: isAscending
						)
					)
				}
				.pickerStyle(.menu)

				Picker(selection: $preferences.preferredSortOption) {
					ForEach(SortingOption.allCases, id: \.self) { option in
						Label(
							option.display.title,
							systemImage: option.display.systemImage
						)
						.tag(option)
					}
				} label: {
					Text("Sort by")
				}
			} label: {
				Label("Sort by", systemImage: "arrow.up.arrow.down")
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
		.environment(UserPreferences.shared)
}

#Preview("Empty State") {
	ContentView()
		.modelContainer(.emptyPreview())
		.environment(FacilityManager.shared)
		.environment(LookAroundManager.shared)
		.environment(OnboardingManager.shared)
		.environment(DeepLinkManager.shared)
		.environment(SearchManager.shared)
		.environment(UserPreferences.shared)
}
