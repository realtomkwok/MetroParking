//
//  FacilityQueries.swift
//  MetroParking
//
//  Created by Tom Kwok on 21/9/2026.
//

import Foundation
import SwiftData

/// One-shot facility lookups for code that isn't a view and so can't use `@Query`.
///
/// Both swallow fetch failures: every caller is framing a map or resolving a deep
/// link, where an empty result and an unreadable store want the same handling.
extension ModelContext {
	/// Every facility in the store.
	func allFacilities() -> [ParkingFacility] {
		(try? fetch(FetchDescriptor<ParkingFacility>())) ?? []
	}

	/// The facility with this ID, or `nil` if the store has never seen it.
	func facility(id facilityId: String) -> ParkingFacility? {
		var descriptor = FetchDescriptor<ParkingFacility>(
			predicate: #Predicate { $0.facilityId == facilityId }
		)
		descriptor.fetchLimit = 1
		return try? fetch(descriptor).first
	}
}
