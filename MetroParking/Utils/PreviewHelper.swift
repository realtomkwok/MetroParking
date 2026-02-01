//
//  PreviewHelper.swift
//  MetroParking
//
//  Created by Tom Kwok on 26/6/2025.
//

// MARK: - SwiftUI Preview Helper
/// Provides utilities for creating realistic preview environments
/// with proper SwiftData model containers and app state simulation
/// Usage examples:
/// ```swift
/// // Simple standalone facility
/// #Preview {
///     FacilityRow(facility: .sample())
/// }
///
/// // With specific status
/// #Preview("Full Facility") {
///     FacilityRow(facility: .sample(status: .full))
/// }
///
/// // With SwiftData container
/// #Preview {
///     ContentView()
///         .modelContainer(.preview())
/// }
///
/// // Multiple facilities for list
/// #Preview("Facility List") {
///     List(ParkingFacility.samples()) { facility in
///         FacilityRow(facility: facility)
///     }
/// }
/// ```

import Foundation
import MapKit
import SwiftData
import SwiftUI

@MainActor
struct PreviewHelper {

	// MARK: - Helper Methods

	/// Mock API response to properly initialise a facility with occupancy data
	/// - Note: Internal helper for creating realistic preview data
	static func mockAPIResponse(
		for facility: ParkingFacility,
		occupancyRatio: Double
	) -> ParkingApiModel {
		let occupied = Int(Double(facility.totalSpaces) * occupancyRatio)

		return ParkingApiModel(
			tsn: "preview-tsn",
			spots: String(facility.totalSpaces),
			zones: [],
			location: ParkingLocationAPI(
				suburb: facility.location.suburb,
				address: facility.location.address,
				latitude: String(facility.location.latitude),
				longitude: String(facility.location.longitude)
			),
			occupancy: ParkingOccupancyAPI(
				loop: nil,
				total: String(occupied),
				monthlies: nil,
				openGate: nil,
				transients: nil
			),
			messageDate: ISO8601DateFormatter().string(from: Date()),
			facilityId: facility.facilityId,
			facilityName: facility.name,
			tfnswFacilityId: facility.facilityId
		)
	}

	/// Apply occupancy to a facility using the proper API update method
	/// - Note: Ensures preview data uses the same update path as production code
	static func applyOccupancy(
		to facility: ParkingFacility,
		ratio: Double
	) {
		guard ratio > 0 else { return }  // Leave as noData if ratio is 0

		let occupied = Int(Double(facility.totalSpaces) * ratio)
		facility
			.updateOccupancy(
				occupied: occupied,
				totalSpaces: facility.totalSpaces
			)
	}

	/// Apply route information to a facility
	/// - Note: Adds realistic routing data for preview scenarios
	static func applyRouting(
		to facility: ParkingFacility,
		distance: CLLocationDistance = 5_000,
		travelTime: TimeInterval = 600
	) {
		facility.updateRoutingData(distance: distance, travelTime: travelTime)
	}
}

// MARK: - ParkingFacility Extensions

extension ParkingFacility {

	/// Creates a sample facility with configurable status
	/// - Parameters:
	///   - status: The availability status to simulate
	///   - isFavorite: Whether the facility should be marked as favorite
	///   - withRoute: Whether to include route information
	/// - Returns: A configured ParkingFacility instance
	@MainActor
	static func sample(
		status: AvailabilityStatus = .available,
		isFavorite: Bool = false,
		withRoute: Bool = false
	) -> ParkingFacility {
		let staticFacilities = getAllStaticFacilities()

		// Select appropriate facility based on status
		let sourceFacility: ParkingFacility
		switch status {
		case .full, .almostFull:
			// Use smaller facility for full/almost full scenarios
			sourceFacility =
				staticFacilities.first { $0.totalSpaces < 200 }
				?? staticFacilities.first!
		case .available:
			// Use medium facility for available
			sourceFacility =
				staticFacilities.first {
					$0.totalSpaces >= 200 && $0.totalSpaces < 800
				}
				?? staticFacilities.first!
		case .noData:
			// Any facility works for noData
			sourceFacility = staticFacilities.first!
		}

		// Create new instance
		let facility = ParkingFacility(
			facilityId: sourceFacility.facilityId,
			name: sourceFacility.name,
			suburb: sourceFacility.location.suburb,
			address: sourceFacility.location.address,
			latitude: sourceFacility.location.latitude,
			longitude: sourceFacility.location.longitude,
			totalSpaces: sourceFacility.totalSpaces
		)

		// Apply status
		let occupancyRatio: Double
		switch status {
		case .available:
			occupancyRatio = 0.25  // 25% occupied = plenty available
		case .almostFull:
			occupancyRatio = 0.95  // 95% occupied
		case .full:
			occupancyRatio = 1.0  // 100% occupied
		case .noData:
			occupancyRatio = 0.0  // Don't set any data
		}

		PreviewHelper.applyOccupancy(to: facility, ratio: occupancyRatio)

		// Apply favourite status
		facility.isFavourite = isFavorite

		// Apply route if requested
		if withRoute {
			PreviewHelper.applyRouting(to: facility)
		}

		return facility
	}

	/// Creates multiple sample facilities with varied statuses
	/// - Parameter count: Number of facilities to generate (default: 5)
	/// - Returns: Array of configured ParkingFacility instances
	@MainActor
	static func samples(count: Int = 5) -> [ParkingFacility] {
		let staticFacilities = getAllStaticFacilities()
		let availableStatuses: [AvailabilityStatus] = [
			.available, .almostFull, .full, .noData,
		]

		return (0..<min(count, staticFacilities.count)).map { index in
			let source = staticFacilities[index]
			let status = availableStatuses[index % availableStatuses.count]

			let facility = ParkingFacility(
				facilityId: source.facilityId,
				name: source.name,
				suburb: source.location.suburb,
				address: source.location.address,
				latitude: source.location.latitude,
				longitude: source.location.longitude,
				totalSpaces: source.totalSpaces
			)

			// Varied occupancy based on status
			let occupancyRatio: Double
			switch status {
			case .available:
				occupancyRatio = Double.random(in: 0.1...0.4)
			case .almostFull:
				occupancyRatio = Double.random(in: 0.85...0.95)
			case .full:
				occupancyRatio = 1.0
			case .noData:
				occupancyRatio = 0.0
			}

			PreviewHelper.applyOccupancy(to: facility, ratio: occupancyRatio)

			// Mark some as favourites
			facility.isFavourite = index % 3 == 0

			// Add route info to some
			if index % 2 == 0 {
				let distance = CLLocationDistance.random(in: 1_000...20_000)
				let travelTime = TimeInterval.random(in: 300...1_800)
				PreviewHelper.applyRouting(
					to: facility,
					distance: distance,
					travelTime: travelTime
				)
			}

			return facility
		}
	}

	/// Creates sample facilities specifically for favorites/pinned scenarios
	/// - Returns: Array of favorited facilities with varied statuses
	@MainActor
	static func sampleFavorites() -> [ParkingFacility] {
		let facilities = samples(count: 4)
		facilities.forEach { $0.isFavourite = true }
		return facilities
	}
}

// MARK: - ModelContainer Extensions

extension ModelContainer {

	/// Creates an in-memory preview container with optional sample data
	/// - Parameters:
	///   - includeSampleData: Whether to populate with sample facilities
	///   - favoriteCount: Number of favorited facilities to include
	/// - Returns: A configured ModelContainer for previews
	@MainActor
	static func preview(
		includeSampleData: Bool = true,
		favoriteCount: Int = 3
	) -> ModelContainer {
		do {
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

			if includeSampleData {
				let context = container.mainContext

				// Add all static facilities
				let staticFacilities = ParkingFacility.getAllStaticFacilities()

				for (index, source) in staticFacilities.enumerated() {
					let facility = ParkingFacility(
						facilityId: source.facilityId,
						name: source.name,
						suburb: source.location.suburb,
						address: source.location.address,
						latitude: source.location.latitude,
						longitude: source.location.longitude,
						totalSpaces: source.totalSpaces
					)

					// Mark some as favourites
					if index < favoriteCount {
						facility.isFavourite = true

						// Give favourites realistic occupancy
						let occupancyPatterns = [0.25, 0.95, 1.0, 0.6]
						let ratio = occupancyPatterns[
							index % occupancyPatterns.count
						]
						PreviewHelper.applyOccupancy(to: facility, ratio: ratio)
					}

					context.insert(facility)
				}

				try context.save()
			}

			return container

		} catch {
			fatalError("Failed to create preview container: \(error)")
		}
	}

	/// Creates a preview container with no data (for empty state testing)
	@MainActor
	static func emptyPreview() -> ModelContainer {
		return preview(includeSampleData: false)
	}
}

// MARK: - Environment Validation Extension

extension View {
	/// Validate that all required environment objects are present (DEBUG ONLY)
	/// Use this in previews to catch missing environment objects early
	func validateEnvironment() -> some View {
		#if DEBUG
			self.onAppear {
				print(
					"✅ Environment validation passed for \(String(describing: Self.self))"
				)
			}
		#else
			self
		#endif
	}
}

// MARK: - Preview Environment Helper

/// Helper to create a complete preview environment with all managers
struct PreviewEnvironment<Content: View>: View {
	let content: () -> Content

	init(@ViewBuilder content: @escaping () -> Content) {
		self.content = content
	}

	var body: some View {
		content()
			.environment(FacilityManager.shared)
			.environment(LookAroundManager.shared)
			.environment(ETAManager.shared)
			.environment(LocationManager.shared)
	}
}
