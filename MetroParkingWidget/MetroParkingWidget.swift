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
	let configuration: SelectFacilityIntent

	static var placeholder: FacilityEntry {
		FacilityEntry(
			date: Date(),
			facilityData: .sample(status: AvailabilityStatus.available),
			isPlaceholder: true,
			configuration: SelectFacilityIntent()
		)
	}

	static var empty: FacilityEntry {
		FacilityEntry(
			date: Date(),
			facilityData: nil,
			isPlaceholder: false,
			configuration: SelectFacilityIntent()
		)
	}
}

struct FacilityProvider: AppIntentTimelineProvider {

	typealias Entry = FacilityEntry
	typealias Intent = SelectFacilityIntent

	func placeholder(in context: Context) -> FacilityEntry {
		.placeholder
	}

	func snapshot(
		for configuration: SelectFacilityIntent,
		in context: Context
	) async -> FacilityEntry {

		if context.isPreview {
			return .placeholder
		}

		// Try to load data for the selected facility
		if let selectedFacility = configuration.facility {
			let data = await loadFacilityData(facilityId: selectedFacility.id)
			return FacilityEntry(
				date: Date(),
				facilityData: data,
				isPlaceholder: false,
				configuration: configuration
			)
		}

		// No facility selected - return empty state
		return FacilityEntry(
			date: Date(),
			facilityData: nil,
			isPlaceholder: false,
			configuration: configuration
		)
	}

	func timeline(
		for configuration: SelectFacilityIntent,
		in context: Context
	) async -> Timeline<FacilityEntry> {

		let data: SharedDataManager.WidgetFacilityData?

		if let selectedFacility = configuration.facility {
			// Load data for the configured facility
			data = await loadFacilityData(facilityId: selectedFacility.id)
		} else {
			// No facility configured - show empty state
			data = nil
		}

		let entry = FacilityEntry(
			date: Date(),
			facilityData: data,
			isPlaceholder: false,
			configuration: configuration
		)

		// Update timeline every 10 minutes (respecting the update frequency of TfNSW)
		guard
			let nextUpdate = Calendar.current.date(
				byAdding: .minute,
				value: 10,
				to: Date()
			)
		else {
			return Timeline(entries: [entry], policy: .atEnd)
		}

		let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
		return timeline
	}

	// MARK: - Helper Methods

	/// Load facility data from SwiftData
	private func loadFacilityData(facilityId: String) async -> SharedDataManager
		.WidgetFacilityData?
	{
		let container = await SharedDataManager.makeSharedContainer()
		let context = ModelContext(container)

		let descriptor = FetchDescriptor<ParkingFacility>(
			predicate: #Predicate { $0.facilityId == facilityId }
		)

		do {
			let facilities = try context.fetch(descriptor)
			guard let facility = facilities.first else {
				print("⚠️ No facility found with ID: \(facilityId)")
				return nil
			}

			// Convert to widget data format
			return SharedDataManager.shared.makeWidgetData(from: facility)
		} catch {
			print("❌ Failed to load facility data: \(error)")
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
			intent: SelectFacilityIntent.self,
			provider: FacilityProvider()
		) { entry in
			FocusedFacilityWidgetView(entry: entry)
		}
		.configurationDisplayName("Focused Parking")
		.description(
			"View vacancy and traffic information for a selected parking facility"
		)
		.supportedFamilies([.systemSmall, .systemMedium])
		.contentMarginsDisabled()
	}
}
