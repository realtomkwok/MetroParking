//
//  RefreshConfiguration.swift
//  MetroParking
//
//  Created by Tom Kwok on 20/12/2025.
//

/// Unified refresh configuration consolidating all timing constants and strategies
/// for foreground refresh, background tasks, and widget updates.

import Foundation

// MARK: - Unified Refresh Configuration

/// Single source of truth for all refresh-related timing and strategy configuration
enum RefreshConfiguration {

	// MARK: - Foreground Refresh Intervals

	/// How often to trigger the next refresh cycle when app is active
	enum ForegroundInterval {
		static let standard: TimeInterval = 60  // 60 seconds between refresh cycles
	}

	// MARK: - Cache Validity by Tier

	/// Cache validity durations based on facility priority tier
	/// Used to determine if a facility needs refreshing
	enum CacheValidity {
		/// Foreground cache validity (when app is active)
		enum Foreground {
			static let critical: TimeInterval = 60     // 1 minute - widgets + favourites
			static let standard: TimeInterval = 300    // 5 minutes - recently visited
			static let background: TimeInterval = 600  // 10 minutes - others
		}

		/// Background cache validity (for background tasks)
		/// More lenient to conserve battery and API quota
		enum Background {
			static let critical: TimeInterval = 600    // 10 minutes - widgets + favourites
			static let standard: TimeInterval = 1800   // 30 minutes - recently visited
			static let background: TimeInterval = 3600 // 1 hour - skip in quick refresh
		}
	}

	// MARK: - Background Task Scheduling

	/// Intervals for scheduling background app refresh tasks
	/// Based on time of day and user activity patterns
	enum BackgroundTaskInterval {
		static let peakHours: TimeInterval = 15 * 60    // 15 minutes during commute
		static let officeHours: TimeInterval = 20 * 60  // 20 minutes during work hours
		static let offPeak: TimeInterval = 30 * 60      // 30 minutes evenings/weekends

		/// Processing task interval (full data sync)
		static let processingTask: TimeInterval = 2 * 60 * 60  // 2 hours

		/// Determine appropriate interval based on current time
		static func current() -> TimeInterval {
			let hour = Calendar.current.component(.hour, from: Date())
			let isWeekday = !Calendar.current.isDateInWeekend(Date())

			// Peak commute time on weekdays (7-9 AM, 5-7 PM)
			if isWeekday && (7...9 ~= hour || 17...19 ~= hour) {
				return peakHours
			}

			// Office hours on weekdays (9 AM - 5 PM)
			if isWeekday && 9...17 ~= hour {
				return officeHours
			}

			// Everything else
			return offPeak
		}
	}

	// MARK: - Widget Refresh Budget

	/// Widget refresh budget and throttling configuration
	enum Widget {
		/// Minimum interval between widget reloads
		static let minReloadInterval: TimeInterval = 15.0

		/// Daily budget for widget reloads (~48-70 allowed by Apple)
		static let dailyBudget: Int = 60

		/// Minimum space change to trigger widget update
		static let foregroundChangeThreshold: Int = 2
		static let backgroundChangeThreshold: Int = 4
	}

	// MARK: - API Rate Limiting

	/// API call constraints
	enum API {
		/// Minimum delay between sequential API calls
		static let minCallInterval: TimeInterval = 0.5  // 500ms

		/// Batch size for concurrent facility fetches
		static let batchSize: Int = 5

		/// Maximum facilities to refresh in quick background task
		static let quickRefreshLimit: Int = 5

		/// Time limits for background tasks
		static let quickRefreshTimeout: TimeInterval = 25  // 25 seconds
		static let fullRefreshTimeout: TimeInterval = 270  // 4.5 minutes
	}
}

// MARK: - RefreshTier Extension

/// Refresh tier represents facility priority for refresh scheduling
enum RefreshTier: CaseIterable {
	case critical   // Favourites - highest priority
	case standard   // Recently visited
	case background // Everything else

	/// Cache validity for foreground operations
	var cacheValiditySeconds: TimeInterval {
		switch self {
		case .critical:
			return RefreshConfiguration.CacheValidity.Foreground.critical
		case .standard:
			return RefreshConfiguration.CacheValidity.Foreground.standard
		case .background:
			return RefreshConfiguration.CacheValidity.Foreground.background
		}
	}

	/// Cache validity for background operations (more lenient)
	var backgroundCacheValiditySeconds: TimeInterval {
		switch self {
		case .critical:
			return RefreshConfiguration.CacheValidity.Background.critical
		case .standard:
			return RefreshConfiguration.CacheValidity.Background.standard
		case .background:
			return RefreshConfiguration.CacheValidity.Background.background
		}
	}
}

// MARK: - AppState

/// Application lifecycle state for refresh scheduling
enum AppState {
	case active
	case background

	/// Interval between refresh cycles
	var refreshInterval: TimeInterval {
		switch self {
		case .active:
			return RefreshConfiguration.ForegroundInterval.standard
		case .background:
			// Background refresh is handled by BackgroundTaskManager
			return RefreshConfiguration.BackgroundTaskInterval.offPeak
		}
	}
}
