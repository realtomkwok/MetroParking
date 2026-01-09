//
//  FacilityEntity.swift
//  MetroParking
//
//  Created by Tom Kwok on 17/12/2025.
//

import AppIntents
import Foundation
import SwiftData
import OSLog

/// Represents a parking facility as an AppEntity for widget configuration
struct FacilityEntity: AppEntity, Identifiable {
	static var typeDisplayRepresentation: TypeDisplayRepresentation = "Carpark"
	static var defaultQuery = FacilityQuery()

	let id: String
	let name: String
	let displayTitle: String
	let displaySubtitle: String

	var displayRepresentation: DisplayRepresentation {
		DisplayRepresentation(
			title: "\(displayTitle)",
			subtitle: displaySubtitle.isEmpty ? nil : "\(displaySubtitle)"
		)
	}

	init(from facility: ParkingFacility) {
		self.id = facility.facilityId
		self.name = facility.name
		self.displayTitle = facility.displayName.title
		self.displaySubtitle = facility.displayName.subtitle
	}
}

/// Query to fetch available parking facilities
struct FacilityQuery: EntityStringQuery {
	func entities(for identifiers: [String]) async throws -> [FacilityEntity] {
		let container = await SharedDataManager.sharedContainer
		let context = ModelContext(container)

		let descriptor = FetchDescriptor<ParkingFacility>(
			predicate: #Predicate { facility in
				identifiers.contains(facility.facilityId)
			},
			sortBy: [SortDescriptor(\.name, order: .forward)]
		)

		do {
			let facilities = try context.fetch(descriptor)
			return facilities.map { FacilityEntity(from: $0) }
		} catch {
			Logger.widget.error("❌ Failed to fetch facilities for identifiers: \(error)")
			return []
		}
	}


	func entities(matching string: String) async throws -> [FacilityEntity] {
			// Fetch specific facilities by ID
		let container = await SharedDataManager.sharedContainer
		let context = ModelContext(container)

		let descriptor = FetchDescriptor<ParkingFacility>(
			predicate: #Predicate { facility in
				facility.name.localizedStandardContains(string)
			},
			sortBy: [SortDescriptor(\.name, order: .forward)]
		)

		do {
			let facilities = try context.fetch(descriptor)
			return facilities.map { FacilityEntity(from: $0) }
		} catch {
			Logger
				.widget.info(
					"❌ No facilities found matching '\(string)'. Error : \(error)"
				)
			return []
		}
	}

	func suggestedEntities() async throws -> [FacilityEntity] {
			// Return all available facilities for selection
		let container = await SharedDataManager.sharedContainer
		let context = ModelContext(container)

		let descriptor = FetchDescriptor<ParkingFacility>(
			sortBy: [
//				SortDescriptor(\.isFavourite, order: .reverse),
				// Favorites first
				SortDescriptor(\.name, order: .forward)
			]
		)

		do {
			let facilities = try context.fetch(descriptor)
			return facilities.map { FacilityEntity(from: $0) }
		} catch {
			print("❌ Failed to fetch suggested facilities: \(error)")
			return []
		}
	}

	func defaultResult() async -> FacilityEntity? {
			// Return the first favourite facility, or nil if none exists
		let container = await SharedDataManager.sharedContainer
		let context = ModelContext(container)

		let descriptor = FetchDescriptor<ParkingFacility>(
			predicate: #Predicate { $0.isFavourite == true },
			sortBy: [SortDescriptor(\.lastVisited, order: .reverse)]
		)

		do {
			let favorites = try context.fetch(descriptor)
			return favorites.first.map { FacilityEntity(from: $0) }
		} catch {
			print("❌ Failed to fetch default facility: \(error)")
			return nil
		}
	}
}
