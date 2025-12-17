//
//  SharedDataManager.swift
//  MetroParking
//
//  Created by Tom Kwok on 16/12/2025.
//

import Foundation
import SwiftData
import WidgetKit
import OSLog

class SharedDataManager {

	// App Group
	static let appGroupIdentifier: String = "group.com.tomkwok.metroparking"

	static var shared = SharedDataManager()

	private init() {}

	// MARK: - SwiftData Container
	@MainActor
	static func makeSharedContainer() -> ModelContainer {
		let schema = Schema([
			ParkingFacility.self,
			ParkingZone.self,
		])

		let modelConfiguration = ModelConfiguration(
			schema: schema,
			isStoredInMemoryOnly: false,
			groupContainer: .identifier(appGroupIdentifier)
		)

		do {
			return try ModelContainer(
				for: schema,
				configurations: modelConfiguration
			)
		} catch {
			fatalError("Could not create ModelContainer: \(error)")
		}
	}

	// MARK: - Widget Data cache
	/// Cache structure
	struct WidgetFacilityData: Codable {
		let facilityId: String
		let name: String
		let displayTitle: String
		let displaySubtitle: String
		let address: String

		// Vacancy
		let availableSpaces: Int
		let totalSpaces: Int
		let occupancyRatio: Double
		let availabilityStatus: String  // "available", "almostFull", "full", "noData" -> as AvailabilityStatus is not codable

		// Route
		let distance: Double?
		let travelTime: TimeInterval?

		// Metadata
		let lastUpdated: Date
		let cacheTimestamp: Date

		var statusColour: String {
			switch availabilityStatus {
			case "available": return "green"
			case "almostFull": return "yellow"
			case "full": return "red"
			default: return "gray"
			}
		}
	}

	/// Get the shared UserDefaults for App Group
	private var sharedDefaults: UserDefaults? {
		UserDefaults(suiteName: Self.appGroupIdentifier)
	}
}

extension SharedDataManager {
		// MARK: - Widget data
	func saveWidgetData(_ data: WidgetFacilityData) {
		guard let defaults = sharedDefaults else {
			Logger.widget.error("❌ Failed to access shared UserDefaults")
			return
		}

		do {
			let encoder = JSONEncoder()
			encoder.dateEncodingStrategy = .iso8601
			let encoded = try encoder.encode(data)
			defaults.set(encoded, forKey: "selectedFacility")
			defaults.synchronize()

			WidgetCenter.shared.reloadAllTimelines()

			Logger.widget
				.info(
					"✅ Widget data saved for: \(data.displayTitle) - \(data.cacheTimestamp)"
				)

		} catch {
			Logger.widget.error("❌ Failed to encode widget data: \(error)")
		}
	}

	func loadWidgetData() -> WidgetFacilityData? {
		guard let defaults = sharedDefaults,
			  let data = defaults.data(forKey: "selectedFacility") else {
			Logger.widget.error("❌ No widget data found")
			return nil
		}

		do {
			let decoder = JSONDecoder()
			decoder.dateDecodingStrategy = .iso8601
			let decoded = try decoder.decode(WidgetFacilityData.self, from: data)
			return decoded
		} catch {
			Logger.widget.error("❌ Failed to decode widget data: \(error)")
			return nil
		}
	}

	func makeWidgetData(from facility: ParkingFacility) -> WidgetFacilityData {
		let vacancy = facility.vacancy
		let displayName = facility.displayName

		return WidgetFacilityData(
			facilityId: facility.facilityId,
			name: facility.name,
			displayTitle: displayName.title,
			displaySubtitle: displayName.subtitle,
			address: facility.address,
			availableSpaces: vacancy.available,
			totalSpaces: vacancy.total,
			occupancyRatio: vacancy.occupancy,
			availabilityStatus: facility.availabilityStatus.text,
			distance: facility.route?.distance,
			travelTime: facility.route?.travelTime,
			lastUpdated: facility.refreshStatus.lastUpdated,
			cacheTimestamp: vacancy.cacheTimestamp
		)
	}

	func updateWidget(with facility: ParkingFacility) {
		let widgetData = makeWidgetData(from: facility)
		saveWidgetData(widgetData)
	}

		/// Update widget only if this facility is currently selected in the widget
	func updateWidgetIfSelected(_ facility: ParkingFacility) {
		guard let currentData = loadWidgetData(),
			  currentData.facilityId == facility.facilityId else {
			// This facility is not the one shown in the widget
			return
		}

		// Update the widget with fresh data
		updateWidget(with: facility)
		Logger.widget
			.info("🔄 Widget updated for: \(facility.displayName.title)")
	}

	// MARK: - Favourites cache
	func cacheFavourites(_ favourites: [String]) {
		sharedDefaults?.set(favourites, forKey: "favouriteFacilityIds")
		sharedDefaults?.synchronize()
	}

	func getCachedFavourites() -> [String]? {
		sharedDefaults?.stringArray(forKey: "favouriteFacilityIds") ?? []
	}
}


// MARK: - Helper functions
extension SharedDataManager.WidgetFacilityData {
	/// Create sample data for previews
	static func sample(status: AvailabilityStatus = .available) -> Self {
		let (available, total): (Int, Int) = {
			switch status {
				case .available: return (45, 100)
				case .almostFull: return (8, 100)
				case .full: return (0, 100)
				case .noData: return (0, 100)
			}
		}()

		return SharedDataManager.WidgetFacilityData(
			facilityId: "6",
			name: "Park&Ride - Gordon Henry St (north)",
			displayTitle: "Gordon",
			displaySubtitle: "Henry St (north)",
			address: "Henry Street",
			availableSpaces: available,
			totalSpaces: total,
			occupancyRatio: Double(total - available) / Double(total),
			availabilityStatus: status.text,
			distance: 2500.0,
			travelTime: 420.0,
			lastUpdated: Date(),
			cacheTimestamp: Date()
		)
	}
}
