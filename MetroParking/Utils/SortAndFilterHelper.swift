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

struct FilterOptionDisplay: BasicDisplayable {
	let title: String
	let systemImage: String
}

enum SortingOption: String, CaseIterable, Codable, Hashable, PickerOptionDisplayable {
	case name
	case lastUpdated
	case distance

	var display: SortingOptionDisplay {
		switch self {
		case .name:
			SortingOptionDisplay(
				title: "Name",
				systemImage: "text.justifyleft",
				ascendingSubtitle: "A to Z",
				descendingSubtitle: "Z to A"
			)
		case .lastUpdated:
			SortingOptionDisplay(
				title: "Last Updated",
				systemImage: "clock",
				ascendingSubtitle: "Oldest First",
				descendingSubtitle: "Newest First"
			)
		case .distance:
			SortingOptionDisplay(
				title: "Distance",
				systemImage: "map",
				ascendingSubtitle: "Nearest First",
				descendingSubtitle: "Farthest First"
			)
		}
	}

	var sortDescriptor: [SortDescriptor<ParkingFacility>] {
		switch self {
		case .name:
			[SortDescriptor(\.displayName)]
		case .lastUpdated:
			[SortDescriptor(\.lastUpdated, order: .reverse)]
		case .distance:
			// Sort by distance with nil values at the end
			// Then by name as a secondary sort for nil values
			[
				SortDescriptor(\.lastCalculatedDistance, order: .forward),
				SortDescriptor(\.displayName)
			]
		}
	}
	
	/// In-memory sorting comparator for ParkingFacility arrays
	/// - Parameters:
	///   - lhs: Left-hand side facility
	///   - rhs: Right-hand side facility
	/// - Returns: true if lhs should come before rhs
	func compare(_ lhs: ParkingFacility, _ rhs: ParkingFacility) -> Bool {
		switch self {
		case .name:
			return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
			
		case .lastUpdated:
			// Newest first (reverse order)
			return lhs.lastUpdated > rhs.lastUpdated
			
		case .distance:
			// Sort by distance with nil values at the end
			switch (lhs.lastCalculatedDistance, rhs.lastCalculatedDistance) {
			case (.none, .none):
				// Both nil: sort by name
				return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
			case (.none, .some):
				// Left is nil: goes after
				return false
			case (.some, .none):
				// Right is nil: goes after
				return true
			case (.some(let lhsDistance), .some(let rhsDistance)):
				// Both have values: compare distances
				return lhsDistance < rhsDistance
			}
		}
	}
	
	/// Apply this sorting to an array of facilities
	/// - Parameter facilities: The facilities to sort
	/// - Returns: Sorted array of facilities
	func apply(to facilities: [ParkingFacility]) -> [ParkingFacility] {
		facilities.sorted(by: compare)
	}
}
enum FilterOption: String, CaseIterable, Codable, Hashable, PickerOptionDisplayable {
	case all
	case pinned
	case available
	case recent

	var display: FilterOptionDisplay {
		switch self {
		case .all:
			return
				FilterOptionDisplay(
					title: "All",
					systemImage: "parkingsign.square"
				)

		case .pinned:
			return
				FilterOptionDisplay(title: "Pinned", systemImage: "star")

		case .available:
			return
				FilterOptionDisplay(
					title: "Available",
					systemImage: "checkmark.circle"
				)

		case .recent:
			return
				FilterOptionDisplay(
					title: "Recent",
					systemImage: "clock.arrow.circlepath"
				)

		}
	}

	/// SwiftData Queries
	var filteringLogic: Predicate<ParkingFacility> {
		switch self {
		case .all: return #Predicate { _ in true }
		case .pinned: return #Predicate { $0.isFavourite }
		case .available:
			return #Predicate {
				$0.currentAvailableSpots > 0
			}
		case .recent:
			return #Predicate {
				$0.lastVisited != nil
			}
		}
	}
	
	/// In-memory filtering function for ParkingFacility arrays
	/// - Parameter facility: The facility to check
	/// - Returns: true if the facility matches this filter option
	func matches(_ facility: ParkingFacility) -> Bool {
		switch self {
		case .all:
			return true
		case .pinned:
			return facility.isFavourite
		case .available:
			return facility.currentAvailableSpots > 0
		case .recent:
			return facility.lastVisited != nil
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
	func filtered(by filter: FilterOption) -> [ParkingFacility] {
		filter.apply(to: self)
	}

		/// Sort facilities by a sorting option
		/// - Parameter sorting: The sorting option to apply
		/// - Returns: Sorted array
	func sorted(by sorting: SortingOption) -> [ParkingFacility] {
		sorting.apply(to: self)
	}

		/// Filter by search text across name and suburb
		/// - Parameter searchText: The text to search for
		/// - Returns: Filtered array matching the search text
	func searchFiltered(by searchText: String) -> [ParkingFacility] {
		guard !searchText.isEmpty else { return self }

		return filter { facility in
			facility.displayName.localizedCaseInsensitiveContains(searchText) ||
			facility.suburb.localizedCaseInsensitiveContains(searchText)
		}
	}

		/// Apply filter, search, and sorting in one go
		/// - Parameters:
		///   - filter: The filter option to apply
		///   - searchText: Optional search text (empty string means no search)
		///   - sorting: The sorting option to apply
		/// - Returns: Filtered, searched, and sorted array
	func filtered(
		by filter: FilterOption,
		searchText: String = "",
		sortedBy sorting: SortingOption
	) -> [ParkingFacility] {
		self
			.filtered(by: filter)
			.searchFiltered(by: searchText)
			.sorted(by: sorting)
	}
}
