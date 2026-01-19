//
//  WidgetBudgetTracker.swift
//  MetroParking
//
//  Created by Tom Kwok on 18/12/2025.
//

/// Centralised widget reload coordinator.
/// Handles budget tracking, throttling, and provides a single point for all widget reloads.
/// Complies with Apple's budget (~48-70 reloads per day).

import Foundation
import OSLog
import WidgetKit

final class WidgetBudgetTracker {

	static let shared = WidgetBudgetTracker()

	private let reloadHistoryKey = "widgetReloadHistory"

	private init() {}

	var lastReloadTime: Date {
		getReloadHistory().last ?? .distantPast
	}

	/// Remaining budget for today
	var remainingBudget: Int {
		max(0, RefreshConfiguration.Widget.dailyBudget - reloadsInLast24Hours())
	}
}

// MARK: - Public API
extension WidgetBudgetTracker {

	/// Check if widget reload is allowed based on throttling and budget
	func canReload() -> Bool {
		let timeSinceLastReload = Date().timeIntervalSince(lastReloadTime)
		let reloadsToday = reloadsInLast24Hours()

		guard timeSinceLastReload >= RefreshConfiguration.Widget.minReloadInterval else {
			Logger.widget.debug(
				"⏰ Throttled: \(Int(timeSinceLastReload))s since last reload (min: \(Int(RefreshConfiguration.Widget.minReloadInterval))s)"
			)
			return false
		}

		guard reloadsToday < RefreshConfiguration.Widget.dailyBudget else {
			Logger.widget.warning(
				"⚠️ Budget exceeded: \(reloadsToday)/\(RefreshConfiguration.Widget.dailyBudget) reloads today"
			)
			return false
		}

		return true
	}

	/// Request a widget reload if budget allows
	/// - Returns: `true` if reload was triggered, `false` if throttled/budget exceeded
	@discardableResult
	func requestReload() -> Bool {
		guard canReload() else { return false }

		WidgetCenter.shared.reloadAllTimelines()
		recordReload()
		return true
	}

	/// Force reload widgets regardless of budget (use sparingly)
	/// Still records the reload for budget tracking
	func forceReload() {
		WidgetCenter.shared.reloadAllTimelines()
		recordReload()
		Logger.widget.notice("⚡️ Forced widget reload")
	}

	func reloadsInLast24Hours() -> Int {
		getReloadHistory().count
	}
}

// MARK: - Internal Recording
extension WidgetBudgetTracker {

	func recordReload() {
		var history = getReloadHistory()  // Already filtered to last 24 hours
		history.append(Date())

		saveReloadHistory(history)
		Logger.widget.notice(
			"✅ Reload recorded (\(history.count)/\(RefreshConfiguration.Widget.dailyBudget) today)"
		)
	}
}

// MARK: - Storage
extension WidgetBudgetTracker {

	private var sharedDefaults: UserDefaults? {
		UserDefaults(suiteName: SharedDataManager.appGroupIdentifier)
	}

	private func getReloadHistory() -> [Date] {
		guard let defaults = sharedDefaults,
			  let data = defaults.data(forKey: reloadHistoryKey),
			  let dates = try? JSONDecoder().decode([Date].self, from: data)
		else {
			return []
		}

		// Filter to last 24 hours to ensure budget resets correctly
		let oneDayAgo = Date().addingTimeInterval(-24 * 60 * 60)
		return dates.filter { $0 > oneDayAgo }
	}

	private func saveReloadHistory(_ dates: [Date]) {
		guard let defaults = sharedDefaults else {
			Logger.widget.error("❌ Failed to access shared UserDefaults for widget history")
			return
		}

		if let data = try? JSONEncoder().encode(dates) {
			defaults.set(data, forKey: reloadHistoryKey)
			defaults.synchronize()
		}
	}
}
