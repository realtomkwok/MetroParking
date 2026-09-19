//
//  APIUsageMonitor.swift
//  MetroParking
//
//  Created by Tom Kwok on 1/9/2025.
//

import Foundation
import OSLog

/// Tracks TfNSW API calls against the daily quota.
///
/// Stored in the App Group so calls made by the widget count too. The count
/// resets when the calendar day changes.
nonisolated struct APIUsageMonitor {
	static let dailyLimit = 60_000

	private static let recordKey = "apiDailyUsage"

	private struct Record: Codable {
		var day: Date
		var count: Int
	}

	private static var defaults: UserDefaults {
		UserDefaults(suiteName: SharedDataManager.appGroupIdentifier) ?? .standard
	}

	static var dailyUsage: Int {
		dailyUsage(in: defaults)
	}

	static var canMakeCall: Bool {
		canMakeCall(in: defaults)
	}

	static func recordCall() {
		recordCall(in: defaults)
	}

	/// Manual reset for debugging
	static func resetCounter() {
		defaults.removeObject(forKey: recordKey)
		Logger.api.notice("🔄 API counters manually reset")
	}

	// MARK: - Testable core

	static func dailyUsage(in defaults: UserDefaults, now: Date = .now, calendar: Calendar = .current) -> Int {
		currentRecord(in: defaults, now: now, calendar: calendar).count
	}

	static func canMakeCall(in defaults: UserDefaults, now: Date = .now, calendar: Calendar = .current) -> Bool {
		dailyUsage(in: defaults, now: now, calendar: calendar) < dailyLimit
	}

	static func recordCall(in defaults: UserDefaults, now: Date = .now, calendar: Calendar = .current) {
		var record = currentRecord(in: defaults, now: now, calendar: calendar)
		record.count += 1
		if let data = try? JSONEncoder().encode(record) {
			defaults.set(data, forKey: recordKey)
		}

		Logger.api.debug("📊 API Usage: \(record.count)/\(dailyLimit) daily")
		if record.count == dailyLimit * 8 / 10 {
			Logger.api.warning("⚠️ Daily API usage at 80%: \(record.count)/\(dailyLimit)")
		}
	}

	/// Today's record; a record from an earlier day counts as zero.
	private static func currentRecord(in defaults: UserDefaults, now: Date, calendar: Calendar) -> Record {
		let today = calendar.startOfDay(for: now)
		guard
			let data = defaults.data(forKey: recordKey),
			let record = try? JSONDecoder().decode(Record.self, from: data),
			calendar.isDate(record.day, inSameDayAs: today)
		else {
			return Record(day: today, count: 0)
		}
		return record
	}
}
