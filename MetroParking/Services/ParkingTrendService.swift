//
//  ParkingTrendService.swift
//  MetroParking
//
//  Created by Tom Kwok on 4/8/2025.
//

import Foundation
import OSLog

class ParkingTrendService: ObservableObject {
	@Published var hourlyPatterns: [HourlyPattern] = []
	@Published var insights: FacilityInsights?

	func fetchData(facilityId: String) async {
		do {
			let patterns: [HourlyPattern] =
				try await supabase
				.from("hourly_patterns")
				.select()
				.eq("facility_id", value: facilityId)
				.execute()
				.value

			let insights: [FacilityInsights] =
				try await supabase
				.from("facility_insights")
				.select()
				.eq("facility_id", value: facilityId)
				.execute()
				.value

			await MainActor.run {
				self.hourlyPatterns = patterns
				self.insights = insights.first
			}
		} catch {
			Logger.facilityData.error("Error fetching data: \(error)")
		}
	}
}
