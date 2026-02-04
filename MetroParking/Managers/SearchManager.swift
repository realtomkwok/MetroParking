//
//  SearchManager.swift
//  MetroParking
//
//  Created by Tom Kwok on 18/1/2026.
//

import Foundation

@MainActor
@Observable
final class SearchManager {

	static let shared = SearchManager()

	var searchText: String = ""
	var isSearching: Bool = false

	private init() {}

	// MARK: - Search Suggestions

	/// Returns unique suburbs matching the current search text
	/// Only returns suggestions when search text is 2+ characters
	/// - Parameter facilities: Array of facilities to extract suburbs from
	/// - Returns: Up to 5 matching suburb names, sorted alphabetically
	func suburbSuggestions(from facilities: [ParkingFacility]) -> [String] {
		guard searchText.count >= 2 else { return [] }

		let uniqueSuburbs = Set(facilities.map { $0.location.suburb })
		return uniqueSuburbs
			.filter { $0.localizedCaseInsensitiveContains(searchText) }
			.sorted()
			.prefix(5)
			.map { $0 }
	}
}
