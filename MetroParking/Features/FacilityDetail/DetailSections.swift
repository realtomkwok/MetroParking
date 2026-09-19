//
//  DetailSections.swift
//  MetroParking
//
//  Created by Tom Kwok on 5/12/2025.
//

import MapKit
import SwiftUI

/// Detail Sections
///  - Vacancy
///  - Traffics
///  - Look Around
///  - Nearby facilities

struct DetailSections: View {
	var selectedFacility: ParkingFacility
	var nearbyFacilities: [ParkingFacility]
	var lookAround: LookAroundLoader

	@Environment(FacilityManager.self) private var facilityDataMgr
	@Environment(ETAManager.self) private var etaMgr
	@Environment(\.dismiss) private var dismiss

	@State private var nearbyRoutes:
		[String: (distance: CLLocationDistance, travelTime: TimeInterval)] = [:]

	var body: some View {
		VStack {

			VacancyView(
				selectedFacility: selectedFacility,
				isRefreshing: facilityDataMgr.isRefreshing
			)

			TrafficView(
				selectedFacility: selectedFacility
			)

			NearbyParkingView(
				nearbyFacilities: nearbyFacilities,
				nearbyRoutes: $nearbyRoutes
			)
			LookAroundView(loader: lookAround)

		}
		.padding()
		.task(id: "\(selectedFacility.facilityId)-\(nearbyFacilities.count)") {
			try? await Task.sleep(for: .seconds(0.3))

			nearbyRoutes = [:]

			// Every child would run on the main actor anyway, so a task group
			// adds nothing; sequential requests also go easier on MKDirections limits.
			for nearby in nearbyFacilities {
				guard !Task.isCancelled else { return }
				if let result = await etaMgr.calculateDistanceBetweenFacilities(
					from: selectedFacility,
					to: nearby
				) {
					nearbyRoutes[nearby.facilityId] = result
				}
			}
		}
	}
}

extension DetailSections {

	struct DetailCard<Content: View, TrailingTopContent: View>: View {
		let labelHeading: String
		let labelIcon: String
		let labelColor: Color
		let content: Content
		let trailingTopContent: TrailingTopContent

		init(
			labelHeading: String,
			labelIcon: String,
			labelColor: Color = .accentColor,
			content: Content,
			trailingTopContent: TrailingTopContent
		) {
			self.labelHeading = labelHeading
			self.labelIcon = labelIcon
			self.labelColor = labelColor
			self.content = content
			self.trailingTopContent = trailingTopContent
		}

		var body: some View {
			VStack(alignment: .leading, spacing: 16) {

				HStack(alignment: .center) {
					Label(labelHeading, systemImage: labelIcon)
						.foregroundStyle(Color(labelColor))
						.font(.subheadline)
						.fontWeight(.semibold)
						.labelIconToTitleSpacing(4)

					Spacer()

					trailingTopContent
				}

				content
					.frame(
						maxWidth: .infinity,
						alignment: .leading
					)
			}
			.padding(.horizontal, 20)
			.padding(.vertical, 16)
			.glassEffect(.regular, in: .rect(corners: .concentric(minimum: 24)))
			.clipShape(.containerRelative)
		}
	}
}
