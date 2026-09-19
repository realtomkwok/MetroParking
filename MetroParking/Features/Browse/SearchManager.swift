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
}
