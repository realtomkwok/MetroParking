//
//  PreviewHelper.swift
//  MetroParking
//
//  Created by Tom Kwok on 26/6/2025.
//

import Foundation
import SwiftUI

struct PreviewHelper {
	
	/// Select facilities by their sizes
	private static var smallFacility: StaticFacilityInfo {
		return ParkingFacility.getAllStaticFacilities()
			.filter { $0.totalSpaces < 100 }
			.first ?? ParkingFacility.getAllStaticFacilities().first!
	}
	
	private static var mediumFacility: StaticFacilityInfo {
		return ParkingFacility.getAllStaticFacilities()
			.filter { $0.totalSpaces >= 100 && $0.totalSpaces <= 500}
			.first ?? ParkingFacility.getAllStaticFacilities().first!
	}
	
	private static var largeFacility: StaticFacilityInfo {
		return ParkingFacility.getAllStaticFacilities()
			.filter { $0.totalSpaces > 1000 }
			.first ?? ParkingFacility.getAllStaticFacilities().first!
	}
}

extension PreviewHelper {
	
	/// Scenerios
	/// 🟢 Available - medium facility
	static func availableFacility() -> ParkingFacility {
		let facility = ParkingFacility(from: mediumFacility)
		
		/// Simulate 20% occupancy
		let occupancy = Int(Double(facility.totalSpaces) * 0.2)
		facility.currentOccupancy = occupancy
		
		return facility
	}
	
	/// 🟡 Almost-full - small facility
	static func almostFullFacility() -> ParkingFacility {
		let facility = ParkingFacility(from: smallFacility)
		
		/// Simulate 95% occupancy
		let occupancy = Int(Double(facility.totalSpaces) * 0.95)
		facility.currentOccupancy = occupancy
		
		return facility
	}
	
	/// 🔴 Full - large facility
	static func fullFacility() -> ParkingFacility {
		let facility = ParkingFacility(from: largeFacility)
		
		facility.currentOccupancy = facility.totalSpaces
		
		return facility
	}
	
	/// ⚪️ No recent data (cache expired)
	static func noDataFacility() -> ParkingFacility {
		let facility = ParkingFacility(from: smallFacility)
		
		/// `CurrentOccupancy` is undefined, and cache remains invalid
		return facility
	}
}

extension PreviewHelper {
	
	/// A list of pinned parking facilities
	static func pinnedFacilities() -> [ParkingFacility] {
		let facilities = ParkingFacility.getAllStaticFacilities()
		
		/// Get one facility from each size category
		let small = facilities.first {$0.totalSpaces < 100 }
		let medium = facilities.first { $0.totalSpaces >= 100 && $0.totalSpaces < 500}
		let large = facilities.first { $0.totalSpaces >= 500 }
		
		let selectedFacilities = [small, medium, large].compactMap { $0 }
		
		return selectedFacilities.enumerated().map { index, facilities in
			let facility = ParkingFacility(from: facilities)
			facility.isFavourite = true
			setVariedOccupancy(facility: facility, index: index)
			return facility
		}
	}
}

// TODO: Add edge cases


extension PreviewHelper {
	
	/// Set a varied occupancy for a certain facility
	private static func setVariedOccupancy(facility: ParkingFacility, index: Int) {
		let patterns: [Double] = [0.2, 0.95, 1.0, 0.6, 0.0]		// Available, Almost Full, Moderate, No Data
		
		if index < patterns.count {
			let occupancyRatio = patterns[index]
			if occupancyRatio > 0 {
				facility.currentOccupancy = Int(Double(facility.totalSpaces) * occupancyRatio)
			}
			// If occupancyRatio is 0, don't set occupancy (no data state) ?
		} else {
			// For additional facilities beyond the pattern, use random
			facility.currentOccupancy = Int(Double(facility.totalSpaces) * Double.random(in: 0.1...0.9))

		}
	}
}
