//
//  MetroParkingWidget.swift
//  MetroParkingWidget
//
//  Created by Tom Kwok on 16/12/2025.
//

import AppIntents
import SwiftData
import SwiftUI
import WidgetKit

struct FacilityEntry: TimelineEntry {
	let date: Date
	let facilityData: SharedDataManager.WidgetFacilityData?
	let isPlaceholder: Bool
	let isStale: Bool
	let configuration: FocusedFacilityWidgetConfigs

	var deepLinkURL: URL? {
		guard let facilityData = self.facilityData else { return nil }
		return URL(string: "metroparking://facility/\(facilityData.facilityId)")
	}

	static var placeholder: FacilityEntry {
		FacilityEntry(
			date: Date(),
			facilityData: .sample(status: AvailabilityStatus.available),
			isPlaceholder: true,
			isStale: false,
			configuration: FocusedFacilityWidgetConfigs()
		)
	}

	static var empty: FacilityEntry {
		FacilityEntry(
			date: Date(),
			facilityData: nil,
			isPlaceholder: false,
			isStale: false,
			configuration: FocusedFacilityWidgetConfigs()
		)
	}
}

struct FacilityProvider: AppIntentTimelineProvider {

	typealias Entry = FacilityEntry
	typealias Intent = FocusedFacilityWidgetConfigs

	func placeholder(in context: Context) -> FacilityEntry {
		.placeholder
	}

	func snapshot(
		for configuration: FocusedFacilityWidgetConfigs,
		in context: Context
	) async -> FacilityEntry {

		if context.isPreview {
			return .placeholder
		}

		// Try to load data for the selected facility
		if let selectedFacility = configuration.facility {
			let data = await loadFacilityData(facilityId: selectedFacility.id)
			let isStale = data?.isStale ?? false
			return FacilityEntry(
				date: Date(),
				facilityData: data,
				isPlaceholder: false,
				isStale: isStale,
				configuration: configuration
			)
		}

		// No facility selected - return empty state
		return .empty
	}

	func timeline(
		for configuration: FocusedFacilityWidgetConfigs,
		in context: Context
	) async -> Timeline<FacilityEntry> {

		guard let selectedFacility = configuration.facility else {
			// No facility configured - show empty state
			return Timeline(entries: [.empty], policy: .never)
		}

		// Register this facility as being displayed in a widget
		SharedDataManager.shared.registerWidgetFacility(selectedFacility.id)

		// STEP 1: Load cached data immediately (prevents placeholder flash)
		// Try SwiftData first (most recent), then UserDefaults fallback
		var displayData = await loadFacilityData(facilityId: selectedFacility.id)
		if displayData == nil {
			displayData = SharedDataManager.shared.loadWidgetData(
				forFacilityId: selectedFacility.id
			)
		}

		// STEP 2: Refresh if data is stale (> 5 min)
		// This ensures widget shows fresh vacancy data when WidgetKit refreshes the timeline
		let staleThreshold: TimeInterval = 5 * 60  // 5 minutes
		let isDataStale = displayData?.cacheTimestamp.timeIntervalSinceNow ?? -.infinity < -staleThreshold

		if isDataStale {
			print("🔄 Widget: Data is stale, fetching fresh from API...")
			if let freshData = await WidgetAPIService.shared.fetchAndUpdateCache(
				facilityId: selectedFacility.id,
				existingData: displayData
			) {
				displayData = freshData
				print("✅ Widget: Got fresh data - \(freshData.availableSpaces)/\(freshData.totalSpaces) available")
			} else {
				print("⚠️ Widget: API fetch failed, using cached data")
			}
		}

		// STEP 3: Create timeline entry
		// Always show cached data (even if stale) - widget view decides whether to show "--" based on age
		let showStaleIndicator = displayData?.isStale ?? false

		let entry = FacilityEntry(
			date: Date(),
			facilityData: displayData,
			isPlaceholder: false,
			isStale: showStaleIndicator,
			configuration: configuration
		)

		// STEP 4: Schedule next refresh
		// - If we have fresh data: check again in 10 minutes
		// - If data is stale (API failed): try again in 5 minutes
		let refreshMinutes = showStaleIndicator ? 5 : 10
		guard
			let nextUpdate = Calendar.current.date(
				byAdding: .minute,
				value: refreshMinutes,
				to: Date()
			)
		else {
			return Timeline(entries: [entry], policy: .atEnd)
		}

		// Return single entry with adaptive refresh schedule
		// Widget will continue showing cached data until next timeline refresh
		return Timeline(entries: [entry], policy: .after(nextUpdate))
	}

	// MARK: - Helper Methods

	/// Load facility data from SwiftData using the shared container
	private func loadFacilityData(facilityId: String) async -> SharedDataManager
		.WidgetFacilityData?
	{
		// Use the shared container to ensure we're reading from the same data store as the app
		let container = await SharedDataManager.sharedContainer
		let context = ModelContext(container)

		let descriptor = FetchDescriptor<ParkingFacility>(
			predicate: #Predicate { $0.facilityId == facilityId }
		)

		do {
			let facilities = try context.fetch(descriptor)
			guard let facility = facilities.first else {
				print("⚠️ Widget: No facility found with ID: \(facilityId)")
				return nil
			}

			print(
				"✅ Widget: Loaded facility '\(facility.displayName.title)' with \(facility.vacancy.available) available spaces"
			)

			// Convert to widget data format
			return SharedDataManager.shared.makeWidgetData(from: facility)
		} catch {
			print("❌ Widget: Failed to load facility data: \(error)")
			return nil
		}
	}
}

// MARK: - Configuration

struct FacilityWidget: Widget {
	let kind: String = "FacilityWidget"

	var body: some WidgetConfiguration {
		AppIntentConfiguration(
			kind: kind,
			intent: FocusedFacilityWidgetConfigs.self,
			provider: FacilityProvider()
		) { entry in
			FocusedFacilityWidgetView(entry: entry)
				.widgetURL(entry.deepLinkURL)
		}
		.configurationDisplayName("Carpark Vacancy")
		.description(
			"Quick view for the vacancy status and available spaces of a selected carpark."
		)
		.supportedFamilies([.systemSmall])
		.contentMarginsDisabled()
	}
}

struct FocusedFacilityWidgetConfigs: WidgetConfigurationIntent {

	static var title: LocalizedStringResource = "Carpark Vacancy"
	static var description = IntentDescription(
		"Select a carpark from the list to display on the widget."
	)

	@Parameter(title: "Carpark")
	var facility: FacilityEntity?

	init(facility: FacilityEntity? = nil) {
		self.facility = facility
	}

	init() {
		self.facility = nil
	}
}

// MARK: - Widget data sample
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
