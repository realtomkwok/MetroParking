//
//  RefreshConfiguration.swift
//  MetroParking
//
//  Created by Tom Kwok on 20/12/2025.
//

/// Unified refresh configuration consolidating all timing constants and strategies
/// for foreground refresh, background tasks, and widget updates.
///
/// ## API Quota Context (TfNSW Bronze Plan)
/// - Rate limit: 5 requests/second
/// - Daily quota: 60,000 requests/day
/// - Source data updates: every 10-15 seconds
///
/// ## Design Goals
/// - Support 50 concurrent test users within quota (~1,200 calls/user/day max)
/// - Align cache validity with source update frequency
/// - Prioritise watched facilities (widgets + favourites)

import Foundation

// MARK: - Unified Refresh Configuration

/// Single source of truth for all refresh-related timing and strategy configuration
enum RefreshConfiguration {

	// MARK: - Foreground Refresh Intervals

	/// How often to trigger the next refresh cycle when app is active
	enum ForegroundInterval {
		static let standard: TimeInterval = 90  // 90 seconds between refresh cycles
	}

	// MARK: - Cache Validity by Tier (Simplified 2-Tier System)

	/// Cache validity durations based on facility priority tier
	/// Used to determine if a facility needs refreshing
	///
	/// Two tiers:
	/// - **Watched**: Favourites + widget facilities (user actively monitors)
	/// - **Unwatched**: Everything else (refresh on-demand or in background sync)
	enum CacheValidity {
		/// Foreground cache validity (when app is active)
		enum Foreground {
			static let watched: TimeInterval = 90      // 90 seconds - widgets + favourites
			static let unwatched: TimeInterval = 300   // 5 minutes - others (visible on screen)
		}

		/// Background cache validity (for background tasks)
		/// More lenient to conserve battery and API quota
		enum Background {
			static let watched: TimeInterval = 900     // 15 minutes - widgets + favourites
			static let unwatched: TimeInterval = 7200  // 2 hours - only in full sync
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

		/// Maximum age to show cached data in widget before prompting refresh
		/// After this duration, widget shows "--" and "Tap to refresh" instead of potentially misleading old data
		static let maxStaleAge: TimeInterval = 120 * 60  // 2 hours
	}

	// MARK: - API Rate Limiting

	/// API call constraints
	enum API {
		/// Minimum delay between sequential API calls (200ms = 5 calls/sec TfNSW limit)
		static let minCallInterval: TimeInterval = 0.2

		/// Delay between UI updates for cascade animation effect
		static let uiStaggerDelay: TimeInterval = 0.08  // 80ms

		/// Batch size for concurrent facility fetches
		static let batchSize: Int = 5

		/// Maximum facilities to refresh in quick background task
		static let quickRefreshLimit: Int = 5

		/// Time limits for background tasks
		static let quickRefreshTimeout: TimeInterval = 25  // 25 seconds
		static let fullRefreshTimeout: TimeInterval = 270  // 4.5 minutes
	}
}

// MARK: - RefreshTier (Simplified 2-Tier System)

/// Refresh tier represents facility priority for refresh scheduling
///
/// Simplified from 3-tier to 2-tier system:
/// - **watched**: Favourites + widget facilities (actively monitored by user)
/// - **unwatched**: Everything else (refresh on-demand when visible)
enum RefreshTier: CaseIterable {
	case watched    // Favourites + widgets - highest priority
	case unwatched  // Everything else - refresh when visible or in background sync

	/// Cache validity for foreground operations
	var cacheValiditySeconds: TimeInterval {
		switch self {
		case .watched:
			return RefreshConfiguration.CacheValidity.Foreground.watched
		case .unwatched:
			return RefreshConfiguration.CacheValidity.Foreground.unwatched
		}
	}

	/// Cache validity for background operations (more lenient)
	var backgroundCacheValiditySeconds: TimeInterval {
		switch self {
		case .watched:
			return RefreshConfiguration.CacheValidity.Background.watched
		case .unwatched:
			return RefreshConfiguration.CacheValidity.Background.unwatched
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
