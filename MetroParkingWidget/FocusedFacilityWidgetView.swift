//
//  FocusedFacilityWidgetView.swift
//  MetroParking
//
//  Created by Tom Kwok on 20/12/2025.
//

import SwiftUI
import WidgetKit

// MARK: - Views
/// We've got two types of the widgets:
/// - Focused Facility -> showing name, vacancy,  and traffics information for a selected parking facility
/// - List of Facilities -> Nearby facilities, etc.
///

struct FocusedFacilityWidgetView: View {
	let entry: FacilityEntry
	@Environment(\.widgetFamily) var widgetFamily

	var body: some View {
		if let facility = entry.facilityData {
			facilityContentView(facility: facility, isStale: entry.isStale)
		} else {
			emptyStateView
		}
	}

	// MARK: - Facility Content View

	@ViewBuilder
	private func facilityContentView(
		facility: SharedDataManager.WidgetFacilityData,
		isStale: Bool
	) -> some View {
		switch widgetFamily {
		case .systemSmall:
			smallWidgetView(facility: facility, isStale: isStale)
		default:
			smallWidgetView(facility: facility, isStale: isStale)
		}
	}

	// MARK: - Small Widget View

	@ViewBuilder
	private func backgroundView() -> some View {
		VStack {
			Image("WidgetBackground/Signs")
				.resizable()
				.widgetAccentedRenderingMode(.accentedDesaturated)
				.scaleEffect(1.2, anchor: .bottomTrailing)
		}
		.opacity(0.1)
		.blendMode(.luminosity)
	}

	@ViewBuilder
	private func smallWidgetView(
		facility: SharedDataManager.WidgetFacilityData,
		isStale: Bool
	) -> some View {

		let statusColourFill: Color =
			isStale
			? .gray
			: statusColour(facility.availabilityStatus).fill

		ZStack {
			backgroundView()

			VStack {
				VStack(alignment: .leading, spacing: 0) {
					HStack(alignment: .top) {
						Text(facility.displayTitle)
							.font(.body)
							.fontWeight(.semibold)
							.foregroundStyle(.primary)

						Spacer()

					}

					if !facility.displaySubtitle.isEmpty {
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

				VStack(alignment: .leading, spacing: 0) {
					if facility.availabilityStatus.lowercased() == "no data" {
						Text("--")
							.font(.title3)

						HStack(alignment: .firstTextBaseline, spacing: 4) {
							Text("Tap to refresh")
								.font(.headline)
								.fontWeight(.semibold)
								.foregroundStyle(
									statusColourFill.mix(
										with: .primary,
										by: 0.4
									)
								)
						}
					} else {
						HStack(alignment: .firstTextBaseline, spacing: 2) {
							Text("\(facility.availableSpaces)")
								.font(.largeTitle)
								.fontWeight(.semibold)
								.tracking(-0.8)
								.foregroundStyle(
									statusColourFill.mix(
										with: .primary,
										by: 0.4
									)
								)
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
								.foregroundStyle(.secondary)
						}

						HStack(alignment: .firstTextBaseline, spacing: 4) {
							Text("\(facility.availabilityStatus)")
								.font(.headline)
								.fontWeight(.semibold)
								.foregroundStyle(
									statusColourFill.mix(
										with: .primary,
										by: 0.4
									)
								)
						}
					}


					if isStale {
						HStack(alignment: .firstTextBaseline, spacing: 2) {
							Text("\(facility.timeSinceUpdate)")
								.font(.footnote)
						}
					}
				}
				.frame(maxWidth: .infinity, alignment: .topLeading)

			}
			.widgetAccentable()
			.fontDesign(.rounded)
			.foregroundStyle(.foreground)
			.padding()
			.containerBackground(
				RadialGradient(
					stops: [
						Gradient
							.Stop(
								color: statusColourFill,
								location: 0.1
							),
						Gradient
							.Stop(
								color: .clear.mix(with: .yellow, by: 0.05),
								location: 0.7
							),
					],
					center: .bottom,
					startRadius: 240,
					endRadius: 8
				),
				for: .widget
			)
		}

	}

	// MARK: - Medium Widget View

	//	private func mediumWidgetView(
	//		facility: SharedDataManager.WidgetFacilityData,
	//		isStale: Bool
	//	) -> some View {
	//		let statusColourFill: Color =
	//			isStale
	//			? .gray
	//			: statusColour(facility.availabilityStatus).fill
	//
	//		return ZStack {
	//			VStack {
	//				Image("WidgetBackground/Signs")
	//					.resizable()
	//					.widgetAccentedRenderingMode(.accentedDesaturated)
	//					.scaledToFill()
	//			}
	//			.opacity(0.2)
	//			.blendMode(.luminosity)
	//
	//			HStack(spacing: 16) {
	//				// Left side - Vacancy info
	//				VStack(alignment: .leading, spacing: 8) {
	//					HStack(alignment: .firstTextBaseline, spacing: 2) {
	//						Text("\(facility.availableSpaces)")
	//							.font(
	//								.system(
	//									size: 48,
	//									weight: .bold,
	//									design: .rounded
	//								)
	//							)
	//							.foregroundStyle(
	//								statusColourFill.mix(with: .primary, by: 0.4)
	//							)
	//							.contentTransition(
	//								.numericText(
	//									value: Double(facility.availableSpaces)
	//								)
	//							)
	//						Text("/\(facility.totalSpaces)")
	//							.font(.title3)
	//							.opacity(0.7)
	//							.contentTransition(
	//								.numericText(
	//									value: Double(facility.totalSpaces)
	//								)
	//							)
	//							.foregroundStyle(
	//								statusColourFill.mix(with: .secondary, by: 0.8)
	//							)
	//					}
	//
	//					HStack(spacing: 4) {
	//						Text("\(facility.availabilityStatus)")
	//							.font(.title3.weight(.semibold))
	//							.foregroundStyle(
	//								statusColourFill.mix(with: .primary, by: 0.4)
	//							)
	//
	//						if isStale {
	//							Text("·")
	//								.foregroundStyle(.secondary)
	//							Text(facility.timeSinceUpdate)
	//								.font(.caption)
	//								.foregroundStyle(.secondary)
	//						}
	//					}
	//				}
	//				.frame(maxWidth: .infinity, alignment: .leading)
	//
	//				Divider()
	//
	//				// Right side - Facility info
	//				VStack(alignment: .leading, spacing: 8) {
	//					HStack {
	//						Image(systemName: "parkingsign.square.fill")
	//							.font(.title2)
	//
	//						Spacer()
	//
	//						//						// Show stale indicator
	//						//						if isStale {
	//						//							Image(systemName: "clock.arrow.circlepath")
	//						//								.font(.subheadline)
	//						//								.foregroundStyle(.secondary)
	//						//						}
	//					}
	//
	//					Spacer()
	//
	//					VStack(alignment: .leading, spacing: 2) {
	//						Text(facility.displayTitle)
	//							.font(.headline)
	//							.foregroundStyle(.primary)
	//							.lineLimit(2)
	//
	//						if !facility.displaySubtitle.isEmpty {
	//							Text(facility.displaySubtitle)
	//								.font(.subheadline)
	//								.opacity(0.7)
	//								.lineLimit(1)
	//						}
	//					}
	//				}
	//				.frame(maxWidth: .infinity, alignment: .leading)
	//			}
	//			.widgetAccentable()
	//			.fontDesign(.rounded)
	//			.foregroundStyle(.foreground)
	//			.padding()
	//		}
	//		.containerBackground(
	//			RadialGradient(
	//				stops: [
	//					Gradient
	//						.Stop(
	//							color: statusColourFill,
	//							location: 0.1
	//						),
	//					Gradient
	//						.Stop(
	//							color: .clear.mix(with: .yellow, by: 0.05),
	//							location: 0.7
	//						),
	//				],
	//				center: .bottom,
	//				startRadius: 400,
	//				endRadius: 8
	//			),
	//			for: .widget
	//		)
	//	}

	// MARK: - Empty State View

	private var emptyStateView: some View {
		ZStack {
			backgroundView()

			VStack(alignment: .center, spacing: 4) {
								Image(systemName: "questionmark.circle")
									.font(.largeTitle)
									.foregroundStyle(.secondary)

				Text("No carpark select")
					.font(.subheadline)
					.fontWeight(.semibold)
					.foregroundStyle(.primary)

				Text("Long press to select")
					.font(.caption)
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
			}
			.fontDesign(.rounded)
			.padding()
			.containerBackground(Color(.systemGray6).gradient, for: .widget)
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
