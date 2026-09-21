//
//  RefreshLogicTests.swift
//  MetroParking
//
//  Created by Tom Kwok on 19/9/2026.
//

import Foundation
import Testing

@testable import MetroParking

@Suite("API usage counter", .tags(.api))
struct APIUsageMonitorTests {
	private let defaults: UserDefaults
	private let calendar: Calendar

	init() throws {
		let suite = "APIUsageMonitorTests-\(UUID().uuidString)"
		defaults = try #require(UserDefaults(suiteName: suite))
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = try #require(TimeZone(identifier: "Australia/Sydney"))
		self.calendar = calendar
	}

	private func date(_ day: Int, _ hour: Int) throws -> Date {
		try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour)))
	}

	@Test func `starts at zero and counts calls`() throws {
		let now = try date(19, 9)
		#expect(APIUsageMonitor.dailyUsage(in: defaults, now: now, calendar: calendar) == 0)

		for _ in 0..<3 {
			APIUsageMonitor.recordCall(in: defaults, now: now, calendar: calendar)
		}

		#expect(APIUsageMonitor.dailyUsage(in: defaults, now: now, calendar: calendar) == 3)
	}

	@Test func `resets when the day changes`() throws {
		APIUsageMonitor.recordCall(in: defaults, now: try date(19, 23), calendar: calendar)

		let nextMorning = try date(20, 6)
		#expect(APIUsageMonitor.dailyUsage(in: defaults, now: nextMorning, calendar: calendar) == 0)

		APIUsageMonitor.recordCall(in: defaults, now: nextMorning, calendar: calendar)
		#expect(APIUsageMonitor.dailyUsage(in: defaults, now: nextMorning, calendar: calendar) == 1)
	}

	@Test func `a fresh install can make calls`() throws {
		#expect(APIUsageMonitor.canMakeCall(in: defaults, now: try date(19, 9), calendar: calendar))
	}
}

@Suite("API dispatcher", .tags(.api))
struct APIDispatcherTests {

	@Test func `concurrent callers get spaced slots`() async {
		let interval: TimeInterval = 0.1
		let dispatcher = APIDispatcher(minInterval: interval)
		let clock = ContinuousClock()
		let start = clock.now

		let finishTimes = await withTaskGroup(of: Duration.self) { group in
			for _ in 0..<4 {
				group.addTask {
					await dispatcher.requestSlot()
					return clock.now - start
				}
			}
			return await group.reduce(into: []) { $0.append($1) }.sorted()
		}

		// The first caller goes immediately; each later one waits one more interval.
		// Before the fix they all woke together after a single interval.
		#expect(finishTimes.count == 4)
		for (index, time) in finishTimes.enumerated() {
			#expect(time >= .seconds(interval * Double(index)) - .milliseconds(15))
		}
		#expect(finishTimes.last! - finishTimes.first! >= .seconds(interval * 3) - .milliseconds(15))
	}
}

@Suite("Background refresh intervals", .tags(.configuration))
struct BackgroundIntervalTests {
	private var calendar: Calendar {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(identifier: "Australia/Sydney")!
		return calendar
	}

	typealias Interval = RefreshConfiguration.BackgroundTaskInterval

	@Test(
		arguments: [
			// (hour on a weekday, expected)
			(6, Interval.offPeak),
			(7, Interval.peakHours),
			(8, Interval.peakHours),
			(9, Interval.officeHours),
			(16, Interval.officeHours),
			(17, Interval.peakHours),
			(18, Interval.peakHours),
			(19, Interval.offPeak),
			(22, Interval.offPeak),
		]
	)
	func `weekday intervals follow the commute`(hour: Int, expected: TimeInterval) throws {
		// 17 Sep 2026 is a Thursday.
		let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 17, hour: hour)))
		#expect(Interval.current(at: date, calendar: calendar) == expected)
	}

	@Test func `weekends are off-peak`() throws {
		// 19 Sep 2026 is a Saturday.
		let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 19, hour: 8)))
		#expect(Interval.current(at: date, calendar: calendar) == Interval.offPeak)
	}
}

@Suite("Configuration", .tags(.configuration))
struct ConfigurationTests {
	@Test(
		arguments: [
			("", false),
			("$(TFNSW_API_KEY)", false),
			("YOUR_API_KEY_GOES_HERE", false),
			("short", false),
			("has a space in the key value", false),
			("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test", true),
		]
	)
	func `validates API keys without crashing`(key: String, isValid: Bool) {
		#expect(Configuration.isValidAPIKey(key) == isValid)
	}
}
