//
//  VacancySection.swift
//  MetroParking
//
//  Created by Tom Kwok on 5/12/2025.
//

import SwiftUI

extension DetailSections {

	struct VacancyView: View {
		let selectedFacility: ParkingFacility
		let isRefreshing: Bool

		struct content: View {
			let selectedFacility: ParkingFacility
			let isRefreshing: Bool

			private var staleness: ParkingFacility.DataStaleness {
				selectedFacility.refreshStatus.staleness
			}

			/// "available/total", e.g. 42/213. Numbers are verbatim, not localised keys.
			private var spaceCount: some View {
				let vacancy = selectedFacility.vacancy
				return HStack(alignment: .firstTextBaseline, spacing: 0) {
					Text(verbatim: "\(vacancy.available)")
						.foregroundStyle(.primary)
						.contentTransition(.numericText(value: Double(vacancy.available)))
					Text(verbatim: "/\(vacancy.total)")
						.foregroundStyle(.secondary)
						.contentTransition(.numericText(value: Double(vacancy.total)))
				}
				.font(.title)
				.fontWeight(.semibold)
				.lineLimit(1)
				.minimumScaleFactor(0.6)
				.opacity(staleness.displayOpacity)
				.breathingAnimation(staleness == .stale && isRefreshing)
			}

			var body: some View {
				HStack(alignment: .center) {
					VStack(alignment: .leading) {
						HStack(alignment: .firstTextBaseline, spacing: 4) {
							spaceCount

							Text(.facilityDetailLabelSpaces)
								.font(.callout)
								.foregroundStyle(.secondary)
								.lineLimit(1)
								.contentTransition(.identity)
						}
						.layoutPriority(1)

						HStack(alignment: .firstTextBaseline, spacing: 4) {
							Text(verbatim: selectedFacility.availabilityStatus.text)
								.font(.headline)
								.transition(.blurReplace)
						}
					}

					Spacer()

					let vacancy = selectedFacility.vacancy
					Gauge(
						value: vacancy.occupancy,
						in:
							0...1
					) {
					}
					.frame(minWidth: 48, maxWidth: 96)
					.gaugeStyle(
						.linearCapacity
					)
					.tint(
						AvailabilityStatus.gradient
					)
					.opacity(
						selectedFacility.refreshStatus.staleness.displayOpacity
					)
				}
				.animation(
					.smooth,
					value: selectedFacility.refreshStatus.staleness
				)
				// Drives the numeric content transitions and the gauge, which have
				// no ambient animation of their own.
				.animation(.smooth, value: selectedFacility.vacancy.available)
			}
		}

		struct trailingView: View {
			let lastUpdated: Date

			var body: some View {
				TimelineView(.periodic(from: .now, by: 60)) { context in
					let timeInterval = context.date.timeIntervalSince(
						lastUpdated
					)

					if lastUpdated == .distantPast {
						// Never loaded; a relative date would read "2,025y ago".
						Text(.dateLabelNever)
					} else if timeInterval < 60 {
						Text(.dateLabelJustNow)
					} else {
						Text(
							.dateFormatUpdated(
								lastUpdated
									.formatted(
										.relative(
											presentation: .named,
											unitsStyle: .narrow
										)
									)
							)
						)
					}
				}
				.transition(.opacity)
				.monospacedDigit()
				.font(.footnote)
			}
		}

		var body: some View {
			DetailCard(
				labelHeading: String(localized: .facilityDetailSectionVacancy),
				labelIcon: "checkmark.circle.fill",
				content: content(
					selectedFacility: selectedFacility,
					isRefreshing: isRefreshing
				),
				trailingTopContent: trailingView(
					lastUpdated: selectedFacility.refreshStatus.lastUpdated
				),
			)
		}
	}

}
