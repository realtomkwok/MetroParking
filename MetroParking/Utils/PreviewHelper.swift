//
//  PreviewHelper.swift
//  MetroParking
//
//  Created by Tom Kwok on 26/6/2025.
//

// MARK: - SwiftUI Preview Helper
// Provides utilities for creating realistic preview environments
// with proper SwiftData model containers and app state simulation

import Foundation
import SwiftData
import SwiftUI

struct PreviewHelper {

	/// Select facilities by their sizes
	private static var smallFacility: ParkingFacility {
		return ParkingFacility.getAllStaticFacilities()
			.filter { $0.totalSpaces < 100 }
			.first ?? ParkingFacility.getAllStaticFacilities().first!
	}

	private static var mediumFacility: ParkingFacility {
		return ParkingFacility.getAllStaticFacilities()
			.filter { $0.totalSpaces >= 100 && $0.totalSpaces <= 500 }
			.first ?? ParkingFacility.getAllStaticFacilities().first!
	}

	private static var largeFacility: ParkingFacility {
		return ParkingFacility.getAllStaticFacilities()
			.filter { $0.totalSpaces > 1000 }
			.first ?? ParkingFacility.getAllStaticFacilities().first!
	}
}

extension PreviewHelper {

	/// Helper to create a new facility instance from a source facility
	private static func createFacilityCopy(from source: ParkingFacility) -> ParkingFacility {
		return ParkingFacility(
			facilityId: source.facilityId,
			name: source.name,
			suburb: source.suburb,
			address: source.address,
			latitude: source.latitude,
			longitude: source.longitude,
			totalSpaces: source.totalSpaces,
		)
	}

	/// Scenarios
	/// 🟢 Available - medium facility
	static func availableFacility() -> ParkingFacility {
		let facility = createFacilityCopy(from: mediumFacility)

		/// Simulate 20% occupancy
		let occupancy = Int(Double(facility.totalSpaces) * 0.2)
		facility.currentOccupiedSpots = occupancy

		return facility
	}

	/// 🟡 Almost-full - small facility
	static func almostFullFacility() -> ParkingFacility {
		let facility = createFacilityCopy(from: smallFacility)

		/// Simulate 95% occupancy
		let occupancy = Int(Double(facility.totalSpaces) * 0.95)
		facility.currentOccupiedSpots = occupancy

		return facility
	}

	/// 🔴 Full - large facility
	static func fullFacility() -> ParkingFacility {
		let facility = createFacilityCopy(from: largeFacility)

		facility.currentOccupiedSpots = facility.totalSpaces

		return facility
	}

	/// ⚪️ No recent data (cache expired)
	static func noDataFacility() -> ParkingFacility {
		let facility = createFacilityCopy(from: smallFacility)

		/// `CurrentOccupancy` is undefined, and cache remains invalid
		return facility
	}
}

extension PreviewHelper {

	/// A list of pinned parking facilities
	static func pinnedFacilities() -> [ParkingFacility] {
		let facilities = ParkingFacility.getAllStaticFacilities()

		/// Get one facility from each size category
		let small = facilities.first { $0.totalSpaces < 100 }
		let medium = facilities.first {
			$0.totalSpaces >= 100 && $0.totalSpaces < 500
		}
		let large = facilities.first { $0.totalSpaces >= 500 }

		let selectedFacilities = [small, medium, large].compactMap { $0 }

		return selectedFacilities.enumerated().map { index, sourceFacility in
			// Create a new copy for each facility
			let facility = createFacilityCopy(from: sourceFacility)
			facility.isFavourite = true
			setVariedOccupancy(facility: facility, index: index)
			return facility
		}
	}
}

// MARK: - ContentView Preview Scenarios

/// Different app states for ContentView previews
enum ContentViewAppState {
	case normal
	case facilitySelected
	case loading
	case noData
}

extension PreviewHelper {

	/// Set a varied occupancy for a certain facility
	private static func setVariedOccupancy(
		facility: ParkingFacility,
		index: Int
	) {
		let patterns: [Double] = [0.2, 0.95, 1.0, 0.6, 0.0]  // Available, Almost Full, Moderate, No Data

		if index < patterns.count {
			let occupancyRatio = patterns[index]
			if occupancyRatio > 0 {
				facility.currentOccupiedSpots = Int(
					Double(facility.totalSpaces) * occupancyRatio
				)
			}
			// If occupancyRatio is 0, don't set occupancy (no data state) ?
		} else {
			// For additional facilities beyond the pattern, use random
			facility.currentOccupiedSpots = Int(
				Double(facility.totalSpaces) * Double.random(in: 0.1...0.9)
			)

		}
	}
}

extension PreviewHelper {

	/// Creates a preview container using the static data
	@MainActor static func previewContainer(withSamplePins: Bool = true)
		-> ModelContainer
	{
		do {
			/// In-memory container with proper schema
			let schema = Schema([
				ParkingFacility.self,
				ParkingZone.self,
			])
			let config = ModelConfiguration(
				schema: schema,
				isStoredInMemoryOnly: true
			)
			let container = try ModelContainer(
				for: schema,
				configurations: [config]
			)

			// Don't configure FacilityManager or add sample data during initialization
			// This prevents race conditions and context conflicts
			
			if withSamplePins {
				let context = container.mainContext
				addSamplePinnedFacilities(to: context)
				try context.save()
			}

			return container

		} catch {
			fatalError("Failed to create preview container: \(error.localizedDescription)")
		}
	}

	/// Creates a fully initialized preview container that mimics the production app setup
	@MainActor static func initializedPreviewContainer(withSamplePins: Bool = true) -> ModelContainer {
		let container = previewContainer(withSamplePins: withSamplePins)
		
		// Simulate the app's initialization sequence
		Task {
			await FacilityManager.shared.loadStaticFacilitiesIfNeeded()
		}
		
		return container
	}
	
	/// Creates a preview-ready FacilityManager configured with the given container
	@MainActor static func previewFacilityManager(for container: ModelContainer) -> FacilityManager {
		let manager = FacilityManager.shared
		manager.setModelContext(container.mainContext)
		return manager
	}

	/// Add some realistic pinned facilities with varied occupancy
	private static func addSamplePinnedFacilities(to context: ModelContext) {
		// Get the static facility data (not SwiftData objects)
		let staticFacilityData = ParkingFacility.getAllStaticFacilities()
		
		// Pin some realistic facilities with varied data
		let facilitiesToPin = [
			(name: "Kiama", occupancyRatio: 0.95),  // Almost full, small facility
			(name: "Gosford", occupancyRatio: 0.3),  // Available, large facility
			(name: "Leppington", occupancyRatio: 1.0),  // Full, very large facility
			(name: "Gordon", occupancyRatio: 0.6),  // Moderate, medium facility
		]

		// Create new facility instances directly in the context
		for staticData in staticFacilityData {
			// Create a new facility instance for this context
			let facility = ParkingFacility(
				facilityId: staticData.facilityId,
				name: staticData.name,
				suburb: staticData.suburb,
				address: staticData.address,
				latitude: staticData.latitude,
				longitude: staticData.longitude,
				totalSpaces: staticData.totalSpaces,
			)
			
			// Check if this facility should be pinned
			if let pinConfig = facilitiesToPin.first(where: { staticData.name.contains($0.name) }) {
				facility.isFavourite = true
				
				// Set realistic occupancy data
				if pinConfig.occupancyRatio > 0 {
					facility.currentOccupiedSpots = Int(
						Double(facility.totalSpaces) * pinConfig.occupancyRatio
					)
				}
			}
			
			// Insert into context
			context.insert(facility)
		}

		print(
			"📌 Preview: Created \(staticFacilityData.count) facilities and pinned \(facilitiesToPin.count) sample facilities"
		)
	}
}
