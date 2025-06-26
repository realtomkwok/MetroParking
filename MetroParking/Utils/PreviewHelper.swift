//
//  PreviewHelper.swift
//  MetroParking
//
//  Created by Tom Kwok on 26/6/2025.
//

import Foundation
import SwiftUI
import SwiftData

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


extension PreviewHelper {
	
	/// Creates a preview container using the static data
	@MainActor static func previewContainer(withSamplePins: Bool = true) -> ModelContainer {
		do {
			
			/// In-memory container
			let config = ModelConfiguration(isStoredInMemoryOnly: true)
			let container = try ModelContainer(for: ParkingFacility.self, configurations: config)
			let context = container.mainContext
			
			loadAllStaticFacilities(into: context)
			
			if withSamplePins {
				addSamplePinnedFacilities(to: context)
			}
			
			try context.save()
			return container
			
		} catch {
			fatalError("Failed to create preview container: \(error)")
		}
	}
	
	/// Load all static facilities (same as FacilityDataManager does)
	private static func loadAllStaticFacilities(into context: ModelContext) {
		let userLocation = (lat: -33.8688, lon: 151.2093) // Sydney CBD
		let staticFacilities = ParkingFacility.getFacilitiesSortedByDistance(from: userLocation)
		
		for staticInfo in staticFacilities {
			let facility = ParkingFacility(from: staticInfo)
			context.insert(facility)
		}
		
		print("📦 Preview: Loaded \(staticFacilities.count) static facilities")
	}
	
	/// Add some realistic pinned facilities with varied occupancy
	private static func addSamplePinnedFacilities(to context: ModelContext) {
		let descriptor = FetchDescriptor<ParkingFacility>()
		
		do {
			let allFacilities = try context.fetch(descriptor)
			
			// Pin some realistic facilities with varied data
			let facilitiesToPin = [
				(name: "Kiama", occupancyRatio: 0.95),           // Almost full, small facility
				(name: "Gosford", occupancyRatio: 0.3),          // Available, large facility
				(name: "Leppington", occupancyRatio: 1.0),       // Full, very large facility
				(name: "Gordon", occupancyRatio: 0.6),           // Moderate, medium facility
			]
			
			for (facilityName, occupancyRatio) in facilitiesToPin {
				if let facility = allFacilities.first(where: { $0.name.contains(facilityName) }) {
					facility.isFavourite = true
					
						// Set realistic occupancy data
					if occupancyRatio > 0 {
						facility.currentOccupancy = Int(Double(facility.totalSpaces) * occupancyRatio)
					}
				}
			}
			
			print("📌 Preview: Pinned \(facilitiesToPin.count) sample facilities")
			
		} catch {
			print("❌ Preview: Failed to add sample pins: \(error)")
		}
	}
}
