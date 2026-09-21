//
//  NearbyParkingSection.swift
//  MetroParking
//
//  Created by Tom Kwok on 5/12/2025.
//

import MapKit
import SwiftUI

extension DetailSections {

	struct NearbyParkingView: View {
		let nearbyFacilities: [ParkingFacility]

		@Binding var nearbyRoutes:
			[String: (distance: CLLocationDistance, travelTime: TimeInterval)]

		var sortedNearbyFacilities: [ParkingFacility] {
			nearbyFacilities.sorted { a, b in
				let distA = nearbyRoutes[a.facilityId]?.distance ?? .infinity
				let distB = nearbyRoutes[b.facilityId]?.distance ?? .infinity
				return distA < distB
			}
		}

		struct rowContent: View {
			@Environment(ETAManager.self) private var etaMgr

			let nearbyRoutes:
				[String: (
					distance: CLLocationDistance, travelTime: TimeInterval
				)]
			let facility: ParkingFacility

			var body: some View {
				HStack {
					ParkingProgressGauge(
						occupancy: facility.vacancy.occupancy,
						available: facility.vacancy.available,
						total: facility.vacancy.total,
						availabilityStatus: facility.availabilityStatus
					)
					.padding(.trailing, 8)

					VStack(alignment: .leading, spacing: 4) {
						Text(facility.displayName.full)
							.font(.headline)
							.lineLimit(1)
						Text(facility.availabilityStatus.text)
							.font(.subheadline)
							.foregroundStyle(.secondary)
					}

					Spacer()

					ZStack {
						if let route = nearbyRoutes[facility.facilityId] {
							VStack(alignment: .trailing, spacing: 4) {
								Text(etaMgr.formatDistance(route.distance))
									.font(.subheadline)
								Text(etaMgr.formatETA(route.travelTime))
									.font(.caption)
									.foregroundStyle(.secondary)
							}
							.zIndex(1)
						} else {
							ProgressView()
								.controlSize(.small)
								.zIndex(1)
						}
					}
					.transition(.blurReplace)


					Image(systemName: "chevron.forward")
						.foregroundStyle(.tertiary)
				}
				.padding(.vertical, 4)
				.contentShape(.rect)

			}
		}

		@ViewBuilder
		func content() -> some View {
			VStack(alignment: .leading, spacing: 12) {

				ForEach(
					sortedNearbyFacilities,
					id: \.facilityId
				) { facility in

					NavigationLink(
						value: MapSheetModel.Route.facility(id: facility.facilityId)
					) {
						rowContent(
							nearbyRoutes: nearbyRoutes,
							facility: facility
						)
					}
					.buttonStyle(.plain)
					.foregroundStyle(.primary)

					if facility.facilityId != nearbyFacilities.last?.facilityId
					{
						Divider()
					}
				}
			}
		}

		var body: some View {
			DetailCard(
				labelHeading: String(
					localized: .facilityDetailSectionNearbyParking
				),
				labelIcon: "parkingsign.circle.fill",
				content: content(),
				trailingTopContent: EmptyView()
			)
		}

	}
}
