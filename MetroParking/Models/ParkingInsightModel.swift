//
//  ParkingInsightModel.swift
//  MetroParking
//
//  Created by Tom Kwok on 4/8/2025.
//

import Foundation

struct HourlyPattern: Codable, Identifiable {
	let id = UUID()
	let facilityId: String
	let dayOfWeek: Int  // 1=Sunday, 7=Saturday
	let hour: Int  // 0-23
	let avgOccupancyRate: Double  // 0.0-1.0
	let sampleCount: Int

	enum CodingKeys: String, CodingKey {
		case facilityId = "facility_id"
		case dayOfWeek = "day_of_week"
		case hour
		case avgOccupancyRate = "avg_occupancy_rate"
		case sampleCount = "sample_count"
	}
}

struct FacilityInsights: Codable {
	let facilityId: String
	let peakHours: [Int]
	let bestTimes: [Int]
	let busiestDays: [Int]
	let generatedAt: Date?

	enum CodingKeys: String, CodingKey {
		case facilityId = "facility_id"
		case peakHours = "peak_hours"
		case bestTimes = "best_times"
		case busiestDays = "busiest_days"
		case generatedAt = "generated_at"
	}
}

struct CacheStatus: Codable {
	let facilityId: String
	let status: String
	let lastApiFetch: Date?
	let daysCached: Int?
	let nextUpdateDue: Date?

	enum CodingKeys: String, CodingKey {
		case facilityId = "facility_id"
		case status
		case lastApiFetch = "last_api_fetch"
		case daysCached = "days_cached"
		case nextUpdateDue = "next_update_due"
	}
}

extension HourlyPattern {
	var occupancyPercentage: Double {
		avgOccupancyRate
	}

	var dayName: String {
		let days = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
		return days[dayOfWeek]
	}
}

extension FacilityInsights {
	var peakHoursText: String {
		peakHours.map { String(format: "%02d:00", $0) }.joined(separator: ", ")
	}
	
	var bestTimeText: String {
		bestTimes.map { String(format: "%02d:00", $0) }.joined(separator: ", ")
	}
}

/// Chart Data
struct InsightChartDataPoint: Identifiable {
	let id = UUID()
	let hour: Int
	let occupancyPercentage: Double
}
