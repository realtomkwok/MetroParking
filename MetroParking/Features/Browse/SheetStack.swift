//
//  SheetStack.swift
//  MetroParking
//
//  Created by Tom Kwok on 13/9/2026.
//

import SwiftData
import SwiftUI

/// The navigation stack shown in the map's sheet (compact) or floating panel (regular).
/// Browse is the root; facility details are pushed from list rows, map pins, deep links
/// and the nearby-parking section.
struct SheetStack: View {
	@Bindable var model: MapSheetModel

	@Environment(OnboardingManager.self) private var onboardingMgr

	var body: some View {
		@Bindable var onboarding = onboardingMgr

		NavigationStack(path: $model.path) {
			BrowseView(model: model)
				.navigationDestination(for: MapSheetModel.Route.self) { route in
					switch route {
					case .facility(let id):
						FacilityDestination(facilityId: id)
					}
				}
		}
		.containerBackground(.clear, for: .navigation)
		// Presented from inside the sheet: the root view is already presenting the sheet itself.
		.sheet(isPresented: $onboarding.isShowingOnboarding) {
			OnboardingView()
		}
	}
}

/// Resolves a facility ID from the navigation path into its detail view.
private struct FacilityDestination: View {
	@Query private var matches: [ParkingFacility]

	init(facilityId: String) {
		_matches = Query(
			filter: #Predicate<ParkingFacility> { $0.facilityId == facilityId }
		)
	}

	var body: some View {
		if let facility = matches.first {
			FacilityDetailView(facility: facility)
		} else {
			ProgressView()
		}
	}
}

// MARK: - Browse

struct BrowseView: View {
	@Bindable var model: MapSheetModel

	@Environment(SearchManager.self) private var searchMgr
	@Environment(UserPreferences.self) private var preferences

	@State private var isSettingsPresented: Bool = false

	@Query(animation: .smooth)
	private var allFacilities: [ParkingFacility]

	/// Grouped facilities with pinned items at the top
	private var groupedFacilities:
		[(title: LocalizedStringResource?, facilities: [ParkingFacility])]
	{
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

		let pinnedFacilities = filteredFacilities.filter { $0.isFavourite }
		let unpinnedFacilities = filteredFacilities.filter { !$0.isFavourite }

		var sections:
			[(title: LocalizedStringResource?, facilities: [ParkingFacility])] =
				[]

		if !pinnedFacilities.isEmpty {
			sections.append(
				(title: "facilityList.section.title.pinned", facilities: pinnedFacilities)
			)
		}

		if !unpinnedFacilities.isEmpty {
			sections.append(
				(
					title: pinnedFacilities.isEmpty
						? nil : "facilityList.section.title.more",
					facilities: unpinnedFacilities
				)
			)
		}

		return sections
	}

	var body: some View {
		@Bindable var search = searchMgr
		let sections = groupedFacilities

		FacilityList(groupedFacilities: sections)
			.scrollContentBackground(.hidden)
			.overlay {
				if sections.isEmpty {
					emptyState
				}
			}
			.safeAreaBar(edge: .top) {
				BrowseControls(preferences: preferences)
			}
			.navigationTitle(.metroParking)
			.modifier(RefreshStatusSubtitle())
			.toolbarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					RefreshButton(scope: .all)
				}

				ToolbarItem(placement: .topBarTrailing) {
					Button {
						isSettingsPresented.toggle()
					} label: {
						Label(.settingsLabelTitle, systemImage: "ellipsis")
							.labelStyle(.iconOnly)
					}
					.accessibilityIdentifier("settings-button")
				}
			}
			.searchable(
				text: $search.searchText,
				isPresented: $search.isSearching,
				placement: .navigationBarDrawer(displayMode: .always),
				prompt: .facilityListPlaceholderSearch
			)
			.onChange(of: searchMgr.isSearching) { _, isSearching in
				// Give search results room, like Maps does.
				if isSearching {
					model.detent = .large
				}
			}
			.sheet(isPresented: $isSettingsPresented) {
				SettingsView()
			}
	}

	@ViewBuilder
	private var emptyState: some View {
		if !searchMgr.searchText.isEmpty {
			ContentUnavailableView.search(text: searchMgr.searchText)
		} else if preferences.filterIsOn
			&& preferences.preferredFilterOption == .pinned
		{
			ContentUnavailableView {
				Label(
					.facilityListEmptyNoPinnedTitle,
					systemImage: "questionmark.diamond.fill"
				)
			} description: {
				Text(.facilityListEmptyNoPinnedMessage)
			} actions: {
				Button {
					withAnimation(.snappy) {
						preferences.filterIsOn.toggle()
					}
				} label: {
					Text(.actionButtonClearFilter)
				}
				.buttonStyle(.borderedProminent)
			}
		}
	}
}

// MARK: - Subtitle

/// Shows refresh progress as the navigation subtitle.
///
/// A separate modifier so progress updates (one per facility during a refresh)
/// only re-render the subtitle, not BrowseView's filter, search and sort.
private struct RefreshStatusSubtitle: ViewModifier {
	@Environment(FacilityManager.self) private var facilityDataMgr
	@Environment(UserPreferences.self) private var preferences

	private var subtitle: Text {
		if preferences.filterIsOn {
			switch preferences.preferredFilterOption {
			case .pinned:
				return Text(.facilityListStatusPinnedOnly)
			case .available:
				return Text(.sortFilterStatusAvailableOnly)
			}
		}

		if facilityDataMgr.isRefreshing {
			return Text(facilityDataMgr.loadProgress.description)
		}

		return Text(.facilityListStatusAllUpdated)
	}

	func body(content: Content) -> some View {
		content.navigationSubtitle(subtitle)
	}
}

// MARK: - Filter & sort controls

private struct BrowseControls: View {
	@Bindable var preferences: UserPreferences

	var body: some View {
		GlassEffectContainer(spacing: 8) {
			HStack(spacing: 8) {
				Toggle(isOn: $preferences.filterIsOn.animation(.bouncy)) {
					Label(
						.sortFilterLabelFilter,
						systemImage: "line.3.horizontal.decrease"
					)
					.labelStyle(.iconOnly)
				}
				.toggleStyle(.button)
				.buttonStyle(.glass)
				.buttonBorderShape(.circle)
				.accessibilityIdentifier("filter-toggle")
				.sensoryFeedback(.selection, trigger: preferences.filterIsOn)

				if preferences.filterIsOn {
					filterPicker
						.transition(.move(edge: .leading).combined(with: .opacity))
				}

				Spacer(minLength: 0)

				sortingMenu
			}
			.controlSize(.regular)
		}
		.padding(.horizontal)
		.padding(.bottom, 4)
	}

	private var filterPicker: some View {
		Menu {
			Picker(selection: $preferences.preferredFilterOption) {
				ForEach(FilterOption.allCases, id: \.self) { option in
					Label(
						option.display.title,
						systemImage: option == preferences.preferredFilterOption
							? option.display.systemImageAfter
							: option.display.systemImage
					)
					.tag(option)
				}
			} label: {
				Text(.sortFilterLabelFilters)
			}
			.pickerStyle(.inline)
		} label: {
			Label(
				preferences.preferredFilterOption.display.title,
				systemImage: preferences.preferredFilterOption.display.systemImageAfter
			)
			.font(.subheadline.weight(.semibold))
		}
		.buttonStyle(.glass)
		.sensoryFeedback(.selection, trigger: preferences.preferredFilterOption)
	}

	private var sortingMenu: some View {
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
					.sortFilterLabelOrder,
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
				Label(
					.sortFilterLabelSortBy,
					systemImage: "arrow.up.arrow.down"
				)
				.labelStyle(.titleOnly)
			}
			.pickerStyle(.inline)
		} label: {
			Label(
				preferences.preferredSortOption.display.title,
				systemImage: "arrow.up.arrow.down"
			)
			.font(.subheadline.weight(.semibold))
		}
		.buttonStyle(.glass)
		.sensoryFeedback(.selection, trigger: preferences.preferredSortOption)
		.sensoryFeedback(.selection, trigger: preferences.preferredSortingOrder)
		.accessibilityIdentifier("sorting-menu")
	}
}
