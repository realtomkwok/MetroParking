//
//  MetroParkingWidget.swift
//  MetroParkingWidget
//
//  Created by Tom Kwok on 16/12/2025.
//

import SwiftUI
import WidgetKit

struct FacilityEntry: TimelineEntry {
	let date: Date
	let facilityData: SharedDataManager.WidgetFacilityData?
	let isPlaceholder: Bool

	static var placeholder: FacilityEntry {
		FacilityEntry(
			date: Date(),
			facilityData: .sample(status: AvailabilityStatus.available),
			isPlaceholder: true
		)
	}

	static var empty: FacilityEntry {
		FacilityEntry(date: Date(), facilityData: nil, isPlaceholder: false)
	}
}

struct FacilityProvider: TimelineProvider {

	func placeholder(in context: Context) -> FacilityEntry {
		.placeholder
	}

	func getSnapshot(
		in context: Context,
		completion: @escaping (FacilityEntry) -> Void
	) {
		let entry: FacilityEntry

		if context.isPreview {
			entry = .placeholder
		} else {
			// Load real data for snapshot
			let data = SharedDataManager.shared.loadWidgetData()
			entry = FacilityEntry(
				date: Date(),
				facilityData: data,
				isPlaceholder: false
			)
		}

		completion(entry)
	}

	func getTimeline(
		in context: Context,
		completion: @escaping (Timeline<FacilityEntry>) -> Void
	) {
		let data = SharedDataManager.shared.loadWidgetData()

		let entry = FacilityEntry(
			date: Date(),
			facilityData: data,
			isPlaceholder: false
		)

		// Update timeline every 10 minute (respecting the update frequency of TfNSW)
		guard
			let nextUpdate = Calendar.current.date(
				byAdding: .minute,
				value: 10,
				to: Date()
			)
		else { return }

		let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))

		completion(timeline)
	}
}

// MARK: - Views
/// We've got two types of the widgets:
/// - Focused Facility -> showing name, vacancy,  and traffics information for a selected parking facility
/// - List of Facilities -> Nearby facilities, etc.
///

struct FocusedFacilityWidgetSmallView: View {
	let entry: FacilityEntry

	var body: some View {
		if let facility = entry.facilityData {

			VStack(alignment: .leading) {
				VStack(alignment: .leading, spacing: 0) {

					HStack(alignment: .center) {

						Text(facility.displayTitle)
							.font(.headline)
							.foregroundStyle(.primary)

						Spacer()

						Image(systemName: "parkingsign.square.fill")

					}


					if facility.displaySubtitle.isEmpty != true {
						Text(facility.displaySubtitle)
							.font(.subheadline)
							.opacity(0.7)
					}
				}
				.frame(
					maxWidth: .infinity,
					alignment: .top
				)

				Spacer()

				VStack(alignment: .leading) {
					HStack(alignment: .firstTextBaseline, spacing: 0) {
						Text("\(facility.availableSpaces)")
							.font(.largeTitle)
							.foregroundStyle(.primary)
							.contentTransition(
								.numericText(
									value: Double(facility.availableSpaces)
								)
							)
						Text("/\(facility.totalSpaces)")
							.font(.subheadline)
							.opacity(0.7)
							.contentTransition(
								.numericText(
									value: Double(facility.totalSpaces)
								)
							)
					}
					Text("\(facility.availabilityStatus)")
						.font(.headline)
				}
				.frame(maxWidth: .infinity, alignment: .topLeading)


			}
			.fontDesign(.rounded)
			.foregroundStyle(.foreground)
			.padding()
			.containerBackground(
				statusColour(
					facility.availabilityStatus
				).fill.gradient,
				for: .widget
			)
		}
	}

	private func statusColour(_ status: String) -> AvailabilityStatus {
		switch status.lowercased().replacingOccurrences(of: " ", with: "") {
		case "available": AvailabilityStatus.available
		case "almostfull": AvailabilityStatus.almostFull
		case "full": AvailabilityStatus.full
		default: AvailabilityStatus.noData
		}
	}
}

// MARK: - Configuration

struct FacilityWidget: Widget {
	let kind: String = "FacilityWidget"

	var body: some WidgetConfiguration {
		StaticConfiguration(kind: kind, provider: FacilityProvider()) { entry in
			FocusedFacilityWidgetSmallView(entry: entry)
		}
		.configurationDisplayName("Focused Parking")
		.description(
			"View vacancy and traffics information for a selected parking facility"
		)
		.supportedFamilies([.systemSmall])
		.contentMarginsDisabled()
	}
}
