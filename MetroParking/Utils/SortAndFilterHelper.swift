//
//  SortAndFilterHelper.swift
//  MetroParking
//
//  Created by Tom Kwok on 4/12/2025.
//

import Foundation
import SwiftData

/// Protocol for types that can be displayed in a labeled picker
protocol PickerOptionDisplayable {
	associatedtype DisplayType
	var display: DisplayType { get }
}

/// Protocol specifically for options with basic display properties (title and systemImage)
protocol BasicDisplayable {
	var title: String { get }
	var systemImage: String { get }
}

struct SortingOptionDisplay: BasicDisplayable {
	let title: String
	let systemImage: String
	let ascendingSubtitle: String
	let descendingSubtitle: String

	/// Returns the subtitle for the current sort order
	func subtitle(ascending: Bool) -> String {
		ascending ? ascendingSubtitle : descendingSubtitle
	}
}

struct SortingOrderDisplay: BasicDisplayable {
	let title: String
	let systemImage: String
}

struct FilterOptionDisplay: BasicDisplayable {
	let title: String
	let systemImage: String
}

enum SortingOption: String, CaseIterable, Codable, Hashable,
	PickerOptionDisplayable
{
	case name
	case lastUpdated
	case distance

	var display: SortingOptionDisplay {
		switch self {
		case .name:
			SortingOptionDisplay(
				title: "Name",
				systemImage: "textformat",
				ascendingSubtitle: "A to Z",
				descendingSubtitle: "Z to A"
			)
		case .lastUpdated:
			SortingOptionDisplay(
				title: "Last Updated",
				systemImage:
					"clock.arrow.trianglehead.2.counterclockwise.rotate.90",
				ascendingSubtitle: "Oldest First",
				descendingSubtitle: "Newest First"
			)
		case .distance:
			SortingOptionDisplay(
				title: "Distance",
				systemImage:
					"point.topleft.filled.down.to.point.bottomright.curvepath",
				ascendingSubtitle: "Nearest First",
				descendingSubtitle: "Farthest First"
			)
		}
	}

	/// Get sort descriptors with the specified order
	/// - Parameter order: The sorting order to apply
	/// - Returns: Array of sort descriptors for SwiftData queries
	func sortDescriptor(order: SortingOrder = .ascending) -> [SortDescriptor<
		ParkingFacility
	>] {
		let sortOrder: SortOrder = order == .ascending ? .forward : .reverse

		switch self {
		case .name:
			// Note: displayName is a computed property, so we sort by the actual name field
			// We also add facilityId as a tiebreaker to ensure stable, consistent sorting
			return [
				SortDescriptor(\.name, order: sortOrder),
				SortDescriptor(\.facilityId, order: sortOrder),
			]
		case .lastUpdated:
			// For lastUpdated, we typically want newest first as default
			// So when "ascending" is selected, we show oldest first
			// When "descending" is selected, we show newest first
			return [
				SortDescriptor(\.refreshStatus.lastUpdated, order: sortOrder),
				SortDescriptor(\.facilityId, order: sortOrder),
			]
		case .distance:
			// Sort by distance using sortableDistance (computed property that returns Double.infinity for nil) -> to avoid SwiftData's failure of sorting by an optional relationship
			// This ensures facilities without route data appear at the end
			return [
				SortDescriptor(\.sortableDistance, order: sortOrder),
				SortDescriptor(\.name, order: sortOrder),
				SortDescriptor(\.facilityId, order: sortOrder),
			]
		}
	}

	/// Legacy computed property for backward compatibility (uses ascending order)
	var sortDescriptor: [SortDescriptor<ParkingFacility>] {
		sortDescriptor(order: .ascending)
	}

	/// In-memory sorting comparator for ParkingFacility arrays
	/// - Parameters:
	///   - lhs: Left-hand side facility
	///   - rhs: Right-hand side facility
	///   - order: The sorting order (ascending or descending)
	/// - Returns: true if lhs should come before rhs
	func compare(
		_ lhs: ParkingFacility,
		_ rhs: ParkingFacility,
		order: SortingOrder = .ascending
	) -> Bool {
		let ascending: Bool

		switch self {
		case .name:
			// Sort by title first, then by subtitle if titles are equal
			let titleComparison = lhs.displayName.title
				.localizedStandardCompare(rhs.displayName.title)
			if titleComparison != .orderedSame {
				ascending = titleComparison == .orderedAscending
			} else {
				// Titles are equal, compare subtitles
				ascending =
					lhs.displayName.subtitle.localizedStandardCompare(
						rhs.displayName.subtitle
					) == .orderedAscending
			}

		case .lastUpdated:
			// For lastUpdated: ascending means oldest first, descending means newest first
			ascending =
				lhs.refreshStatus.lastUpdated < rhs.refreshStatus.lastUpdated

		case .distance:
			// Sort by distance with nil values at the end
			switch (lhs.route?.distance, rhs.route?.distance) {
			case (.none, .none):
				// Both nil: sort by name (title, then subtitle)
				let titleComparison = lhs.displayName.title
					.localizedStandardCompare(rhs.displayName.title)
				if titleComparison != .orderedSame {
					ascending = titleComparison == .orderedAscending
				} else {
					ascending =
						lhs.displayName.subtitle.localizedStandardCompare(
							rhs.displayName.subtitle
						) == .orderedAscending
				}
			case (.none, .some):
				// Left is nil: goes after (regardless of order)
				return order == .ascending ? false : false
			case (.some, .none):
				// Right is nil: goes after (regardless of order)
				return order == .ascending ? true : true
			case (.some(let lhsDistance), .some(let rhsDistance)):
				// Both have values: compare distances
				ascending = lhsDistance < rhsDistance
			}
		}

		// Apply the order
		return order == .ascending ? ascending : !ascending
	}

	/// Apply this sorting to an array of facilities with specified order
	/// - Parameters:
	///   - facilities: The facilities to sort
	///   - order: The sorting order to apply
	/// - Returns: Sorted array of facilities
	func apply(
		to facilities: [ParkingFacility],
		order: SortingOrder = .ascending
	) -> [ParkingFacility] {
		facilities.sorted { compare($0, $1, order: order) }
	}
}

enum SortingOrder: String, CaseIterable, Codable, Hashable,
	PickerOptionDisplayable
{
	case ascending
	case descending

	var display: SortingOrderDisplay {
		switch self {
		case .ascending:
			return SortingOrderDisplay(
				title: "Ascending",
				systemImage: "arrow.up"
			)
		case .descending:
			return SortingOrderDisplay(
				title: "Descending",
				systemImage: "arrow.down"
			)
		}
	}

	/// Toggle between ascending and descending
	mutating func toggle() {
		self = self == .ascending ? .descending : .ascending
	}

	/// Returns the opposite order
	var toggled: SortingOrder {
		self == .ascending ? .descending : .ascending
	}
}

enum FilterOption: String, CaseIterable, Codable, Hashable,
	PickerOptionDisplayable
{
	case pinned
	case available

	var display: FilterOptionDisplay {
		switch self {

		case .pinned:
			return
				FilterOptionDisplay(title: "Pinned", systemImage: "star")

		case .available:
			return
				FilterOptionDisplay(
					title: "Available",
					systemImage: "checkmark.circle.fill"
				)

		}
	}

	/// SwiftData Queries
	var filteringLogic: Predicate<ParkingFacility> {
		switch self {
		case .pinned: return #Predicate { $0.isFavourite }
		case .available:
			return #Predicate {
				// Use vacancy.available which is computed from totalSpaces - _cachedOccupied
				// Since we can't use computed properties in predicates, we need to compute it inline
				$0.totalSpaces - $0.vacancy.occupied > 0
			}
		}
	}

	/// In-memory filtering function for ParkingFacility arrays
	/// - Parameter facility: The facility to check
	/// - Returns: true if the facility matches this filter option
	func matches(_ facility: ParkingFacility) -> Bool {
		switch self {

		case .pinned:
			return facility.isFavourite
		case .available:
			return facility.vacancy.available > 0
				&& facility.availabilityStatus != .noData
		}
	}

	/// Apply this filter to an array of facilities
	/// - Parameter facilities: The facilities to filter
	/// - Returns: Filtered array of facilities
	func apply(to facilities: [ParkingFacility]) -> [ParkingFacility] {
		facilities.filter { matches($0) }
	}
}

// MARK: - Array Extensions for Convenience

extension Array where Element == ParkingFacility {
	/// Filter facilities by a filter option
	/// - Parameter filter: The filter to apply
	/// - Returns: Filtered array
	func filtered(by filter: FilterOption?) -> [ParkingFacility] {
		guard let filter else { return self }
		return filter.apply(to: self)
	}

	/// Sort facilities by a sorting option
	/// - Parameters:
	///   - sorting: The sorting option to apply
	///   - order: The sorting order (ascending or descending)
	/// - Returns: Sorted array
	func sorted(by sorting: SortingOption, order: SortingOrder = .ascending)
		-> [ParkingFacility]
	{
		sorting.apply(to: self, order: order)
	}

	/// Filter by search text across name and suburb
	/// - Parameter searchText: The text to search for
	/// - Returns: Filtered array matching the search text
	func searchFiltered(by searchText: String) -> [ParkingFacility] {
		guard !searchText.isEmpty else { return self }

		return filter { facility in
			facility.displayName.title.localizedCaseInsensitiveContains(
				searchText
			)
				|| facility.displayName.subtitle
					.localizedCaseInsensitiveContains(searchText)
				|| facility.suburb.localizedCaseInsensitiveContains(searchText)
		}
	}

	/// Apply filter, search, and sorting in one go
	/// - Parameters:
	///   - filter: The filter option to apply
	///   - searchText: Optional search text (empty string means no search)
	///   - sorting: The sorting option to apply
	///   - order: The sorting order (ascending or descending)
	/// - Returns: Filtered, searched, and sorted array
	func filtered(
		by filter: FilterOption,
		searchText: String = "",
		sortedBy sorting: SortingOption,
		order: SortingOrder = .ascending
	) -> [ParkingFacility] {
		self
			.filtered(by: filter)
			.searchFiltered(by: searchText)
			.sorted(by: sorting, order: order)
	}
}
