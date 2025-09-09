//
//  APIUsageMonitor.swift
//  MetroParking
//
//  Created by Tom Kwok on 1/9/2025.
//

import Foundation
import OSLog

struct APIUsageMonitor {
	private static let dailyLimit = 60000  // Current plan, can upgrade if exceeds too often
	private static let safetyBuffer = 0.85

	private static let dailyCountKey = "api_daily_count"
	private static let dailyDateKey = "api_daily_date"

	static var dailyUsage: Int {
		resetIfNeeded()
		return UserDefaults.standard.integer(forKey: dailyCountKey)
	}

	static var canMakeCall: Bool {
		resetIfNeeded()
		return Double(dailyUsage) < Double(dailyLimit)
	}
}

extension APIUsageMonitor {

	static func recordCall() {
		resetIfNeeded()

		let newRecord = dailyUsage + 1
		UserDefaults.standard.set(newRecord, forKey: dailyCountKey)
		Logger.api.debug("📊 API Usage: \(newRecord)/\(dailyLimit) daily")

		if newRecord >= Int(Double(dailyLimit) * 0.8) {
			Logger.api
				.warning(
					"⚠️ Daily API usage at 80%: \(newRecord)/\(dailyLimit)"
				)
		}
	}

	static var usageReport: String {
		resetIfNeeded()

		let dailyPercent = Int(Double(dailyUsage) / Double(dailyLimit) * 100)

		return """
			📊 API Usage Report
			Daily: \(dailyUsage)/\(dailyLimit) (\(dailyPercent.formatted(.percent)))
			Status: \(canMakeCall ? "✅ OK" : "⚠️ Limit Reached")
		"""
	}

	private static func resetIfNeeded() {
		let now = Date()
		let calendar = Calendar.current

		if let lastDailyDate = UserDefaults.standard.object(
			forKey: dailyDateKey
		) as? Date {
			if !calendar.isDate(lastDailyDate, inSameDayAs: now) {
				UserDefaults.standard.set(0, forKey: dailyCountKey)
				UserDefaults.standard.set(now, forKey: dailyDateKey)
				Logger.api.notice("🔄 Daily API counter reset")
			} else {
				UserDefaults.standard.set(now, forKey: dailyDateKey)
			}
		}
	}

	/// Manual reset for testing
	static func resetCounter() {
		UserDefaults.standard.set(0, forKey: dailyCountKey)
		UserDefaults.standard.set(Date(), forKey: dailyDateKey)
		Logger.api.notice("🔄 API counters manually reset")
	}
}
