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

	// Access FacilityManager from environment
	@Environment(FacilityManager.self) private var facilityManager

	@State private var searchText: String = ""
	@State private var selectedSorting: SortingOption = .name
	@State private var selectedSortingOrder: SortingOrder = .ascending
	@State private var filterIsOn: Bool = true
	@State private var selectedFilter: FilterOption = .pinned
	@State private var isSearchFieldFocused: Bool = false

	@Query private var facilities: [ParkingFacility]

	private var filteredFacilities: [ParkingFacility] {
		return
			facilities
			.filtered(by: filterIsOn ? selectedFilter : .all)
			.searchFiltered(by: searchText)
			.sorted(by: selectedSorting, order: selectedSortingOrder)
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

	private var backgroundGradient: some View {
		LinearGradient(
			gradient: Gradient(colors: [
				Color(.systemTeal),
				Color(.systemBackground),
			]),
			startPoint: .top,
			endPoint: .center
		)
		.edgesIgnoringSafeArea(.all)
	}

	@available(iOS 26.0, *)
	private var mainContentGlassy: some View {
		ScrollView(.vertical) {
			LazyVStack(spacing: 8) {
				FacilityList(
					facilities: filteredFacilities
				)
			}
			.padding()
		}
		.animation(.snappy, value: filteredFacilities.map(\.facilityId))
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
		}
		.searchable(text: $searchText, isPresented: $isSearchFieldFocused)
	}

	// TODO: main content for iOS versions under iOS 26

	var body: some View {
		NavigationStack {
			ZStack {
				backgroundGradient
				if #available(iOS 26.0, *) {
					mainContentGlassy
				} else {
					// Fallback on earlier versions
				}
			}

		}
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
			Button {
				// TODO: Navigate to settings
			} label: {
				Label("Settings", systemImage: "ellipsis")
			}

			//			Menu {
			//				// Settings section
			//				Section {
			//					Button {
			//						// TODO: Navigate to settings
			//					} label: {
			//						Label("Settings", systemImage: "gear")
			//					}
			//				}
			//			} label: {
			//				Label("More", systemImage: "ellipsis")
			//			}
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

@available(iOS 26.0, *)
struct FacilityList: View {
	let facilities: [ParkingFacility]

	@ViewBuilder
	func FacilityRowView(facility: ParkingFacility) -> some View {
		HStack(alignment: .top) {
			VStack(alignment: .leading) {
				Text(facility.displayName)
					.font(.title2)
					.fontWeight(.medium)
					.foregroundStyle(.foreground)

				Spacer()

				Text(facility.availabilityStatus.text)
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}

			Spacer()
			Text(String(facility.displayAvailableSpots))
				.font(.largeTitle)
				.fontWeight(.regular)
				.contentTransition(.numericText())
		}
		.frame(maxWidth: .infinity)
		.containerShape(
			.rect(cornerRadius: 16, style: .continuous)
		)
		.padding()
		.glassEffect(
			.clear,
			in: .rect(cornerRadius: 16, style: .continuous)
		)
	}

	var body: some View {
		ForEach(facilities, id: \.facilityId) { facility in
			FacilityRowView(facility: facility)
				.transition(.blurReplace)
				.id(facility.facilityId)
		}
	}
}

#Preview {
	ContentView()
		.modelContainer(PreviewHelper.previewContainer(withSamplePins: true))
		.environment(FacilityManager.shared)
}
